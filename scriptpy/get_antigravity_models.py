"""
Script para extrair modelos do banco de dados do Antigravity e gerar configuracao compativel com opencode.json.
O Antigravity IDE e a fonte da verdade - so modelos listados no banco serao incluidos.

Salva o JSON na pasta Installers para ser usado pelos scripts de instalacao.
"""

import sqlite3
import base64
import json
import os
import sys
import re
from pathlib import Path
from datetime import datetime
from typing import Any


def gerar_nome_modelo(nome_detectado: str) -> str:
    """Gera nome formatado com sufixo (Antigravity)"""
    nome = nome_detectado.strip()
    if "(Antigravity)" not in nome and "(antigravity)" not in nome.lower():
        nome = f"{nome} (Antigravity)"
    return nome


PADROES_MODELOS = [
    (r"gemin[iy]?\s*3\s*pro", "gemini-3-pro"),
    (r"gemin[iy]?\s*3\s*flash", "gemini-3-flash"),
    (r"gemin[iy]?\s*2\.5\s*pro", "gemini-2-5-pro"),
    (r"gemin[iy]?\s*2\.5\s*flash", "gemini-2-5-flash"),
    (r"gemin[iy]?\s*2\s*pro", "gemini-2-pro"),
    (r"gemin[iy]?\s*2\s*flash", "gemini-2-flash"),
    (r"claude\s*opus\s*4\.?6?\s*thinking", "claude-opus-4-6-thinking"),
    (r"claude\s*opus\s*4\.?6?(?!\s*thinking)", "claude-opus-4-6"),
    (r"claude\s*sonnet\s*4\.?6?", "claude-sonnet-4-6"),
    (r"claude\s*sonnet\s*4\.?5", "claude-sonnet-4-5"),
]

METADADOS_PADRAO = {
    "gemini": {
        "limit": {"context": 1048576, "output": 65536},
        "modalities": {"input": ["text", "image", "pdf"], "output": ["text"]},
        "variants": {
            "minimal": {"thinkingLevel": "minimal"},
            "low": {"thinkingLevel": "low"},
            "medium": {"thinkingLevel": "medium"},
            "high": {"thinkingLevel": "high"},
        },
    },
    "claude": {
        "limit": {"context": 200000, "output": 64000},
        "modalities": {"input": ["text", "image", "pdf"], "output": ["text"]},
    },
    "claude-thinking": {
        "limit": {"context": 200000, "output": 64000},
        "modalities": {"input": ["text", "image", "pdf"], "output": ["text"]},
        "variants": {
            "low": {"thinkingConfig": {"thinkingBudget": 8192}},
            "medium": {"thinkingConfig": {"thinkingBudget": 16384}},
            "high": {"thinkingConfig": {"thinkingBudget": 32768}},
        },
    },
}


def detectar_familia_modelo(nome: str) -> str:
    """Detecta a familia do modelo (gemini, claude, claude-thinking)"""
    nome_lower = nome.lower()
    if "gemini" in nome_lower:
        return "gemini"
    if "claude" in nome_lower:
        if "thinking" in nome_lower:
            return "claude-thinking"
        return "claude"
    return "unknown"


def gerar_id_modelo(nome_normalizado: str) -> str:
    """Gera ID no formato antigravity-{modelo}"""
    id_formatado = nome_normalizado.lower().replace("_", "-").replace(" ", "-")
    return f"antigravity-{id_formatado}"


def extrair_nome_display(chave: str) -> str:
    """Extrai nome display do modelo a partir da chave normalizada"""
    partes = chave.replace("-", " ").replace("_", " ").split()
    nome_formatado = []
    for p in partes:
        if p.isdigit() or (len(p) > 1 and p[0].isdigit()):
            nome_formatado.append(p)
        else:
            nome_formatado.append(p.capitalize())
    return " ".join(nome_formatado)


