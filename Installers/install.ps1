# install.ps1 - Instalador do opencode-antigravity-auth para Windows
# Corrige automaticamente a incompatibilidade ESM/Bun do proper-lockfile
# Descoberto com ajuda do Claude AI (claude-sonnet-4-6)

$ErrorActionPreference = "Stop"

$INSTALLER_BUILD = 4

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

# ---- 3. Limpar credenciais existentes (apenas Google) -------------------------------------------------------------------
Write-Step "Limpeza de credenciais do Google..."
Write-Host ""
Write-Host " Deseja remover credenciais do Google antes de instalar?" -ForegroundColor White
Write-Host " (Recomendado se voce teve erros de autenticacao ou 403)" -ForegroundColor Yellow
Write-Host ""
Write-Host " [S] Sim - limpar credenciais do Google"
Write-Host " [N] Nao - manter credenciais existentes"
Write-Host ""
$cleanChoice = Read-Host " Opcao [S/N]"

if ($cleanChoice -match "^[Ss]") {
    $accountsFile = "$configDir\antigravity-accounts.json"
    
    if (Test-Path $accountsFile) {
        Remove-Item $accountsFile -Force
        Write-Ok "Removido: $accountsFile"
    }
    
    $authFile = "$env:LOCALAPPDATA\OpenCode\auth.json"
    $authFile2 = "$env:USERPROFILE\.local\share\opencode\auth.json"
    
    foreach ($authPath in @($authFile, $authFile2)) {
        if (Test-Path $authPath) {
            try {
                $authData = Get-Content $authPath -Raw | ConvertFrom-Json
                if ($authData.PSObject.Properties.Name -contains "google") {
                    $authData.PSObject.Properties.Remove("google")
                    $authData | ConvertTo-Json -Depth 10 | Set-Content $authPath -Encoding UTF8
                    Write-Ok "Credenciais do Google removidas de $authPath"
                } else {
                    Write-Host "  Nenhuma credencial do Google em $authPath"
                }
            } catch {
                Write-Warn "Erro ao processar $authPath - mantendo arquivo"
            }
        }
    }
    
    $cacheDir = "$env:USERPROFILE\.cache\opencode"
    if (Test-Path $cacheDir) {
        Remove-Item $cacheDir -Recurse -Force
        Write-Ok "Cache limpo: $cacheDir"
    }
	Write-Ok "Credenciais do Google removidas - instalacao limpa"
} else {
	Write-Ok "Credenciais mantidas"
}

# ---- 4. Perguntar conta Google ----------------------------------------------------------------------------------------------------
Write-Step "Conta Google para autenticacao..."
Write-Host ""
Write-Host "  Qual conta Google voce vai usar? (ex: seuemail@gmail.com)"
Write-Host "  Dica: use uma conta Google estabelecida, NAO uma conta nova"
Write-Host ""
$googleEmail = Read-Host "  E-mail"
if (-not $googleEmail) { Write-Fail "E-mail nao informado." }

# ---- 5. Verificacao da conta Google (IMPORTANTE) ------------------------------------------------------------------------
Write-Step "Verificacao da conta Google - PASSO OBRIGATORIO"
Write-Host ""
Write-Host "  IMPORTANTE: Antes de continuar, voce PRECISA verificar sua conta" -ForegroundColor Yellow
Write-Host "  Google para o Gemini Code Assist. Sem isso, voce recebera erro 403." -ForegroundColor Yellow
Write-Host ""
Write-Host "  Por que isso e necessario?" -ForegroundColor White
Write-Host "  O Google exige que a API 'Gemini for Google Cloud' esteja ativa"
Write-Host "  na sua conta antes de aceitar requisicoes do Antigravity."
Write-Host ""
Write-Host "  Opcao 1 - Antigravity IDE (mais facil, recomendada):" -ForegroundColor Green
Write-Host "    1. Abra o Antigravity IDE (baixe em antigravity.ai se nao tiver)"
Write-Host "    2. Faca login com $googleEmail"
Write-Host "    3. Aceite os termos do Gemini Code Assist quando solicitado"
Write-Host "    4. Aguarde aparecer sugestoes de codigo (prova que funcionou)"
Write-Host "    5. Feche o Antigravity"
Write-Host ""
Write-Host "  Opcao 2 - VS Code com Gemini Code Assist:" -ForegroundColor Cyan
Write-Host "    1. Instale a extensao 'Gemini Code Assist' no VS Code"
Write-Host "    2. Faca login com $googleEmail"
Write-Host "    3. Aceite os termos quando solicitado"
Write-Host ""
Write-Host "  Opcao 3 - Google Cloud Console (avancado):" -ForegroundColor DarkGray
Write-Host "    1. Acesse console.cloud.google.com"
Write-Host "    2. Busque por 'Cloud AI Companion API'"
Write-Host "    3. Clique em 'Enable' para o seu projeto"
Write-Host ""
$verified = Read-Host "  Ja fez a verificacao? [S/N]"
if ($verified -notmatch "^[Ss]") {
    Write-Host ""
    Write-Warn "Continuando sem verificacao - voce pode receber erro 403 mais tarde."
    Write-Warn "Se isso acontecer, faca a verificacao e execute o instalador novamente."
}

