#!/usr/bin/env bash
# install.sh - Instalador do opencode-antigravity-auth para Linux e macOS
# Corrige automaticamente a incompatibilidade ESM/Bun do proper-lockfile
# Descoberto com ajuda do Claude AI (claude-sonnet-4-6)

set -e

INSTALLER_BUILD=1

# ---- Cores -------------------------------------------------------------------
CYAN='\033[0;36m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
MAGENTA='\033[0;35m'
WHITE='\033[1;37m'
GRAY='\033[0;90m'
NC='\033[0m'

write_step() { echo -e "\n${CYAN}==> $1${NC}"; }
write_ok()   { echo -e "    ${GREEN}OK: $1${NC}"; }
write_warn() { echo -e "    ${YELLOW}AVISO: $1${NC}"; }
write_fail() { echo -e "    ${RED}ERRO: $1${NC}"; exit 1; }

echo ""
echo -e "  ${MAGENTA}opencode-antigravity-auth - instalador Linux/macOS (build $INSTALLER_BUILD)${NC}"
echo -e "  ${MAGENTA}================================================${NC}"
echo ""

# ---- Detectar OS -------------------------------------------------------------
OS_TYPE="linux"
if [[ "$OSTYPE" == "darwin"* ]]; then
    OS_TYPE="mac"
fi

# ---- 1. Verificar OpenCode ---------------------------------------------------
write_step "Verificando instalacao do OpenCode..."

OPENCODE_EXE=$(which opencode 2>/dev/null || true)

# Tenta locais alternativos se nao estiver no PATH
if [ -z "$OPENCODE_EXE" ]; then
    for candidate in \
        "$HOME/.local/bin/opencode" \
        "/usr/local/bin/opencode" \
        "/opt/opencode/opencode" \
        "$HOME/Applications/OpenCode.app/Contents/MacOS/opencode"
    do
        if [ -x "$candidate" ]; then
            OPENCODE_EXE="$candidate"
            break
        fi
    done
fi

if [ -z "$OPENCODE_EXE" ]; then
    write_fail "OpenCode nao encontrado.\nBaixe em: https://opencode.ai"
fi

VERSION=$("$OPENCODE_EXE" --version 2>&1)
write_ok "OpenCode $VERSION encontrado em $OPENCODE_EXE"

# ---- 2. Pasta de config ------------------------------------------------------
write_step "Configurando pasta do OpenCode..."

CONFIG_DIR="$HOME/.config/opencode"
mkdir -p "$CONFIG_DIR"
write_ok "Config em: $CONFIG_DIR"

# ---- 3. Pasta de cache (varia por OS) ----------------------------------------
if [ "$OS_TYPE" = "mac" ]; then
    CACHE_DIR="$HOME/Library/Caches/opencode"
else
    CACHE_DIR="${XDG_CACHE_HOME:-$HOME/.cache}/opencode"
fi

# ---- 4. Limpar credenciais existentes ----------------------------------------
write_step "Limpeza de credenciais existentes..."
echo ""
echo -e "  ${WHITE}Deseja remover credenciais antigas antes de instalar?${NC}"
echo -e "  ${YELLOW}(Recomendado se voce teve erros de autenticacao ou 403)${NC}"
echo ""
echo "  [S] Sim - limpar tudo e comecar do zero (recomendado)"
echo "  [N] Nao - manter credenciais existentes"
echo ""
read -r -p "  Opcao [S/N]: " CLEAN_CHOICE

if [[ "$CLEAN_CHOICE" =~ ^[Ss] ]]; then
    ACCOUNTS_FILE="$CONFIG_DIR/antigravity-accounts.json"
    AUTH_FILE="$HOME/.local/share/opencode/auth.json"

    [ -f "$ACCOUNTS_FILE" ] && rm -f "$ACCOUNTS_FILE" && write_ok "Removido: $ACCOUNTS_FILE"
    [ -f "$AUTH_FILE"      ] && rm -f "$AUTH_FILE"      && write_ok "Removido: $AUTH_FILE"
    [ -d "$CACHE_DIR"      ] && rm -rf "$CACHE_DIR"     && write_ok "Cache limpo: $CACHE_DIR"
    write_ok "Credenciais removidas - instalacao limpa"
else
    write_ok "Credenciais mantidas"
fi

# ---- 5. Conta Google ---------------------------------------------------------
write_step "Conta Google para autenticacao..."
echo ""
echo "  Qual conta Google voce vai usar? (ex: seuemail@gmail.com)"
echo "  Dica: use uma conta Google estabelecida, NAO uma conta nova"
echo ""
read -r -p "  E-mail: " GOOGLE_EMAIL
[ -z "$GOOGLE_EMAIL" ] && write_fail "E-mail nao informado."

