# Haste 2 RGB — CLI + widget Omarchy (Quickshell)

Controle de RGB para o `HyperX Pulsefire Haste 2 (com fio)` no Linux, com
um widget nativo pra barra do Omarchy (Quickshell/omarchy-shell).

## Estrutura

```
haste2-rgb                  CLI/daemon Python (fala HID com o mouse, RGB)
haste2-rgb.service           unit systemd --user que roda o daemon de RGB
haste2-dpi-watcher            daemon que observa o botão físico de DPI
haste2-dpi-watcher.service    unit systemd --user do watcher de DPI
99-haste2-rgb.rules          regra udev (permissão do /dev/hidrawN)
install.sh                   instala CLI + services + regra udev
manifest.json                 |
BarWidget.qml                 | plugin bar-widget do Omarchy
Panel.qml                     |
update.sh                    reaplica tudo de uma vez (CLI + widget)
```

## Instalação do zero

```bash
chmod +x install.sh update.sh
./update.sh
```

Isso instala o `haste2-rgb` em `~/.local/bin`, o serviço systemd, a regra
udev, e copia o widget para `~/.config/omarchy/plugins/local.haste2-rgb/`,
já habilitando tudo.

## Uso

- **Clique esquerdo** no ícone do mouse na barra: abre/fecha o painel.
- **Clique direito**: força atualização do estado (cor/serviço ativo).
- No painel: clique numa cor, ou digite um HEX (`#8a2be2`) e **Aplicar**.
- **Desligar LED**: `haste2-rgb set off`.
- **Parar serviço**: `haste2-rgb stop`.

Via terminal, direto:

```bash
haste2-rgb set purple
haste2-rgb set '#8a2be2'
haste2-rgb status
haste2-rgb stop
```

## Atualizar depois de editar algo

```bash
git pull        # se estiver clonado
./update.sh
```

Se só mexeu nos `.qml`, também funciona editar direto em
`~/.config/omarchy/plugins/local.haste2-rgb/` — o shell recarrega sozinho
ao salvar. Se não recarregar: `omarchy-shell shell rescanPlugins`, e se
nem isso resolver: `omarchy-restart-shell`.

## Troubleshooting

### O mouse não responde depois de reiniciar o computador

**Causa raiz real (corrigida nesta versão):** a regra udev original tinha
`ATTRS{idVendor}`, `ATTRS{idProduct}` e `ATTRS{bInterfaceNumber}` juntos
numa única regra. O problema: `idVendor`/`idProduct` vivem no dispositivo
USB **pai** (o mouse inteiro), enquanto `bInterfaceNumber` vive na
interface USB **filha** (a porta 02 específica). O udev exige que todos
os `ATTRS{}` de uma mesma regra pertençam ao **mesmo** ancestral na
árvore de dispositivos — misturando os dois níveis, a condição nunca
batia, e a regra era ignorada **em silêncio**, sem nenhum erro no log.
Isso fazia o `/dev/hidrawN` ficar sempre `root`-only (`crw-------`).

A regra atual usa `ENV{ID_VENDOR_ID}`/`ENV{ID_MODEL_ID}` (propriedades já
importadas pela regra padrão `60-persistent-hidraw.rules` via `usb_id`,
que não têm essa restrição de nível) combinadas com um único
`ATTRS{bInterfaceNumber}`, e `MODE="0666"` pra não depender de timing de
sessão do `logind` também.

Se isso acontecer de novo (outra distro, outro dispositivo parecido),
diagnostique com:

```bash
systemctl --user status haste2-rgb.service --no-pager -l
journalctl --user -u haste2-rgb.service --no-pager -n 40
ls -la /dev/hidraw*
```

Se aparecer `crw-------` (só root) em vez de `crw-rw-rw-`, confirme se a
regra está de fato **executando** (não só sendo lida) com:

```bash
DEVPATH=$(udevadm info -q path -n /dev/hidraw3)
sudo SYSTEMD_LOG_LEVEL=debug udevadm test "$DEVPATH" 2>&1 | grep "haste2-rgb.rules:"
```

Se essa busca não retornar nada, a regra está sendo ignorada silenciosamente
(provavelmente por causa do problema de "mesmo ancestral" acima). Depois de
corrigir o arquivo:

```bash
sudo udevadm control --reload-rules
sudo udevadm trigger --action=add --subsystem-match=hidraw   # --action=add é obrigatório;
                                                                 # sem isso o trigger manda um
                                                                 # evento "change" que não bate
                                                                 # na condição ACTION=="add"
systemctl --user reset-failed haste2-rgb.service
systemctl --user restart haste2-rgb.service
```

### O ícone não aparece na barra

Veja o log do shell:

```bash
qs log -p "$OMARCHY_PATH/shell" --tail 100
```

Erros de QML (ex. `IDs cannot start with an uppercase letter`) apontam
arquivo:linha:coluna exatos — se editar e o erro não sumir mesmo com o
arquivo corrigido no disco, force um restart completo do shell
(`rescanPlugins` às vezes não repropaga um plugin que já falhou uma vez):

```bash
omarchy-restart-shell
```

### Validar antes de instalar (opcional)

```bash
PLUGIN_DIR="$HOME/.config/omarchy/plugins/local.haste2-rgb"
omarchy plugin validate "$PLUGIN_DIR"
qmllint -I "$OMARCHY_PATH/shell" "$PLUGIN_DIR/BarWidget.qml" "$PLUGIN_DIR/Panel.qml"
```

## Remover

```bash
omarchy plugin remove local.haste2-rgb
systemctl --user disable --now haste2-rgb.service
systemctl --user disable --now haste2-dpi-watcher.service
rm ~/.local/bin/haste2-rgb ~/.local/bin/haste2-dpi-watcher
rm ~/.config/systemd/user/haste2-rgb.service ~/.config/systemd/user/haste2-dpi-watcher.service
sudo rm /etc/udev/rules.d/99-haste2-rgb.rules
sudo udevadm control --reload-rules
```

## Notas / limitações

- O ícone é desenhado com formas QML (retângulo + rodinha), sem depender
  de nenhuma fonte Nerd Font — os codepoints do Material Design Icons
  mudam entre versões da fonte, então um glifo fixo podia virar um
  "tofu" (quadrado vazio) dependendo do sistema.
- `bar.run()` é fire-and-forget; o estado (cor atual / serviço ativo /
  DPI atual) é lido via arquivos em `~/.config/haste2-rgb/`, em polling
  leve a cada 4s — não é instantâneo caso você troque a cor por fora
  (ex. via terminal) ou aperte o botão de DPI, mas atualiza sozinho em
  poucos segundos.
- **DPI é somente leitura.** Testado via engenharia reversa: o mouse
  manda um report (`fb 08 XX YY`) na interface HID 02 toda vez que o
  botão físico de DPI é apertado, ciclando entre 4 estágios
  (400/800/1600/3200). Tentativas de **escrever** esse mesmo formato de
  volta pro mouse (pra forçar a troca pelo widget) não tiveram efeito —
  esse hardware só aceita troca de DPI pelo botão físico. O painel
  mostra o estágio atual, destacado, mas os blocos não são clicáveis.
- **Brilho do LED não é ajustável** por esse protocolo. Testei os dois
  bytes reservados do report de cor (offsets 1 e 2, hoje zerados) com
  valores de 0 a 255 — o LED sempre ficou no brilho máximo, sem variar.
  Não descartamos que exista em outro report ID não mapeado ainda, mas
  não é algo trivial de continuar sem mais captura de tráfego USB.
