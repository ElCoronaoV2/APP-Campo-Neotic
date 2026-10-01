# Dataset de Municipios

## Origen

Archivo del usuario: `municipios_espana.json` (1.4 MB, 8.131 entradas originales con muchos duplicados por ID).

## Esquema origen vs destino

| Campo | Origen | Destino | Notas |
|---|---|---|---|
| id | string (con duplicados) | int→str | Se preserva aunque haya duplicados; no es PK |
| nombre | str | `nombre_oficial` | Conserva tildes y formato original |
| provincia | str | provincia | Sin cambios |
| comunidad | str | comunidad | Sin cambios |
| alias | list[str] | `variantes` | Convertido a minúsculas, sin duplicados |
| — | — | variante normalizada | **Añadida**: nombre_oficial en minúsculas, sin tildes, sin `/` ni `-`, en primera posición |

## Transformación

Script: `backend/scripts/transform_municipios.py`

```bash
python3 backend/scripts/transform_municipios.py \
  /ruta/a/municipios_espana.json \
  app/assets/data/municipios.json
```

Salida: 8.131 municipios únicos (deduplicados por `nombre_oficial + provincia`).

Tamaño final: ~1 MB. Se incluye en el APK (`flutter assets`).

## Adiós ideal: añadir variantes fonéticas/valencianas

El dataset actual solo trae los alias "oficiales" en minúsculas. Para que el fuzzy matching rinda al máximo con valenciano y fonética rápida, conviene ampliar las variantes. Ejemplos recomendados:

| nombre_oficial | Variantes actuales | Variantes recomendadas (a añadir manualmente) |
|---|---|---|
| Xàtiva | xativa | xativa, jativa, chativa, shativa, satiba |
| Ontinyent | ontinyent | ontinyent, onteniente, onten, ontinete, ontenyent |
| Benigànim | beniganim | beniganim, benigani, benicanim, veniganim |
| Castelló de la Ribera | castello de la ribera | castello de la ribera, villanueva de castellon, villanueva |
| Guadassuar | guadassuar | guadassuar, guadasuar, guadazuar |

Para añadirlas:

1. Editar `municipios_espana.json` o crear `municipios_espana_extra.json` con un array de parches `{id, alias_extra: [...]}`.
2. Modificar `transform_municipios.py` para fusionar los extras en `variantes`.
3. Re-generar `app/assets/data/municipios.json`.

## Por qué el JSON se embebe en el APK

- Fuzzy matching de pueblos **funciona offline desde el primer uso** (requisito del caso de campo sin cobertura).
- 1 MB es aceptable para un APK (Google Play permite hasta 150 MB por APK).
- Se actualiza con cada release del APK. Si se necesita actualización sin release, se puede mover a una pestaña de Sheets como `Fincas_Pueblos` y descargar al login (descartado para MVP por simplicidad).

## Privacidad

- Este dataset es **público** (lista oficial de municipios INE), no contiene datos personales.
- Las **fincas** (datos privados de cada socio) **NO** están en este JSON. Viven en la pestaña `Fincas_Pueblos` de Sheets y se descargan al login, cacheadas localmente.