# ---- 6. Verificacao da conta Google ------------------------------------------
write_step "Verificacao da conta Google - PASSO OBRIGATORIO"
echo ""
echo -e "  ${YELLOW}IMPORTANTE: Antes de continuar, voce PRECISA verificar sua conta${NC}"
echo -e "  ${YELLOW}Google para o Gemini Code Assist. Sem isso, voce recebera erro 403.${NC}"
echo ""
echo -e "  ${WHITE}Por que isso e necessario?${NC}"
echo "  O Google exige que a API 'Gemini for Google Cloud' esteja ativa"
echo "  na sua conta antes de aceitar requisicoes do Antigravity."
echo ""
echo -e "  ${GREEN}Opcao 1 - Antigravity IDE (mais facil, recomendada):${NC}"
echo "    1. Abra o Antigravity IDE (baixe em antigravity.ai se nao tiver)"
echo "    2. Faca login com $GOOGLE_EMAIL"
echo "    3. Aceite os termos do Gemini Code Assist quando solicitado"
echo "    4. Aguarde aparecer sugestoes de codigo (prova que funcionou)"
echo "    5. Feche o Antigravity"
echo ""
echo -e "  ${CYAN}Opcao 2 - VS Code com Gemini Code Assist:${NC}"
echo "    1. Instale a extensao 'Gemini Code Assist' no VS Code"
echo "    2. Faca login com $GOOGLE_EMAIL"
echo "    3. Aceite os termos quando solicitado"
echo ""
echo -e "  ${GRAY}Opcao 3 - Google Cloud Console (avancado):${NC}"
echo "    1. Acesse console.cloud.google.com"
echo "    2. Busque por 'Cloud AI Companion API'"
echo "    3. Clique em 'Enable' para o seu projeto"
echo ""
read -r -p "  Ja fez a verificacao? [S/N]: " VERIFIED
if [[ ! "$VERIFIED" =~ ^[Ss] ]]; then
    echo ""
    write_warn "Continuando sem verificacao - voce pode receber erro 403 mais tarde."
    write_warn "Se isso acontecer, faca a verificacao e execute o instalador novamente."
fi

# ---- 7. Selecao de modelos ---------------------------------------------------
write_step "Selecao de modelos..."
echo ""
echo "  Quais modelos deseja configurar?"
echo "  [1] Todos (Gemini 3 Pro/Flash + Claude Opus/Sonnet) - Recomendado"
echo "  [2] Apenas Gemini (Gemini 3 Pro e Flash)"
echo "  [3] Apenas Claude (Opus 4.6 Thinking e Sonnet 4.6)"
echo ""
read -r -p "  Opcao [1/2/3]: " MODEL_CHOICE
MODEL_CHOICE="${MODEL_CHOICE:-1}"

ALL_MODELS='    "antigravity-gemini-3-pro": {
      "name": "Gemini 3 Pro (Antigravity)",
      "limit": { "context": 1048576, "output": 65535 },
      "modalities": { "input": ["text","image","pdf"], "output": ["text"] },
      "variants": { "low": { "thinkingLevel": "low" }, "high": { "thinkingLevel": "high" } }
    },
    "antigravity-gemini-3-flash": {
      "name": "Gemini 3 Flash (Antigravity)",
      "limit": { "context": 1048576, "output": 65536 },
      "modalities": { "input": ["text","image","pdf"], "output": ["text"] },
      "variants": {
        "minimal": { "thinkingLevel": "minimal" }, "low": { "thinkingLevel": "low" },
        "medium": { "thinkingLevel": "medium" },   "high": { "thinkingLevel": "high" }
      }
    },
    "antigravity-claude-opus-4-6-thinking": {
      "name": "Claude Opus 4.6 Thinking (Antigravity)",
      "limit": { "context": 200000, "output": 64000 },
      "modalities": { "input": ["text","image","pdf"], "output": ["text"] },
      "variants": { "low": { "thinkingConfig": { "thinkingBudget": 8192 } }, "max": { "thinkingConfig": { "thinkingBudget": 32768 } } }
    },
    "antigravity-claude-sonnet-4-6": {
      "name": "Claude Sonnet 4.6 (Antigravity)",
      "limit": { "context": 200000, "output": 64000 },
      "modalities": { "input": ["text","image","pdf"], "output": ["text"] }
    }'

GEMINI_MODELS='    "antigravity-gemini-3-pro": {
      "name": "Gemini 3 Pro (Antigravity)",
      "limit": { "context": 1048576, "output": 65535 },
      "modalities": { "input": ["text","image","pdf"], "output": ["text"] },
      "variants": { "low": { "thinkingLevel": "low" }, "high": { "thinkingLevel": "high" } }
    },
    "antigravity-gemini-3-flash": {
      "name": "Gemini 3 Flash (Antigravity)",
      "limit": { "context": 1048576, "output": 65536 },
      "modalities": { "input": ["text","image","pdf"], "output": ["text"] },
      "variants": {
        "minimal": { "thinkingLevel": "minimal" }, "low": { "thinkingLevel": "low" },
        "medium": { "thinkingLevel": "medium" },   "high": { "thinkingLevel": "high" }
      }
    }'

