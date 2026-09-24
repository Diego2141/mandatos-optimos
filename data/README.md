# Datos

**Ningun archivo de esta carpeta se versiona.** Contiene datos internos del
BCRP sobre gestores externos. El `.gitignore` bloquea `.mat`, `.csv` y `.xlsx`
en todo el arbol del repositorio.

Para correr el codigo, coloca aqui los `.mat` desde la ruta de trabajo en `H:`.

## Archivos esperados

| Archivo | Contenido | Pendiente de documentar |
|---|---|---|
| `ActiveData2.mat` | | variables, dimensiones, frecuencia, periodo |
| `PassiveData2.mat` | | variables, dimensiones, frecuencia, periodo |
| `ManagersActiveData.mat` | | identificadores de gestor, moneda, neto/bruto de comisiones |
| `Global_ActiveData.mat` | | |
| `Global_PassiveData.mat` | | |
| `PassiveData_IndicesGOI.mat` | | |

Esta tabla se completa al revisar el codigo. Sin ella el repositorio no es
reproducible por nadie mas: el codigo esta versionado pero nadie sabe que
tiene que poner en `data/` ni con que formato.

## Preguntas que la documentacion debe responder

- Frecuencia de los retornos (diaria, mensual) y periodo cubierto.
- Si los retornos vienen **netos o brutos de comisiones**. Si ya vienen netos
  y el modelo resta comisiones aparte, el costo se cuenta dos veces y `N*`
  sale sesgado a la baja.
- Si el panel incluye mandatos terminados o solo vigentes. Si solo hay
  vigentes, hay sesgo de supervivencia y `N*` es una cota superior.
- Moneda y si los retornos estan cubiertos cambiariamente.