def normalizar_nome_modelo(texto: str) -> str | None:
    """Normaliza nome de modelo para chave padrao"""
    texto_lower = texto.lower().replace("-", " ").replace("_", " ")
    for padrao, chave in PADROES_MODELOS:
        if re.search(padrao, texto_lower, re.IGNORECASE):
            return chave
    return None


def decodificar_base64(valor: str) -> bytes | None:
    """Decodifica valor base64 com tratamento de erros"""
    try:
        padding = 4 - len(valor) % 4
        if padding != 4:
            valor = valor + "=" * padding
        return base64.b64decode(valor)
    except Exception:
        return None


def extrair_modelos_protobuf(data: bytes) -> list[dict[str, str]]:
    """Extrai informacoes de modelos de dados protobuf"""
    modelos_encontrados = []
    try:
        texto = data.decode("utf-8", errors="ignore")
        for padrao, chave in PADROES_MODELOS:
            if re.search(padrao, texto, re.IGNORECASE):
                nome_display = extrair_nome_display(chave)
                modelos_encontrados.append(
                    {
                        "chave": chave,
                        "nome_display": nome_display,
                    }
                )
                break
    except Exception:
        pass
    return modelos_encontrados


def obter_caminho_antigravity() -> Path:
    """Retorna caminho do Antigravity baseado no OS"""
    if sys.platform == "win32":
        appdata = os.environ.get("APPDATA", "")
        return Path(appdata) / "Antigravity"
    elif sys.platform == "darwin":
        return Path.home() / "Library" / "Application Support" / "Antigravity"
    else:
        return Path.home() / ".config" / "Antigravity"


def obter_pasta_instaladores() -> Path:
    """Retorna caminho da pasta Installers"""
    script_dir = Path(__file__).parent
    installers_dir = script_dir.parent / "Installers"
    if installers_dir.exists():
        return installers_dir
    return script_dir


def consultar_banco_sqlite(antigravity_path: Path) -> dict[str, Any]:
    """Consulta banco SQLite do Antigravity - FONTE DA VERDADE"""
    state_db = antigravity_path / "User" / "globalStorage" / "state.vscdb"

    resultado = {
        "timestamp": datetime.now().isoformat(),
        "antigravity_path": str(antigravity_path),
        "state_db": str(state_db),
        "db_exists": state_db.exists(),
        "modelos_detectados": [],
        "modelo_atual": None,
        "raw_data": {},
        "error": None,
    }

    if not state_db.exists():
        resultado["error"] = "Banco SQLite nao encontrado - Antigravity instalado?"
        return resultado

    try:
        conn = sqlite3.connect(str(state_db))
        cursor = conn.cursor()

        cursor.execute("""
            SELECT key, value FROM ItemTable
            WHERE key LIKE '%model%'
            OR key LIKE '%Model%'
            OR key LIKE '%agent%'
            OR key LIKE '%cloud%'
            OR key LIKE '%allowed_command%'
        """)

        modelos_vistos = set()

        for key, value in cursor.fetchall():
            if not value:
                continue

            dados = decodificar_base64(value)
            if dados:
                modelos = extrair_modelos_protobuf(dados)
                if modelos:
                    resultado["raw_data"][key] = {
                        "modelos": modelos,
                        "preview": dados[:100].decode("utf-8", errors="replace"),
                    }
                    for m in modelos:
                        chave = m["chave"]
                        if chave not in modelos_vistos:
                            modelos_vistos.add(chave)
                            resultado["modelos_detectados"].append(m)

        conn.close()

    except Exception as e:
        resultado["error"] = str(e)

    if resultado["modelos_detectados"]:
        resultado["modelo_atual"] = resultado["modelos_detectados"][0]

    return resultado


