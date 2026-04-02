# install.ps1 - Instalador do opencode-antigravity-auth para Windows
# Corrige automaticamente a incompatibilidade ESM/Bun do proper-lockfile
# Descoberto com ajuda do Claude AI (claude-sonnet-4-6)

$ErrorActionPreference = "Stop"

$INSTALLER_BUILD = 3

function Write-Step($msg)  { Write-Host "`n==> $msg" -ForegroundColor Cyan }
function Write-Ok($msg)    { Write-Host "    OK: $msg" -ForegroundColor Green }
function Write-Warn($msg)  { Write-Host "    AVISO: $msg" -ForegroundColor Yellow }
function Write-Fail($msg)  { Write-Host "    ERRO: $msg" -ForegroundColor Red; exit 1 }

Write-Host ""
Write-Host "  opencode-antigravity-auth - instalador Windows (build $INSTALLER_BUILD)" -ForegroundColor Magenta
Write-Host "  ================================================" -ForegroundColor Magenta
Write-Host ""

# ---- 1. Verificar OpenCode ------------------------------------------------------------------------------------------------------------
Write-Step "Verificando instalacao do OpenCode..."

$opencodeExe = "$env:LOCALAPPDATA\OpenCode\opencode-cli.exe"
if (-not (Test-Path $opencodeExe)) {
    Write-Fail "OpenCode nao encontrado em $opencodeExe`nBaixe em: https://opencode.ai"
}
$version = & $opencodeExe --version 2>&1
Write-Ok "OpenCode $version encontrado"

# ---- 2. Verificar/criar pasta de config --------------------------------------------------------------------------------
Write-Step "Configurando pasta do OpenCode..."

$configDir = "$env:USERPROFILE\.config\opencode"
if (-not (Test-Path $configDir)) {
    New-Item -ItemType Directory -Path $configDir -Force | Out-Null
}
Write-Ok "Config em: $configDir"

# ---- 3. Perguntar conta Google ----------------------------------------------------------------------------------------------------
Write-Step "Conta Google para autenticacao..."
Write-Host ""
Write-Host "  Qual conta Google voce vai usar? (ex: seuemail@gmail.com)"
Write-Host "  Dica: use uma conta Google estabelecida, NAO uma conta nova"
Write-Host ""
$googleEmail = Read-Host "  E-mail"
if (-not $googleEmail) { Write-Fail "E-mail nao informado." }

# ---- 4. Perguntar modelos --------------------------------------------------------------------------------------------------------------
Write-Step "Selecao de modelos..."
Write-Host ""
Write-Host "  Quais modelos deseja configurar?"
Write-Host "  [1] Todos (Gemini 3 Pro/Flash + Claude Opus/Sonnet) - Recomendado"
Write-Host "  [2] Apenas Gemini (Gemini 3 Pro e Flash)"
Write-Host "  [3] Apenas Claude (Opus 4.6 Thinking e Sonnet 4.6)"
Write-Host ""
$modelChoice = Read-Host "  Opcao [1/2/3]"
if (-not $modelChoice) { $modelChoice = "1" }

$allModels = @'
    "antigravity-gemini-3-pro": {
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
    }
'@

$geminiModels = @'
    "antigravity-gemini-3-pro": {
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
    }
'@

$claudeModels = @'
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
    }
'@

$selectedModels = switch ($modelChoice) {
    "2"     { $geminiModels }
    "3"     { $claudeModels }
    default { $allModels }
}

# ---- 5. Criar/atualizar opencode.json ------------------------------------------------------------------------------------
Write-Step "Criando opencode.json..."

$opencodeJson = "$configDir\opencode.json"

# Preserva conteudo existente se houver outras configs
$existingContent = @{}
if (Test-Path $opencodeJson) {
    try {
        $existingContent = Get-Content $opencodeJson -Raw | ConvertFrom-Json -AsHashtable
        Write-Warn "opencode.json existente encontrado - mesclando configuracoes"
    } catch {
        Write-Warn "opencode.json existente invalido - sera substituido"
    }
}

$newConfig = @"
{
  "`$schema": "https://opencode.ai/config.json",
  "plugin": ["opencode-antigravity-auth@latest"],
  "provider": {
    "google": {
      "models": {
$selectedModels
      }
    }
  }
}
"@

Set-Content -Path $opencodeJson -Value $newConfig -Encoding UTF8
Write-Ok "opencode.json criado"

# ---- 6. Instalar plugin via npm ------------------------------------------------------------------------------------------------
Write-Step "Instalando plugin via npm..."

$pkgJson = "$configDir\package.json"
if (-not (Test-Path $pkgJson)) {
    Set-Content -Path $pkgJson -Value '{"dependencies":{}}' -Encoding UTF8
}

Push-Location $configDir
try {
    npm install opencode-antigravity-auth@latest --save 2>&1 | Out-Null
    Write-Ok "Plugin instalado em $configDir\node_modules"
} catch {
    Write-Warn "npm install falhou - o OpenCode tentara instalar automaticamente ao abrir"
} finally {
    Pop-Location
}

# ---- 7. Abrir OpenCode para instalar no cache --------------------------------------------------------------------
Write-Step "Instalacao no cache do OpenCode..."
Write-Host ""
Write-Host "  Agora voce precisa:"
Write-Host "  1. Abrir o OpenCode normalmente"
Write-Host "  2. Aguardar ele carregar (alguns segundos)"
Write-Host "  3. Fechar o OpenCode"
Write-Host ""
Write-Host "  (Isso instala o plugin no cache interno do OpenCode)"
Write-Host ""
Read-Host "  Pressione ENTER quando tiver aberto E fechado o OpenCode"

