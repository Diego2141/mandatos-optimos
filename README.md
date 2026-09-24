# mandatos-optimos

Numero optimo de mandatos externos de gestion activa. Codigo en MATLAB.

Los datos de gestores son internos del BCRP y **no se versionan**: el
`.gitignore` bloquea `.mat`, `.csv`, `.xlsx` y formatos afines en cualquier
ruta del repositorio. Los graficos y tablas generados tampoco se versionan;
se reproducen corriendo el codigo.

## Para correr el analisis

Los `.mat` no estan aqui. Hay que copiarlos desde la ruta de trabajo en `H:`
junto a los `.m`.

## Pendiente de documentar

Sin esto el repositorio no es reproducible por nadie mas: el codigo esta
versionado pero nadie sabe que archivos hacen falta ni con que formato.

- Que variables y dimensiones tiene cada `.mat`, su frecuencia y periodo.
- Si los retornos vienen **netos o brutos de comisiones**. Si ya vienen netos
  y el modelo resta comisiones aparte, el costo se cuenta dos veces y `N*`
  sale sesgado a la baja.
- Si el panel incluye mandatos terminados o solo vigentes. Si solo hay
  vigentes, hay sesgo de supervivencia y `N*` es una cota superior.
- Moneda y si los retornos estan cubiertos cambiariamente.

## Antes de cada commit

```
git status --short
```

Revisar linea por linea. Si aparece un `.mat`, `.xlsx` o `.png`, parar.