def construir_config_modelo(modelo_info: dict[str, str]) -> dict[str, Any]:
    """Constroi configuracao completa do modelo usando metadados dinamicos"""
    chave = modelo_info["chave"]
    nome_display = modelo_info.get("nome_display", chave)

    familia = detectar_familia_modelo(chave)
    metadados = METADADOS_PADRAO.get(familia, {})

    id_modelo = gerar_id_modelo(chave)
    nome = gerar_nome_modelo(nome_display)

    config = {
        "name": nome,
        "limit": metadados.get("limit", {"context": 1000000, "output": 8192}),
        "modalities": metadados.get(
            "modalities", {"input": ["text"], "output": ["text"]}
        ),
    }

    if "variants" in metadados:
        config["variants"] = metadados["variants"]

    return {id_modelo: config}


def gerar_config_opencode(modelos: list[dict[str, str]]) -> dict[str, Any]:
    """Gera configuracao JSON compativel com opencode.json dos instaladores"""
    config_modelos = {}

    for modelo_info in modelos:
        config_modelo = construir_config_modelo(modelo_info)
        config_modelos.update(config_modelo)

    return {
        "$schema": "https://opencode.ai/config.json",
        "plugin": ["opencode-antigravity-auth@latest"],
        "provider": {"google": {"models": config_modelos}},
    }


def gerar_models_json(modelos: list[dict[str, str]]) -> dict[str, Any]:
    """Gera JSON com apenas os modelos (sem schema/plugin) para ser incluido nos instaladores"""
    config_modelos = {}

    for modelo_info in modelos:
        config_modelo = construir_config_modelo(modelo_info)
        config_modelos.update(config_modelo)

    return config_modelos


def main():
    print("=" * 70)
    print("ANTIGRAVITY MODEL EXTRACTOR")
    print("Fonte da verdade: Banco de dados do Antigravity IDE")
    print("=" * 70)

    antigravity_path = obter_caminho_antigravity()
    print(f"\nAntigravity path: {antigravity_path}")

    print("\nConsultando banco de dados...")
    banco = consultar_banco_sqlite(antigravity_path)

    if banco.get("error"):
        print(f"\n[ERRO] {banco['error']}")
        print("\nCertifique-se de que o Antigravity IDE esta instalado.")
        print("Baixe em: https://antigravity.ai")
        return 1

    if not banco["modelos_detectados"]:
        print("\n[!] Nenhum modelo encontrado no banco de dados")
        print("    Abra o Antigravity IDE e faca login primeiro.")
        return 1

    print(f"\n[OK] Modelos detectados no banco ({len(banco['modelos_detectados'])}):")
    for m in banco["modelos_detectados"]:
        nome = gerar_nome_modelo(m.get("nome_display", m["chave"]))
        print(f"  - {nome}")

    config = gerar_config_opencode(banco["modelos_detectados"])
    models_json = gerar_models_json(banco["modelos_detectados"])

    installers_dir = obter_pasta_instaladores()
    output_config = installers_dir / "antigravity_models_opencode.json"
    output_models = installers_dir / "antigravity_models.json"

    with open(output_config, "w", encoding="utf-8") as f:
        json.dump(config, f, indent=2, ensure_ascii=False)
    print(f"\n[OK] Configuracao completa salva em: {output_config}")

    with open(output_models, "w", encoding="utf-8") as f:
        json.dump(models_json, f, indent=2, ensure_ascii=False)
    print(f"[OK] Modelos (para instaladores) salvos em: {output_models}")

    print("\n" + "=" * 70)
    print("MODELOS PARA INSTALADORES (antigravity_models.json)")
    print("=" * 70)
    print(json.dumps(models_json, indent=2, ensure_ascii=False))

    print("\n" + "=" * 70)
    print("CONFIGURACAO COMPLETA (antigravity_models_opencode.json)")
    print("=" * 70)
    print(json.dumps(config, indent=2, ensure_ascii=False))

    print("\n" + "=" * 70)
    print("PROXIMOS PASSOS:")
    print("  1. Os instaladores usarao antigravity_models.json automaticamente")
    print("  2. Execute este script sempre que os modelos do Antigravity mudarem")
    print("=" * 70)

    return 0


if __name__ == "__main__":
    sys.exit(main())
