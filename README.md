# Haste 2 RGB

Controle de RGB para o **HyperX Pulsefire Haste 2** no Linux, com um widget nativo para a barra do [Omarchy](https://omarchy.org) (Quickshell / omarchy-shell).

## Recursos

- Troca de cor do LED por CLI ou pelo widget da barra (nome da cor ou HEX).
- Daemon em Python que fala HID direto com o mouse.
- Indicador do estágio de DPI atual (somente leitura), via observação do botão físico.
- Permissões configuradas por regra udev, sem precisar rodar nada como root.
- Serviços `systemd --user` que iniciam junto com a sessão.

## Estrutura do projeto

```
haste2-rgb                   CLI/daemon Python (HID + RGB)
haste2-rgb.service           unit systemd --user do daemon de RGB
haste2-dpi-watcher           daemon que observa o botão físico de DPI
haste2-dpi-watcher.service   unit systemd --user do watcher de DPI
99-haste2-rgb.rules          regra udev (permissão do /dev/hidrawN)
install.sh                   instala CLI + services + regra udev
update.sh                    reaplica tudo de uma vez (CLI + widget)
manifest.json                ┐
BarWidget.qml                ├ plugin bar-widget do Omarchy
Panel.qml                    ┘
```

## Instalação

```bash
chmod +x install.sh update.sh
./update.sh
```

O script:

1. instala o `haste2-rgb` e o `haste2-dpi-watcher` em `~/.local/bin`;
2. instala e habilita os serviços systemd (usuário);
3. instala a regra udev (pede `sudo`);
4. copia o widget para `~/.config/omarchy/plugins/local.haste2-rgb/` e o habilita.

## Uso

### Widget na barra

| Ação | Resultado |
|---|---|
| Clique esquerdo no ícone do mouse | Abre/fecha o painel |
| Clique direito | Força a atualização do estado (cor e serviço ativo) |

No painel, clique em uma cor ou digite um HEX (ex.: `#8a2be2`) e clique em **Aplicar**.

### Terminal

```bash
haste2-rgb set purple          # cor por nome
haste2-rgb set '#8a2be2'       # cor por HEX
haste2-rgb set off             # desliga o LED
haste2-rgb status              # mostra o estado atual
haste2-rgb stop                # para o serviço
```

## Atualização

Depois de editar qualquer arquivo do projeto:

```bash
./update.sh
```

Se você só alterou os `.qml`, também pode editá-los direto em `~/.config/omarchy/plugins/local.haste2-rgb/`. O shell recarrega ao salvar. Se não recarregar:

```bash
omarchy-shell shell rescanPlugins   # 1ª tentativa
omarchy-restart-shell               # se a anterior não resolver
```

### Validação opcional

```bash
PLUGIN_DIR="$HOME/.config/omarchy/plugins/local.haste2-rgb"
omarchy plugin validate "$PLUGIN_DIR"
qmllint -I "$OMARCHY_PATH/shell" "$PLUGIN_DIR/BarWidget.qml" "$PLUGIN_DIR/Panel.qml"
```

## Solução de problemas

### O mouse não responde depois de reiniciar o computador

**Sintoma:** o `/dev/hidrawN` fica `crw-------` (só root) e o serviço falha ao abrir o dispositivo.

**Causa raiz (corrigida nesta versão):** a regra udev original juntava `ATTRS{idVendor}`, `ATTRS{idProduct}` e `ATTRS{bInterfaceNumber}` em uma única regra. Só que `idVendor`/`idProduct` pertencem ao dispositivo USB **pai** (o mouse inteiro), enquanto `bInterfaceNumber` pertence à interface **filha** (a interface 02). O udev exige que todos os `ATTRS{}` de uma mesma regra venham do **mesmo** ancestral; misturando os dois níveis, a condição nunca batia e a regra era ignorada **em silêncio**, sem erro no log.

**Solução aplicada:** a regra atual usa `ENV{ID_VENDOR_ID}` e `ENV{ID_MODEL_ID}` (importadas pela regra padrão `60-persistent-hidraw.rules` via `usb_id`, sem essa restrição de nível), combinadas com um único `ATTRS{bInterfaceNumber}`. Também usa `MODE="0666"` para não depender do timing da sessão do `logind`.

**Diagnóstico**, caso aconteça de novo (outra distro ou outro dispositivo parecido):

```bash
systemctl --user status haste2-rgb.service --no-pager -l
journalctl --user -u haste2-rgb.service --no-pager -n 40
ls -la /dev/hidraw*
```

Se aparecer `crw-------` em vez de `crw-rw-rw-`, confirme se a regra está sendo **executada** (e não só lida):

```bash
DEVPATH=$(udevadm info -q path -n /dev/hidraw3)
sudo SYSTEMD_LOG_LEVEL=debug udevadm test "$DEVPATH" 2>&1 | grep "haste2-rgb.rules:"
```

Se a busca não retornar nada, a regra está sendo ignorada silenciosamente (provavelmente pelo problema do "mesmo ancestral"). Depois de corrigir o arquivo:

```bash
sudo udevadm control --reload-rules
sudo udevadm trigger --action=add --subsystem-match=hidraw
systemctl --user reset-failed haste2-rgb.service
systemctl --user restart haste2-rgb.service
```

> **Importante:** o `--action=add` é obrigatório. Sem ele, o trigger envia um evento `change`, que não bate na condição `ACTION=="add"` da regra.

### O ícone não aparece na barra

Veja o log do shell:

```bash
qs log -p "$OMARCHY_PATH/shell" --tail 100
```

Erros de QML (ex.: `IDs cannot start with an uppercase letter`) indicam arquivo:linha:coluna exatos. Se o erro persistir mesmo com o arquivo corrigido no disco, force um restart completo, pois o `rescanPlugins` às vezes não repropaga um plugin que já falhou uma vez:

```bash
omarchy-restart-shell
```

## Remoção

```bash
omarchy plugin remove local.haste2-rgb
systemctl --user disable --now haste2-rgb.service
systemctl --user disable --now haste2-dpi-watcher.service
rm ~/.local/bin/haste2-rgb ~/.local/bin/haste2-dpi-watcher
rm ~/.config/systemd/user/haste2-rgb.service ~/.config/systemd/user/haste2-dpi-watcher.service
sudo rm /etc/udev/rules.d/99-haste2-rgb.rules
sudo udevadm control --reload-rules
```

## Limitações conhecidas

- **DPI é somente leitura.** O mouse envia um report (`fb 08 XX YY`) na interface HID 02 a cada aperto do botão físico de DPI, ciclando entre 4 estágios (400 / 800 / 1600 / 3200). Tentativas de escrever esse mesmo formato de volta não tiveram efeito: este hardware só aceita a troca pelo botão físico. O painel mostra o estágio atual, destacado, mas os blocos não são clicáveis.
- **O brilho do LED não é ajustável** por este protocolo. Os dois bytes reservados do report de cor (offsets 1 e 2, hoje zerados) foram testados com valores de 0 a 255 e o LED sempre ficou no brilho máximo. Pode existir em outro report ID ainda não mapeado, mas continuar exige mais captura de tráfego USB.
- **O estado do widget não é instantâneo.** O `bar.run()` é fire-and-forget; cor atual, serviço ativo e DPI são lidos de arquivos em `~/.config/haste2-rgb/`, com polling leve a cada 4 s. Mudanças feitas por fora (terminal ou botão de DPI) aparecem em poucos segundos.
- **O ícone é desenhado com formas QML** (retângulo + rodinha), sem depender de Nerd Font. Os codepoints do Material Design Icons mudam entre versões da fonte e um glifo fixo poderia virar um "tofu" (quadrado vazio).

## Como contribuir

Contribuições são bem-vindas: correções, documentação, sugestões e melhorias.

1. Consulte as [Issues](../../issues) abertas para evitar duplicidade.
2. Faça um fork do repositório.
3. Crie uma branch: `git checkout -b feature/minha-contribuicao`
4. Implemente as alterações seguindo os padrões do projeto e rode as verificações pertinentes (veja [Validação opcional](#validação-opcional)).
5. Faça o commit com uma mensagem descritiva: `git commit -m "feat: descreve minha contribuição"`
6. Envie a branch: `git push origin feature/minha-contribuicao`
7. Abra um Pull Request.

**Diretrizes**

- Mantenha as alterações objetivas e relacionadas ao propósito do PR.
- Respeite a arquitetura e os padrões existentes.
- Atualize a documentação quando houver mudanças relevantes.
- Mantenha uma comunicação respeitosa e construtiva.

**No Pull Request, inclua:** descrição clara das mudanças, justificativa, Issues relacionadas, capturas de tela (se houver mudança visual) e os testes realizados. PRs podem receber pedidos de ajuste ou ser recusados se não estiverem alinhados ao escopo do projeto.

### Reportando problemas

Abra uma Issue com:

- título claro e objetivo;
- passos para reproduzir;
- comportamento esperado e observado;
- ambiente (distro, versão do Omarchy, kernel) e logs relevantes (`journalctl --user -u haste2-rgb.service`).

### Sugerindo funcionalidades

Explique o problema que a ideia resolve, a solução proposta, alternativas consideradas e possíveis impactos técnicos. Enviar uma sugestão não garante sua implementação; cada proposta é avaliada conforme o escopo e as prioridades do projeto.

## Segurança

Encontrou uma vulnerabilidade? Não a divulgue em Issues públicas; entre em contato com o mantenedor por um canal privado. Nunca publique credenciais, tokens ou chaves privadas.

## Licença

Distribuído sob a licença **MIT**. Veja o arquivo `LICENSE` para mais detalhes.
