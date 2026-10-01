#!/usr/bin/env python3
"""
Transforma municipios_espana.json (schema: id, nombre, provincia, comunidad, alias[])
al formato que consume la app móvil voz-campo (schema: id, nombre_oficial, provincia,
comunidad, variantes[]).

Ademas, anade el nombre_oficial normalizado (lowercase, sin tildes, sin /) a variantes,
para mejorar el fuzzy matching cuando el usuario dice el nombre "limpio" del pueblo.
"""
import json
import sys
import unicodedata
from pathlib import Path


def normalize(s: str) -> str:
    if s is None:
        return ""
    nfkd = unicodedata.normalize("NFKD", s)
    no_accents = "".join(c for c in nfkd if not unicodedata.combining(c))
    return no_accents.lower().replace("/", " ").replace("-", " ").strip()


def transform(src_path: Path, dst_path: Path) -> int:
    with src_path.open("r", encoding="utf-8") as f:
        data = json.load(f)

    out = []
    seen = set()
    for item in data:
        nombre = (item.get("nombre") or "").strip()
        if not nombre:
            continue

        provincia = (item.get("provincia") or "").strip()
        dedup_key = (normalize(nombre), normalize(provincia))
        if dedup_key in seen:
            continue
        seen.add(dedup_key)

        variantes = []
        for v in item.get("alias") or []:
            v = (v or "").strip().lower()
            if v and v not in variantes:
                variantes.append(v)

        oficial_norm = normalize(nombre)
        if oficial_norm and oficial_norm not in variantes:
            variantes.insert(0, oficial_norm)

        out.append({
            "id": str(item.get("id", "")).strip(),
            "nombre_oficial": nombre,
            "provincia": provincia,
            "comunidad": (item.get("comunidad") or "").strip(),
            "variantes": variantes,
        })

    dst_path.parent.mkdir(parents=True, exist_ok=True)
    with dst_path.open("w", encoding="utf-8") as f:
        json.dump(out, f, ensure_ascii=False, separators=(",", ":"))

    return len(out)


def main():
    if len(sys.argv) < 3:
        print("Uso: transform_municipios.py <origen.json> <destino.json>", file=sys.stderr)
        sys.exit(1)

    src = Path(sys.argv[1])
    dst = Path(sys.argv[2])
    if not src.exists():
        print(f"ERROR: no existe {src}", file=sys.stderr)
        sys.exit(1)

    n = transform(src, dst)
    print(f"Transformados {n} municipios -> {dst}")


if __name__ == "__main__":
    main()