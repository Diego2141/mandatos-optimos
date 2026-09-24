# mandatos-optimos

Numero optimo de mandatos externos de gestion activa.

Estado: repositorio inicializado. Sin modelo todavia.

## Entorno

```bash
pip install -e ".[dev]"
pytest
```

## Datos

Los CSV de gestores no se versionan. Ver [`data/README.md`](data/README.md)
para el esquema esperado.

## Estructura

```
src/mandatos/   codigo del paquete
scripts/        analisis ejecutables
tests/          pruebas
data/           CSV locales (ignorados por git)
outputs/        resultados generados (ignorados por git)
```