# ---- 6. Perguntar modelos (dinamico ou fallback) ------------------------------------------------------------------------
Write-Step "Selecao de modelos..."

$scriptDir = Split-Path -Parent $PSCommandPath
$modelsJsonPath = Join-Path $scriptDir "antigravity_models.json"

if (Test-Path $modelsJsonPath) {
    Write-Ok "Modelos dinamicos encontrados em: $modelsJsonPath"
    $selectedModels = Get-Content $modelsJsonPath -Raw
    Write-Host ""
    Write-Host " Modelos disponiveis (do Antigravity):"
    try {
        $modelsObj = $selectedModels | ConvertFrom-Json
        $modelsObj.PSObject.Properties | ForEach-Object {
            Write-Host "  - $($_.Value.name)"
        }
    } catch {
        Write-Host "  (lista nao disponivel)"
    }
} else {
    Write-Warn "antigravity_models.json nao encontrado - usando fallback"
    Write-Host ""
    Write-Host " Quais modelos deseja configurar?"
    Write-Host " [1] Todos (Gemini 3 Pro/Flash + Claude Opus/Sonnet) - Recomendado"
    Write-Host " [2] Apenas Gemini (Gemini 3 Pro e Flash)"
    Write-Host " [3] Apenas Claude (Opus 4.6 Thinking e Sonnet 4.6)"
    Write-Host ""
    $modelChoice = Read-Host " Opcao [1/2/3]"
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
"minimal": { "thinkingLevel": "minimal" },
"low": { "thinkingLevel": "low" },
"medium": { "thinkingLevel": "medium" },
"high": { "thinkingLevel": "high" }
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
"minimal": { "thinkingLevel": "minimal" },
"low": { "thinkingLevel": "low" },
"medium": { "thinkingLevel": "medium" },
"high": { "thinkingLevel": "high" }
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
        "2" { $geminiModels }
        "3" { $claudeModels }
        default { $allModels }
    }
}

# ---- 7. Criar/atualizar opencode.json ------------------------------------------------------------------------------------
Write-Step "Criando opencode.json..."

$opencodeJson = "$configDir\\opencode.json"

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

if (Test-Path $modelsJsonPath) {
    $newConfig = @"
{
"`$schema": "https://opencode.ai/config.json",
"plugin": ["opencode-antigravity-auth@latest"],
"provider": {
"google": {
"models": $selectedModels
}
}
}
"@
} else {
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
}

Set-Content -Path $opencodeJson -Value $newConfig -Encoding UTF8
Write-Ok "opencode.json criado"

# ---- 8. Instalar plugin via npm ------------------------------------------------------------------------------------------------
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

# ---- 9. Abrir OpenCode para instalar no cache --------------------------------------------------------------------
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

