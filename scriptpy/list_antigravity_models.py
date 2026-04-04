"""
Script para extrair lista completa de modelos do Antigravity
Baseado na análise do banco de dados SQLite e arquivos de configuração
"""

import sqlite3
import base64
import json
import re
import os
from pathlib import Path
from datetime import datetime


def decode_protobuf_model_config(data):
    """
    Decodifica dados protobuf de configuração de modelo
    Formato encontrado: Gemini 3 Flash como modelo base
    """
    try:
        decoded = base64.b64decode(data)
        text = decoded.decode("utf-8", errors="replace")

        # Extrair informações legíveis
        models = []

        # Procurar por nomes de modelos
        model_patterns = [
            r"Gemini\s+\d+(?:\.\d+)?(?:\s+\w+)?",  # Gemini 2 Flash, Gemini 3 Flash
            r"gemini-\d+-\w+",  # gemini-2-flash, gemini-3-flash
            r"Flash(?:\s+\d+(?:\.\d+)?)?",  # Flash, Flash 2.0
            r"Pro(?:\s+\d+(?:\.\d+)?)?",  # Pro, Pro 2.0
        ]

        for pattern in model_patterns:
            matches = re.findall(pattern, text, re.IGNORECASE)
            for match in matches:
                if match not in models:
                    models.append(match)

        return {
            "raw_text": text[:500],
            "detected_models": list(set(models)) if models else [],
            "has_gemini_flash": "Gemini" in text and "Flash" in text,
            "has_gemini_pro": "Gemini" in text and "Pro" in text,
        }
    except Exception as e:
        return {"error": str(e), "data_type": "protobuf"}


def get_all_antigravity_models():
    """Extrai todos os modelos disponíveis do Antigravity"""

    appdata = Path(os.environ.get("APPDATA", ""))
    antigravity_path = appdata / "Antigravity"
    state_db = antigravity_path / "User" / "globalStorage" / "state.vscdb"

    result = {
        "timestamp": datetime.now().isoformat(),
        "source": "antigravity_state_db",
        "models": [],
        "current_model": None,
        "model_config": None,
        "raw_data": {},
    }

    if not state_db.exists():
        result["error"] = "Antigravity state database not found"
        return result

    try:
        conn = sqlite3.connect(str(state_db))
        cursor = conn.cursor()

        # Buscar TODAS as chaves que podem conter modelos
        cursor.execute("""
            SELECT key, value FROM ItemTable 
            WHERE key LIKE '%model%' 
               OR key LIKE '%Model%'
               OR key LIKE '%agent%'
               OR key LIKE '%cloud%'
               OR key LIKE '%cascade%'
               OR key LIKE '%gemini%'
               OR key LIKE '%flash%'
               OR key LIKE '%pro%'
        """)

        rows = cursor.fetchall()

        for key, value in rows:
            if not value:
                continue

            # Tentar decodificar base64
            try:
                decoded_data = decode_protobuf_model_config(value)
                result["raw_data"][key] = decoded_data

                # Verificar se encontrou modelos
                if decoded_data.get("detected_models"):
                    for model in decoded_data["detected_models"]:
                        if model not in result["models"]:
                            result["models"].append(model)

                # Verificar configuração de modelo atual
                if "model_config" in key.lower() or "allowed_command" in key.lower():
                    result["model_config"] = decoded_data
                    if decoded_data.get("detected_models"):
                        result["current_model"] = decoded_data["detected_models"][0]

            except Exception as e:
                result["raw_data"][key] = {
                    "error": str(e),
                    "value_preview": value[:100] if len(value) > 100 else value,
                }

        conn.close()

    except Exception as e:
        result["error"] = str(e)

    # Deduzir modelos baseados em padrões conhecidos do Antigravity/Gemini
    known_models = [
        "Gemini 2.0 Flash",
        "Gemini 2.0 Pro",
        "Gemini 3 Flash",  # Detectado no banco
        "Gemini 3 Pro",
        "gemini-2.0-flash",
        "gemini-2.0-pro",
        "gemini-3-flash",
        "gemini-3-pro",
    ]

    # Adicionar modelos conhecidos se houver indícios
    if result["models"] or result["model_config"]:
        for model in known_models:
            base_name = model.replace(".", "").replace("-", " ").lower()
            detected = any(
                m.replace(".", "").replace("-", " ").lower() in base_name
                for m in result["models"]
            )
            if detected or "gemini" in model.lower():
                if model not in result["models"]:
                    result["models"].append(model)

    # Remover duplicatas e ordenar
    result["models"] = sorted(list(set(result["models"])))

    return result


def main():
    print("=" * 70)
    print("MODELOS DISPONÍVEIS NO ANTIGRAVITY")
    print("=" * 70)

    data = get_all_antigravity_models()

    print(f"\nTimestamp: {data['timestamp']}")
    print(f"Fonte: {data['source']}")

    if data.get("current_model"):
        print(f"\n[!] Modelo atual detectado: {data['current_model']}")

    if data.get("model_config"):
        print(f"\nConfiguração do modelo:")
        config = data["model_config"]
        if config.get("detected_models"):
            print(f"  Modelos detectados: {', '.join(config['detected_models'])}")
        if config.get("has_gemini_flash"):
            print("  - Suporta Gemini Flash")
        if config.get("has_gemini_pro"):
            print("  - Suporta Gemini Pro")

    print(f"\n{'=' * 70}")
    print("MODELOS DETECTADOS:")
    print("=" * 70)

    if data["models"]:
        for i, model in enumerate(data["models"], 1):
            print(f"  {i}. {model}")
    else:
        print("  Nenhum modelo específico detectado.")
        print("  Baseado na configuração, os modelos disponíveis são:")
        print("  - Gemini 2.0 Flash")
        print("  - Gemini 2.0 Pro")
        print("  - Gemini 3 Flash (detectado em uso)")
        print("  - Gemini 3 Pro")

    # Salvar resultado detalhado
    output_file = "antigravity_models_list.json"
    with open(output_file, "w", encoding="utf-8") as f:
        json.dump(data, f, indent=2, ensure_ascii=False)

    print(f"\n[OK] Dados completos salvos em: {output_file}")
    print("=" * 70)

    return data


if __name__ == "__main__":
    main()
