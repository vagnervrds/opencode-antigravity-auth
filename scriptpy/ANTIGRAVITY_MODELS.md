# Antigravity Models - Métodos de Interceptação Dinâmica

## Resumo

Encontrei que o Antigravity é uma IDE baseada no VS Code (versão 1.21.9) que usa modelos Gemini do Google Cloud. O modelo atual em uso é **Gemini 3 Flash**.

## Métodos para Interceptar Modelos Dinamicamente

### Método 1: Consulta ao Banco de Dados SQLite (RECOMENDADO)

O Antigravity armazena preferências de modelos em um banco de dados SQLite:
```
%APPDATA%\Antigravity\User\globalStorage\state.vscdb
```

**Script**: `list_antigravity_models.py`

Este é o método mais confiável para obter informações sobre modelos.

### Método 2: Análise de Logs em Tempo Real

O Antigravity faz requisições periódicas (a cada 5 minutos) para buscar modelos disponíveis:
```
POST v1internal:fetchAvailableModels
```

**Logs em**: `%APPDATA%\Antigravity\logs\*\cloudcode.log`

**Script com monitoramento**: `get_antigravity_models.py --monitor`

### Método 3: Interceptação de Rede (Avançado)

Para capturar a resposta da API em tempo real:

1. **Usar Proxy** (como mitmproxy):
```bash
# Instalar mitmproxy
pip install mitmproxy

# Executar com certificado
mitmproxy --mode upstream -p 8080

# Configurar Antigravity para usar proxy
# Set environment variable: HTTP_PROXY=http://localhost:8080
```

2. **Script Python com requests intercept**:
```python
import mitmproxy.http
from mitmproxy import ctx

class ModelInterceptor:
    def request(self, flow: mitmproxy.http.HTTPFlow):
        if "fetchAvailableModels" in flow.request.path:
            ctx.log.info(f"Model request: {flow.request.path}")
    
    def response(self, flow: mitmproxy.http.HTTPFlow):
        if "fetchAvailableModels" in flow.request.path:
            ctx.log.info(f"Model response: {flow.response.text}")
            # Salvar resposta para análise
            with open("models_response.json", "w") as f:
                f.write(flow.response.text)

addons = [ModelInterceptor()]
```

### Método 4: Decodificação de Dados Protobuf

Os dados de modelos são armazenados em formato Protocol Buffers. Exemplo de decodificação:

```python
import base64

# Dados do campo: antigravity_allowed_command_model_configs
data = "Cg5HZW1pbmkgMyBGbGFzaBIDCPoH..."
decoded = base64.b64decode(data)
# O texto "Gemini 3 Flash" é visível nos bytes decodificados
```

## Modelos Disponíveis Detectados

Com base na análise do banco de dados e padrões:

1. **Gemini 3 Flash** ← Modelo atual em uso
2. Gemini 3 Pro
3. Gemini 2.0 Flash
4. Gemini 2.0 Pro
5. gemini-3-flash
6. gemini-3-pro
7. gemini-2.0-flash
8. gemini-2.0-pro

## Arquivos Criados

1. **list_antigravity_models.py** - Extrai modelos do banco SQLite (mais confiável)
2. **get_antigravity_models.py** - Análise completa + monitoramento em tempo real
3. **get_antigravity_models.ps1** - Versão PowerShell para extração rápida
4. **antigravity_models_list.json** - Resultado da análise
5. **antigravity_models_detailed.json** - Dados completos com logs

## Como Usar

### Para obter lista de modelos:
```bash
python list_antigravity_models.py
```

### Para monitoramento em tempo real (requer watchdog):
```bash
pip install watchdog
python get_antigravity_models.py --monitor
```

### Para análise rápida:
```powershell
powershell -ExecutionPolicy Bypass -File get_antigravity_models.ps1
```

## Atualizando Script de Instalação

Se você tem um script de instalação que precisa dessa lista, use:

```python
import json

# Carregar modelos detectados
with open('antigravity_models_list.json', 'r', encoding='utf-8') as f:
    data = json.load(f)

# Lista de modelos
modelos = data['models']
modelo_atual = data.get('current_model', 'Gemini 3 Flash')

print(f"Modelos disponíveis: {modelos}")
print(f"Modelo atual: {modelo_atual}")
```

## Endpoint da API

O Antigravity consulta:
```
https://daily-cloudcode-pa.googleapis.com/v1internal:fetchAvailableModels
```

Esta API retorna a lista completa de modelos disponíveis para sua conta/ região.

## Próximos Passos

Para obter a lista completa e atualizada de modelos em tempo real:

1. **Método Simples**: Execute `list_antigravity_models.py` periodicamente
2. **Método Avançado**: Configure interceptação de rede com mitmproxy
3. **Método API**: Se tiver acesso à API do Google Cloud, consulte diretamente

Qual script de instalação você quer atualizar com essa lista de modelos?