# ---- 10. Aplicar fix ESM/Bun --------------------------------------------------------------------------------------------------------
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
        $content = $content -replace 'import lockfile from "proper-lockfile";', ('// proper-lockfile replaced: Bun ESM incompatibility fix (github.com/vagnervrds/opencode-antigravity-auth)' + "`n" + 'const lockfile = { lock: async () => async () => {} };')

        # Correcao 2: import * as (variante alternativa que pode aparecer)
        $content = $content -replace 'import \* as lockfileModule from "proper-lockfile";[\r\n]+const lockfile = lockfileModule\.default \?\? lockfileModule;', ('// proper-lockfile replaced: Bun ESM incompatibility fix (github.com/vagnervrds/opencode-antigravity-auth)' + "`n" + 'const lockfile = { lock: async () => async () => {} };')

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
        `$c = `$c -replace 'import lockfile from "proper-lockfile";', ("// proper-lockfile replaced`nconst lockfile = { lock: async () => async () => {} };")
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

# ---- 11. Autenticacao Google --------------------------------------------------------------------------------------------------------
Write-Step "Autenticacao com o Google..."
Write-Host ""
Write-Host "  Vamos fazer o login com $googleEmail no OpenCode."
Write-Host ""
Write-Host "  Na tela de login, selecione:"
Write-Host "  'Google' -> 'OAuth with Google (Antigravity)'"
Write-Host ""
Write-Host "  LEMBRE-SE: Se receber erro 403 'Verify your account' apos o login," -ForegroundColor Yellow
Write-Host "  voce precisa verificar a conta no Antigravity IDE primeiro (passo 5)." -ForegroundColor Yellow
Write-Host ""
Write-Host "  DICA - Project ID: quando o login perguntar 'Project ID'," -ForegroundColor Cyan
Write-Host "  deixe em BRANCO e pressione ENTER (a menos que voce saiba" -ForegroundColor Cyan
Write-Host "  exatamente qual project ID usar e ja tenha a API ativada nele)." -ForegroundColor Cyan
Write-Host "  Preencher um Project ID incorreto causa erro 403 com a mensagem:" -ForegroundColor Cyan
Write-Host "  'Gemini for Google Cloud API has not been used in project...'." -ForegroundColor Cyan
Write-Host ""
$doLogin = Read-Host "  Quer fazer o login agora? [S/N]"

if ($doLogin -match "^[Ss]") {
    Write-Host ""
    Write-Host "  Abrindo tela de login..." -ForegroundColor Cyan
    Start-Sleep -Seconds 2
    & $opencodeExe auth login
}

# ---- 12. Conclusao --------------------------------------------------------------------------------------------------------------------------
Write-Host ""
Write-Host "  ================================================" -ForegroundColor Magenta
Write-Host "  Instalacao concluida!" -ForegroundColor Green
Write-Host ""
Write-Host "  Proximos passos:" -ForegroundColor White
Write-Host "  1. Abra o OpenCode"
Write-Host "  2. Selecione um modelo como 'google/antigravity-gemini-3-flash'"
Write-Host "  3. Envie uma mensagem para testar"
Write-Host ""
Write-Host "  Solucao de problemas:" -ForegroundColor Yellow
Write-Host ""
Write-Host "  Erro '403 Verify your account':"
Write-Host "    -> Abra o Antigravity IDE, faca login com $googleEmail"
Write-Host "    -> Aceite os termos do Gemini Code Assist"
Write-Host "    -> Execute este instalador novamente (opcao S na limpeza)"
Write-Host ""
Write-Host "  Erro '403 Gemini for Google Cloud API has not been used':"
Write-Host "    -> Acesse console.cloud.google.com"
Write-Host "    -> Busque por 'Cloud AI Companion API' e clique em Enable"
Write-Host "    -> OU use o Antigravity IDE para ativar automaticamente"
Write-Host "    -> OU refaca o login deixando o Project ID em BRANCO"
Write-Host ""
Write-Host "  Erro 'No Antigravity accounts configured':"
Write-Host "    -> Execute este instalador novamente (opcao S na limpeza)"
Write-Host "    -> Certifique-se de fazer login com 'OAuth with Google (Antigravity)'"
Write-Host ""
Write-Host "  Problemas? github.com/vagnervrds/opencode-antigravity-auth" -ForegroundColor Cyan
Write-Host "  Fix descoberto com Claude AI (claude-sonnet-4-6)" -ForegroundColor DarkGray
Write-Host "  ================================================" -ForegroundColor Magenta
Write-Host ""
