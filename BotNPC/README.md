# BotNPC - Sistema de IA de Combate Avançado

O **BotNPC** é um recurso modular e de alta performance para MTA:SA, projetado para fornecer NPCs inteligentes com comportamentos táticos realistas, sistema de dano customizável e um editor de mapas integrado para definição de rotas e coberturas.

## 🚀 Funcionalidades Principais

- **IA Tática**: Bots armados utilizam strafe, rolamentos de combate e buscam cobertura (cover) automaticamente.
- **Sistema de Dano por Bone**: Dano configurável por arma e por parte do corpo (Cabeça, Tronco, etc).
- **Arquétipos Especializados**: Perfis prontos para Zumbis (lentos e rápidos), Bandidos e Guardas.
- **Sistema de Proteção**: Guardas que protegem áreas fixas (Públicos) ou seguem e defendem jogadores (Privados).
- **Percepção Avançada**: Sistema de visão (FOV) e audição (sons de passos, tiros e explosões) com detecção de proximidade crítica.
- **Editor de Mapas em Tempo Real**: Comandos para administradores criarem caminhos e pontos de cobertura diretamente no jogo.

---

## 🛠️ Arquétipos de Bot Disponíveis

1.  **bandit**: Inimigo armado, agressivo, usa táticas de combate e busca cover.
2.  **zombie_wakie**: Zumbi clássico, lento, ataca corpo a corpo.
3.  **zombie_rynner**: Zumbi veloz e agressivo, corre atrás do alvo.
4.  **guard_pub**: Segurança de zona. Protege um perímetro e ignora players inocentes.
5.  **guard_priv**: Guarda-costas pessoal. Segue o player e ataca qualquer ameaça ao mestre.

---

## 🗺️ Sistema de Mapas e Editor (NOVO)

O sistema de mapas permite definir por onde os bots podem caminhar e onde devem se esconder durante um tiroteio.

### Comandos do Editor (Apenas Admin/Console)
Use estes comandos para mapear uma área em tempo real:

-   **/addnode**: Cria um ponto de caminho (nó) na sua posição atual. Os bots usam esses pontos para patrulha e movimentação.
-   **/linknodes**: Cria uma conexão entre os dois últimos nós criados. (Essencial para definir rotas).
-   **/addcover [low/high]**: Cria um ponto de cobertura na sua posição e rotação.
    -   `low`: Para objetos baixos (caixas, muretas) onde o bot deve agachar.
    -   `high`: Para objetos altos (paredes, pilares) onde o bot fica em pé.
-   **/savenodes**: Salva permanentemente todos os pontos criados no arquivo `maps/custom_nodes.lua`. O resource recarregará os pontos automaticamente após o salvamento.
-   **/clearnodes**: Limpa a sessão de edição atual (remove marcadores temporários).

### Como a IA utiliza o Mapa
- **Patrulha**: Se um bot não tem alvo, ele pode caminhar entre os nós (`paths`) definidos.
- **Combate Tático**: Bots com o perfil `bandit` ou `guard` buscarão ativamente o ponto de `cover` mais próximo se estiverem sob fogo, aumentando drasticamente a dificuldade do combate.

---

## 🛡️ Sistema de Guardas

### Guardas Públicos (`guard_pub`)
- Protegem uma área definida por `setBotProtectArea`.
- Retornam ao posto se a perseguição sair da zona.
- **Inteligência Social**: Só atacam players se forem hostis (Wanted Level > 0 ou Time Inimigo). Ignoram cidadãos comuns.

### Guardas Privados (`guard_priv`)
- Seguem um alvo definido por `setBotProtectTarget`.
- **Zona de Conforto**: Mantêm 4.5m de distância para não atrapalhar o jogador.
- **Proteção Reativa**: Priorizam atacar instantaneamente qualquer um que cause dano ao seu mestre.

---

## 💻 API de Exports (Server-side)

### Criar Bot Customizado
```lua
exports.BotNPC:createBot(x, y, z, rot, skin, botType, dimension, interior, {
    health = 500,        -- HP customizado
    meleeDamage = 50     -- Dano de soco customizado
})
```

### Gerenciar Proteção
```lua
-- Fazer bot seguir e proteger um player
exports.BotNPC:setBotProtectTarget(botElement, playerElement)

-- Fazer bot proteger uma zona fixa (ex: entrada de uma base)
exports.BotNPC:setBotProtectArea(botElement, x, y, z, raio)
```

---

## 📊 Configurações e Dano
As configurações globais de dano, multiplicadores de membros (Headshot, etc) e performance podem ser ajustadas em `shared/constants.lua`.

## ⌨️ Comandos Administrativos Gerais
- `/spawnnpc [tipo] [quantidade]`: Spawn em massa para testes.
- `/killbots`: Remove todos os bots ativos.
- `/spawnguardpriv`: Cria um guarda-costas pessoal imediato.
- `/spawnguardpub`: Cria um guarda de zona no local atual.
