# Datos

Los CSV reales de gestores **no se versionan** (ver `.gitignore`). Solo se
suben archivos `example_*.csv` con datos sinteticos.

## Esquema

### `returns.csv`
| columna | tipo | nota |
|---|---|---|
| `date` | ISO `YYYY-MM-DD` | fin de periodo |
| `manager_id` | texto | identificador estable del mandato |
| `return` | decimal | `0.012` = 1.2%. **Neto o bruto de comisiones: decidelo una vez y documentalo**, porque el modelo de costos resta fees por separado y contarlos dos veces sesga N* a la baja |

### `benchmark.csv`
| columna | tipo |
|---|---|
| `date` | ISO `YYYY-MM-DD` |
| `benchmark_id` | texto |
| `return` | decimal |

### `managers.csv` (opcional)
| columna | tipo |
|---|---|
| `manager_id` | texto |
| `benchmark_id` | texto |
| `fee` | decimal anual |
| `aum` | numerico |

## Advertencia sobre sesgo de supervivencia

Si tu panel solo contiene gestores vivos hoy, el alpha medio estimado esta
inflado y `N*` saldra mas alto de lo que corresponde. Incluye mandatos
terminados con su historia hasta la fecha de cese, o trata el resultado como
una cota superior y dilo explicitamente.