CLAUDE_MODELS='    "antigravity-claude-opus-4-6-thinking": {
      "name": "Claude Opus 4.6 Thinking (Antigravity)",
      "limit": { "context": 200000, "output": 64000 },
      "modalities": { "input": ["text","image","pdf"], "output": ["text"] },
      "variants": { "low": { "thinkingConfig": { "thinkingBudget": 8192 } }, "max": { "thinkingConfig": { "thinkingBudget": 32768 } } }
    },
    "antigravity-claude-sonnet-4-6": {
      "name": "Claude Sonnet 4.6 (Antigravity)",
      "limit": { "context": 200000, "output": 64000 },
      "modalities": { "input": ["text","image","pdf"], "output": ["text"] }
    }'

case "$MODEL_CHOICE" in
    2) SELECTED_MODELS="$GEMINI_MODELS" ;;
    3) SELECTED_MODELS="$CLAUDE_MODELS" ;;
    *) SELECTED_MODELS="$ALL_MODELS" ;;
esac

# ---- 8. Criar opencode.json --------------------------------------------------
write_step "Criando opencode.json..."

OPENCODE_JSON="$CONFIG_DIR/opencode.json"

if [ -f "$OPENCODE_JSON" ]; then
    write_warn "opencode.json existente encontrado - sera substituido"
fi

cat > "$OPENCODE_JSON" <<EOF
{
  "\$schema": "https://opencode.ai/config.json",
  "plugin": ["opencode-antigravity-auth@latest"],
  "provider": {
    "google": {
      "models": {
$SELECTED_MODELS
      }
    }
  }
}
EOF

write_ok "opencode.json criado"

# ---- 9. Instalar plugin via npm ----------------------------------------------
write_step "Instalando plugin via npm..."

PKG_JSON="$CONFIG_DIR/package.json"
[ -f "$PKG_JSON" ] || echo '{"dependencies":{}}' > "$PKG_JSON"

if command -v npm &>/dev/null; then
    (cd "$CONFIG_DIR" && npm install opencode-antigravity-auth@latest --save 2>&1) | tail -1
    write_ok "Plugin instalado em $CONFIG_DIR/node_modules"
else
    write_warn "npm nao encontrado - o OpenCode tentara instalar automaticamente ao abrir"
fi

# ---- 10. Abrir OpenCode para instalar no cache --------------------------------
write_step "Instalacao no cache do OpenCode..."
echo ""
echo "  Agora voce precisa:"
echo "  1. Abrir o OpenCode normalmente"
echo "  2. Aguardar ele carregar (alguns segundos)"
echo "  3. Fechar o OpenCode"
echo ""
echo "  (Isso instala o plugin no cache interno do OpenCode)"
echo ""
read -r -p "  Pressione ENTER quando tiver aberto E fechado o OpenCode"

# ---- 11. Aplicar fix ESM/Bun -------------------------------------------------
write_step "Aplicando correcao de compatibilidade ESM/Bun..."

STORAGE_JS="$CACHE_DIR/node_modules/opencode-antigravity-auth/dist/src/plugin/storage.js"

if [ -f "$STORAGE_JS" ]; then
    if grep -q "proper-lockfile replaced" "$STORAGE_JS"; then
        write_ok "Correcao ja aplicada anteriormente"
    else
        # macOS usa sed diferente do GNU sed — detecta e adapta
        if [ "$OS_TYPE" = "mac" ]; then
            sed -i '' \
                's|import lockfile from "proper-lockfile";|// proper-lockfile replaced: Bun ESM incompatibility fix (github.com/vagnervrds/opencode-antigravity-auth)\nconst lockfile = { lock: async () => async () => {} };|g' \
                "$STORAGE_JS"
        else
            sed -i \
                's|import lockfile from "proper-lockfile";|// proper-lockfile replaced: Bun ESM incompatibility fix (github.com\/vagnervrds\/opencode-antigravity-auth)\nconst lockfile = { lock: async () => async () => {} };|g' \
                "$STORAGE_JS"
        fi
        write_ok "Correcao aplicada em $STORAGE_JS"
    fi
else
    write_warn "Cache do plugin nao encontrado em $CACHE_DIR"
    write_warn "O fix sera aplicado automaticamente na proxima vez que o OpenCode abrir"

    # Salvar script de fix para rodar depois
    FIX_SCRIPT="$CONFIG_DIR/apply-fix.sh"
    cat > "$FIX_SCRIPT" <<'FIXEOF'