# ---- 8. Aplicar fix ESM/Bun --------------------------------------------------------------------------------------------------------
Write-Step "Aplicando correcao de compatibilidade ESM/Bun..."

$cacheDir = "$env:USERPROFILE\.cache\opencode\node_modules\opencode-antigravity-auth"
$storageJs = "$cacheDir\dist\src\plugin\storage.js"

if (Test-Path $storageJs) {
    $content = Get-Content $storageJs -Raw

    # Detectar se ja foi corrigido
    if ($content -match "proper-lockfile replaced") {
        Write-Ok "Correcao ja aplicada anteriormente"
    } else {
        # Correcao 1: import default
        $content = $content -replace 'import lockfile from "proper-lockfile";', `
            ('// proper-lockfile replaced: Bun ESM incompatibility fix (github.com/vagnervrds/opencode-antigravity-auth)' + "`n" + `
            'const lockfile = { lock: async () => async () => {} };')

        # Correcao 2: import * as (variante alternativa que pode aparecer)
        $content = $content -replace 'import \* as lockfileModule from "proper-lockfile";[\r\n]+const lockfile = lockfileModule\.default \?\? lockfileModule;', `
            ('// proper-lockfile replaced: Bun ESM incompatibility fix (github.com/vagnervrds/opencode-antigravity-auth)' + "`n" + `
            'const lockfile = { lock: async () => async () => {} };')

        Set-Content -Path $storageJs -Value $content -Encoding UTF8 -NoNewline
        Write-Ok "Correcao aplicada em $storageJs"
    }
} else {
    Write-Warn "Cache do plugin nao encontrado em $cacheDir"
    Write-Warn "O fix sera aplicado automaticamente na proxima vez que o OpenCode abrir"

    # Salvar script de fix para rodar depois
    $fixScript = "$configDir\apply-fix.ps1"
    Set-Content -Path $fixScript -Value @"
`$storageJs = "`$env:USERPROFILE\.cache\opencode\node_modules\opencode-antigravity-auth\dist\src\plugin\storage.js"
if (Test-Path `$storageJs) {
    `$c = Get-Content `$storageJs -Raw
    if (`$c -notmatch "proper-lockfile replaced") {
        `$c = `$c -replace 'import lockfile from "proper-lockfile";', "// proper-lockfile replaced`nconst lockfile = { lock: async () => async () => {} };"
        Set-Content -Path `$storageJs -Value `$c -Encoding UTF8 -NoNewline
        Write-Host "Fix aplicado com sucesso!" -ForegroundColor Green
    } else {
        Write-Host "Fix ja estava aplicado." -ForegroundColor Yellow
    }
} else {
    Write-Host "Plugin ainda nao instalado no cache. Abra o OpenCode primeiro." -ForegroundColor Yellow
}
"@ -Encoding UTF8
    Write-Warn "Script de fix salvo em: $fixScript"
    Write-Warn "Rode-o apos abrir e fechar o OpenCode uma vez"
}

# ---- 9. Autenticacao Google --------------------------------------------------------------------------------------------------------
Write-Step "Autenticacao com o Google..."
Write-Host ""
Write-Host "  Para ativar o Gemini Code Assist na sua conta Google ($googleEmail):"
Write-Host ""
Write-Host "  IMPORTANTE: Antes de fazer login no OpenCode, voce PRECISA verificar"
Write-Host "  a conta no Antigravity IDE ou VS Code com Gemini Code Assist."
Write-Host ""
Write-Host "  Opcao recomendada - Antigravity IDE:"
Write-Host "    1. Abra o Antigravity (esta instalado no seu PC)"
Write-Host "    2. Faca login com $googleEmail"
Write-Host "    3. Aceite os termos do Gemini Code Assist"
Write-Host "    4. Feche o Antigravity"
Write-Host ""
Write-Host "  Opcao alternativa - VS Code:"
Write-Host "    1. Instale a extensao 'Gemini Code Assist' no VS Code"
Write-Host "    2. Faca login com $googleEmail e aceite os termos"
Write-Host ""
$doLogin = Read-Host "  Ja verificou a conta? Quer fazer o login agora? [S/N]"

if ($doLogin -match "^[Ss]") {
    Write-Host ""
    Write-Host "  Abrindo tela de login..." -ForegroundColor Cyan
    Write-Host "  Selecione 'Google' -> 'OAuth with Google (Antigravity)'"
    Write-Host ""
    Start-Sleep -Seconds 2
    & $opencodeExe auth login
}

# ---- 10. Conclusao --------------------------------------------------------------------------------------------------------------------------
Write-Host ""
Write-Host "  ================================================" -ForegroundColor Magenta
Write-Host "  Instalacao concluida!" -ForegroundColor Green
Write-Host ""
Write-Host "  Proximos passos:" -ForegroundColor White
Write-Host "  1. Abra o OpenCode"
Write-Host "  2. Selecione um modelo como 'google/antigravity-gemini-3-flash'"
Write-Host "  3. Envie uma mensagem para testar"
Write-Host ""
Write-Host "  Se receber '403 Verify your account': verifique a conta no"
Write-Host "  Antigravity IDE primeiro (veja instrucoes acima)"
Write-Host ""
Write-Host "  Problemas? github.com/vagnervrds/opencode-antigravity-auth" -ForegroundColor Cyan
Write-Host "  Fix descoberto com Claude AI (claude-sonnet-4-6)" -ForegroundColor DarkGray
Write-Host "  ================================================" -ForegroundColor Magenta
Write-Host ""
