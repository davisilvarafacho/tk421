# TODO

## Não concluídos

- [ ] engenharia reversa do fone Corsair HS80 (chegou em 2026-11-11), no estilo do basike-keyboard
- [ ] lockscreen like caelestia
- [ ] temas gtk
- [ ] settings
- [ ] ter uma abinha que me segue entre as áreas de trabalho
- [ ] preview da área de trabalho + separa mais elas
- [ ] configurações de usuário
- [ ] melhorar as notificações bar
- [ ] melhorar design das notificações
- [ ] island v2 - inspiração redit - https://www.reddit.com/r/unixporn/comments/1xabt09/hyprland_impasto_06_liquid_glass_a_bezel_bar_and/
- [ ] waybar
- [ ] spcitify
- [ ] better-discord
- [ ] sync themas + auto: discord, spotify, vscode
- [ ] tranparência em todas as janelas
- [ ] banir botões: _ []
- [ ] Dock
- [ ] melhorar resolução imagem youtube
- [ ] escolher icons mais cheios
- [ ] mudar a death star
- [ ] island muito travado
- [ ] 

- [ ] 


## Concluídos

- [x] transição entre as áreas de trabalho (slide, hypr/hyprland.lua)
- [x] windows v design
- [x] notificações
- [x] desligar/suspender/encerrar/internet
- [x] terminais startup
- [x] melhorar o tweak de som
- [x] sistema de ícones temático feito com IA (pesquisar e implementar), no estilo do `assets/claude-spark.svg` (linha fina de aço `#b9b6b2`, traço 1.5, pontas retas, cantos em quina, grade 24×24)
  - pesquisa (2026-10-17): o Recraft (MCP já conectado) cria um estilo próprio a partir de 1–5 imagens de referência (`create_style`, grátis) e os modelos `_vector` geram SVG de verdade (`generate_image`, gasta créditos). Caminho: reunir 3–5 ícones de referência (claude-spark, deathstar, helmet…), criar o estilo, gerar o conjunto com um prompt único por ícone, e um script em Lua que troca as cores por `currentColor`/aço antes de salvar em `assets/`.
  - decidir: quais ícones primeiro (apps das notificações, tray, cápsulas da barra), e como ligar no `AppTile` (já aceita `asset`) e nas regras de `notifications/logic.js` (`APP_RULES`).
- [x] melhorar o island
- [x] mover de área de trabalho
- [x] widgets
- [x] menu on hover de cpu gpu e ram



## Inspirações

1. https://github.com/andreumassanet/impasto