#!/usr/bin/env bash
OS_TYPE="linux"
[[ "$OSTYPE" == "darwin"* ]] && OS_TYPE="mac"

if [ "$OS_TYPE" = "mac" ]; then
    CACHE_DIR="$HOME/Library/Caches/opencode"
else
    CACHE_DIR="${XDG_CACHE_HOME:-$HOME/.cache}/opencode"
fi

STORAGE_JS="$CACHE_DIR/node_modules/opencode-antigravity-auth/dist/src/plugin/storage.js"

if [ -f "$STORAGE_JS" ]; then
    if grep -q "proper-lockfile replaced" "$STORAGE_JS"; then
        echo "Fix ja estava aplicado."
    else
        if [ "$OS_TYPE" = "mac" ]; then
            sed -i '' 's|import lockfile from "proper-lockfile";|// proper-lockfile replaced\nconst lockfile = { lock: async () => async () => {} };|g' "$STORAGE_JS"
        else
            sed -i 's|import lockfile from "proper-lockfile";|// proper-lockfile replaced\nconst lockfile = { lock: async () => async () => {} };|g' "$STORAGE_JS"
        fi
        echo "Fix aplicado com sucesso!"
    fi
else
    echo "Plugin ainda nao instalado no cache. Abra o OpenCode primeiro."
fi
FIXEOF
    chmod +x "$FIX_SCRIPT"
    write_warn "Script de fix salvo em: $FIX_SCRIPT"
    write_warn "Rode-o apos abrir e fechar o OpenCode uma vez:  bash $FIX_SCRIPT"
fi

# ---- 12. Autenticacao Google -------------------------------------------------
write_step "Autenticacao com o Google..."
echo ""
echo "  Vamos fazer o login com $GOOGLE_EMAIL no OpenCode."
echo ""
echo "  Na tela de login, selecione:"
echo "  'Google' -> 'OAuth with Google (Antigravity)'"
echo ""
echo -e "  ${YELLOW}LEMBRE-SE: Se receber erro 403 'Verify your account' apos o login,${NC}"
echo -e "  ${YELLOW}voce precisa verificar a conta no Antigravity IDE primeiro (passo 6).${NC}"
echo ""
echo -e "  ${CYAN}DICA - Project ID: quando o login perguntar 'Project ID',${NC}"
echo -e "  ${CYAN}deixe em BRANCO e pressione ENTER (a menos que voce saiba${NC}"
echo -e "  ${CYAN}exatamente qual project ID usar e ja tenha a API ativada nele).${NC}"
echo -e "  ${CYAN}Preencher um Project ID incorreto causa erro 403 com a mensagem:${NC}"
echo -e "  ${CYAN}'Gemini for Google Cloud API has not been used in project...'.${NC}"
echo ""
read -r -p "  Quer fazer o login agora? [S/N]: " DO_LOGIN

if [[ "$DO_LOGIN" =~ ^[Ss] ]]; then
    echo ""
    echo -e "  ${CYAN}Abrindo tela de login...${NC}"
    sleep 2
    "$OPENCODE_EXE" auth login
fi

# ---- 13. Conclusao -----------------------------------------------------------
echo ""
echo -e "  ${MAGENTA}================================================${NC}"
echo -e "  ${GREEN}Instalacao concluida!${NC}"
echo ""
echo -e "  ${WHITE}Proximos passos:${NC}"
echo "  1. Abra o OpenCode"
echo "  2. Selecione um modelo como 'google/antigravity-gemini-3-flash'"
echo "  3. Envie uma mensagem para testar"
echo ""
echo -e "  ${YELLOW}Solucao de problemas:${NC}"
echo ""
echo "  Erro '403 Verify your account':"
echo "    -> Abra o Antigravity IDE, faca login com $GOOGLE_EMAIL"
echo "    -> Aceite os termos do Gemini Code Assist"
echo "    -> Execute este instalador novamente (opcao S na limpeza)"
echo ""
echo "  Erro '403 Gemini for Google Cloud API has not been used':"
echo "    -> Acesse console.cloud.google.com"
echo "    -> Busque por 'Cloud AI Companion API' e clique em Enable"
echo "    -> OU use o Antigravity IDE para ativar automaticamente"
echo "    -> OU refaca o login deixando o Project ID em BRANCO"
echo ""
echo "  Erro 'No Antigravity accounts configured':"
echo "    -> Execute este instalador novamente (opcao S na limpeza)"
echo "    -> Certifique-se de fazer login com 'OAuth with Google (Antigravity)'"
echo ""
echo -e "  ${CYAN}Problemas? github.com/vagnervrds/opencode-antigravity-auth${NC}"
echo -e "  ${GRAY}Fix descoberto com Claude AI (claude-sonnet-4-6)${NC}"
echo -e "  ${MAGENTA}================================================${NC}"
echo ""
