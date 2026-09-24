# mandatos-optimos

Numero optimo de mandatos externos de gestion activa.

Codigo en **MATLAB**. Los datos de gestores son internos del BCRP y **no se
versionan**: el repositorio contiene solo codigo y documentacion.

## Estructura

```
scripts/   rutinas ejecutables (Main_*.m)
src/       funciones reutilizables
data/      archivos .mat locales -- ignorados por git, ver data/README.md
outputs/   graficos y tablas generados -- ignorados por git
```

## Reproducir el analisis

Los `.mat` no estan en el repositorio. Para correr el codigo hay que
colocarlos en `data/` con los nombres que documenta
[`data/README.md`](data/README.md).

```matlab
addpath(genpath('src'));
run('scripts/Main_OptimalAllocation_Managers_V2.m');
```

Los resultados se escriben en `outputs/`, que git ignora: se regeneran
corriendo el codigo, no se guardan.

## Reglas del repositorio

1. **Ningun dato entra al repositorio.** El `.gitignore` bloquea `.mat`,
   `.csv`, `.xlsx` y formatos afines en cualquier ruta. Un repo privado sigue
   siendo un servidor externo, y el historial de git conserva el archivo
   aunque despues se borre.
2. **Ningun grafico ni salida entra al repositorio.** Se regeneran.
3. **Antes de cada commit**, revisar `git status --short` linea por linea.
