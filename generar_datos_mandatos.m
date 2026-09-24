%% Apilar bases activas y pasivas e inspeccionar sus variables (MATLAB R2024b)
% Guardar este script en la carpeta Codigo y ejecutarlo.
% Admite .mat (una tabla, o variable con el nombre del archivo), .xlsx,
% .xls, .csv y .parquet. Para Excel se lee la primera hoja.
% No elimina duplicados, no renumera fondos y no transforma tasas/comisiones.
% Los reportes quedan en los MAT y se muestran en la ventana de comandos.
clear; clc;

rutaCodigo = 'H:\DPINV\CARPETAS PERSONALES\DIEGO\8. Numero Optimo AM\Número Óptimo de Mandatos\Codigo';
rutaData = fullfile(rutaCodigo, 'Data');
assert(isfolder(rutaData), 'No existe la carpeta: %s', rutaData);

activos = ["data_global", "data_short", "data_ultrashort"];
pasivos = ["passive_data_global", "passive_data_short", "passive_data_ultrashort"];

% Se validan ambos grupos antes de guardar resultados.
[ActiveData, InspeccionActiva] = apilar(rutaData, activos);
[PassiveData, InspeccionPasiva] = apilar(rutaData, pasivos);

% Variables ActiveData y PassiveData: compatibles con load y acceso .fund, etc.
% La procedencia por fila se conserva aparte, sin agregar columnas a las bases.
save(fullfile(rutaCodigo, 'ActiveData2.mat'), ...
    'ActiveData', 'InspeccionActiva', '-v7.3');
save(fullfile(rutaCodigo, 'PassiveData2.mat'), ...
    'PassiveData', 'InspeccionPasiva', '-v7.3');
fprintf('\nArchivos guardados en:\n%s\n', rutaCodigo);

%% Funciones locales
function [T, informe] = apilar(carpeta, nombres)
    partes = cell(numel(nombres),1);
    origen = cell(numel(nombres),1);
    resumen = table();
    detalle = table();
    for i = 1:numel(nombres)
        archivo = localizar(carpeta, nombres(i));
        A = leerTabla(archivo, nombres(i));
        fprintf('\nArchivo: %s | Filas: %d | Variables: %d\n', ...
            archivo, height(A), width(A));
        D = inspeccionar(A, nombres(i));
        disp(D);
        detalle = [detalle; D]; %#ok<AGROW>
        resumen = [resumen; table(string(archivo), height(A), width(A), ...
            'VariableNames', {'Archivo','Filas','NumVariables'})]; %#ok<AGROW>
        if i > 1
            ref = partes{1};
            faltan = setdiff(ref.Properties.VariableNames, A.Properties.VariableNames);
            sobran = setdiff(A.Properties.VariableNames, ref.Properties.VariableNames);
            assert(isempty(faltan) && isempty(sobran), ...
                'Columnas incompatibles en %s. Faltan: %s. Sobran: %s.', ...
                archivo, strjoin(faltan, ', '), strjoin(sobran, ', '));
            A = A(:,ref.Properties.VariableNames);
            for j = 1:width(A)
                v = A.Properties.VariableNames{j};
                assert(strcmp(class(A.(v)), class(ref.(v))), ...
                    'Tipo incompatible en %s, columna %s: %s frente a %s.', ...
                    archivo, v, class(A.(v)), class(ref.(v)));
                assert(isequal(size(A.(v),2:ndims(A.(v))), ...
                    size(ref.(v),2:ndims(ref.(v)))), ...
                    'Dimensiones incompatibles en %s, columna %s.', archivo, v);
            end
        end
        partes{i} = A;
        origen{i} = repmat(nombres(i),height(A),1);
    end
    T = vertcat(partes{:});
    assert(height(T) == sum(resumen.Filas), 'El total de filas no coincide.');
    informe.Archivos = resumen;
    informe.PorArchivo = detalle;
    informe.Consolidado = inspeccionar(T, "CONSOLIDADO");
    informe.OrigenPorFila = vertcat(origen{:});
    informe.FechaEjecucion = datetime('now');
    fprintf('\nRESUMEN DEL GRUPO\n'); disp(resumen);
    fprintf('CONSOLIDADO: %d filas y %d variables\n', height(T), width(T));
    disp(informe.Consolidado);
    % La inspeccion no descarta observaciones duplicadas.
    try
        informe.FilasDuplicadas = height(T)-height(unique(T,'rows'));
        fprintf('Filas duplicadas exactas adicionales: %d (se conservan).\n', ...
            informe.FilasDuplicadas);
    catch
        informe.FilasDuplicadas = NaN;
        fprintf('No se pudo evaluar duplicacion exacta para estos tipos.\n');
    end
    if all(ismember({'fund','date'},T.Properties.VariableNames))
        try
            informe.ClavesFundDateRepetidas = height(T)-height(unique(T(:,{'fund','date'}),'rows'));
            fprintf('Repeticiones adicionales de (fund,date): %d.\n', ...
                informe.ClavesFundDateRepetidas);
            if informe.ClavesFundDateRepetidas > 0
                warning('Hay claves (fund,date) repetidas: revisar fondos compartidos entre segmentos. No se modificaron IDs.');
            end
        catch
            informe.ClavesFundDateRepetidas = NaN;
        end
    end
end

function archivo = localizar(carpeta, nombre)
    extensiones = [".mat", ".xlsx", ".xls", ".csv", ".parquet"];
    candidatos = fullfile(string(carpeta), nombre + extensiones);
    candidatos = candidatos(isfile(candidatos));
    assert(~isempty(candidatos), 'No se encontro un archivo compatible para %s.', nombre);
    assert(numel(candidatos)==1, ...
        'Hay varias extensiones para %s. Deje una sola version o ajuste localizar().', nombre);
    archivo = candidatos(1);
end

function T = leerTabla(archivo, nombre)
    [~,~,ext] = fileparts(archivo);
    switch lower(ext)
        case '.mat'
            S = load(archivo);
            if isfield(S,char(nombre)) && istable(S.(char(nombre)))
                T = S.(char(nombre));
            else
                campos = fieldnames(S);
                esTabla = cellfun(@(c) istable(S.(c)),campos);
                candidatos = campos(esTabla);
                assert(numel(candidatos)==1, ...
                    ['El MAT %s debe contener una tabla unica o una tabla con ' ...
                     'el mismo nombre del archivo. Revise su contenido con whos -file.'], archivo);
                T = S.(candidatos{1});
            end
        case '.parquet'
            T = parquetread(archivo);
        otherwise
            T = readtable(archivo, 'VariableNamingRule','preserve', 'TextType','string');
    end
    assert(istable(T), 'El contenido de %s no es una tabla.', archivo);
end

function R = inspeccionar(T, etiqueta)
    p = width(T);
    Archivo = repmat(string(etiqueta),p,1);
    Variable = string(T.Properties.VariableNames(:));
    Tipo = strings(p,1); Dimensiones = strings(p,1);
    Filas = repmat(height(T),p,1);
    Elementos = zeros(p,1); NoFaltantes = nan(p,1); Faltantes = nan(p,1);
    PctFaltantes = nan(p,1); UnicosNoFaltantes = nan(p,1);
    Minimo = strings(p,1); Maximo = strings(p,1);
    Media = nan(p,1); DesvEstandar = nan(p,1); Infinitos = nan(p,1);
    for j = 1:p
        x = T.(T.Properties.VariableNames{j});
        Tipo(j) = string(class(x));
        Dimensiones(j) = strjoin(string(size(x)), 'x');
        Elementos(j) = numel(x);
        try
            m = ismissing(x);
            if isstring(x) || iscellstr(x)
                m = m | strlength(strtrim(string(x)))==0;
            end
            Faltantes(j) = nnz(m);
            NoFaltantes(j) = numel(x)-nnz(m);
            if numel(x)>0
                PctFaltantes(j) = 100*nnz(m)/numel(x);
            end
            y = x(~m);
            try
                UnicosNoFaltantes(j) = numel(unique(y));
            catch
                % NaN indica que la metrica no es aplicable al tipo.
            end
            if ~isempty(y) && (isnumeric(y) || islogical(y)) && isreal(y)
                Infinitos(j) = nnz(isinf(y));
                Minimo(j) = string(min(y)); Maximo(j) = string(max(y));
                Media(j) = mean(double(y)); DesvEstandar(j) = std(double(y));
            elseif ~isempty(y) && (isdatetime(y) || isduration(y))
                Minimo(j) = string(min(y)); Maximo(j) = string(max(y));
            end
        catch
            % Tipos anidados/no compatibles: se reportan clase y dimensiones.
        end
    end
    R = table(Archivo,Variable,Tipo,Dimensiones,Filas,Elementos,NoFaltantes, ...
        Faltantes,PctFaltantes,UnicosNoFaltantes,Minimo,Maximo,Media,DesvEstandar,Infinitos);
    % Conteos por elemento; para variables de una columna equivalen a filas.
    % Faltantes: NaN, NaT, missing, undefined y texto vacio/blanco.
    % Inf no se considera faltante. NaN en metricas significa no aplicable.
end
















%% Comparación de ActiveData y ActiveData2
clear; clc;

ruta = 'H:\DPINV\CARPETAS PERSONALES\DIEGO\8. Numero Optimo AM\Número Óptimo de Mandatos\Codigo';

A = cargarTabla(fullfile(ruta, 'ActiveData.mat'));
B = cargarTabla(fullfile(ruta, 'ActiveData2.mat'));

% Si las fechas son texto, indicar el formato cuando sea necesario.
% Ejemplos: 'yyyy-MM', 'yyyy-MM-dd', 'MM/yyyy', 'dd/MM/yyyy'.
formatoAnterior = '';
formatoNueva    = '';

% Solo completar si las fechas están almacenadas como números:
% 'datenum', 'excel' o 'yyyymmdd'.
fechaNumericaAnterior = '';
fechaNumericaNueva    = '';

%% 1. Tabla general
[nA, idA] = contarPortafolios(A);
[nB, idB] = contarPortafolios(B);

[dA, fechaA] = obtenerFechas(A, formatoAnterior, fechaNumericaAnterior);
[dB, fechaB] = obtenerFechas(B, formatoNueva, fechaNumericaNueva);

% Homogeneizar ambas series al cierre del mes, a medianoche.
dA = dateshift(dateshift(dA, 'end', 'month'), 'start', 'day');
dB = dateshift(dateshift(dB, 'end', 'month'), 'start', 'day');

dA.Format = 'yyyy-MM-dd';
dB.Format = 'yyyy-MM-dd';

ComparacionGeneral = table( ...
    ["Número de portafolios"; ...
     "Identificador utilizado"; ...
     "Número de observaciones"; ...
     "Variable de fecha"; ...
     "Fecha de inicio"; ...
     "Fecha de fin"; ...
     "Fechas faltantes"], ...
    [string(nA); idA; string(height(A)); fechaA; ...
     extremoFecha(dA, 'min'); extremoFecha(dA, 'max'); ...
     string(nnz(isnat(dA)))], ...
    [string(nB); idB; string(height(B)); fechaB; ...
     extremoFecha(dB, 'min'); extremoFecha(dB, 'max'); ...
     string(nnz(isnat(dB)))], ...
    'VariableNames', {'Indicador','ActiveData','ActiveData2'});

disp('COMPARACIÓN GENERAL');
disp(ComparacionGeneral);

%% 2. Tabla de tipos y unidades
variables = union( ...
    string(A.Properties.VariableNames), ...
    string(B.Properties.VariableNames), 'stable');
variables = variables(:);

n = numel(variables);
TipoAnterior = strings(n,1);
TipoNueva = strings(n,1);
UnidadAnterior = strings(n,1);
UnidadNueva = strings(n,1);

for i = 1:n
    [TipoAnterior(i), UnidadAnterior(i)] = ...
        describirVariable(A, variables(i));

    [TipoNueva(i), UnidadNueva(i)] = ...
        describirVariable(B, variables(i));
end

ComparacionUnidades = table( ...
    variables, TipoAnterior, TipoNueva, ...
    UnidadAnterior, UnidadNueva, ...
    'VariableNames', {'Variable','TipoAnterior','TipoNueva', ...
                     'UnidadAnterior','UnidadNueva'});

disp('TIPOS Y UNIDADES');
disp(ComparacionUnidades);

%% Funciones locales
function T = cargarTabla(archivo)
    assert(isfile(archivo), 'No se encontró: %s', archivo);
    S = load(archivo);

    for nombre = ["ActiveData", "ActiveData2"]
        if isfield(S, char(nombre)) && istable(S.(char(nombre)))
            T = S.(char(nombre));
            return;
        end
    end

    nombres = fieldnames(S);
    nombres = nombres(cellfun(@(x) istable(S.(x)), nombres));

    assert(numel(nombres)==1, ...
        'No se pudo identificar una tabla única en %s.', archivo);

    T = S.(nombres{1});
end

function [n, clave] = contarPortafolios(T)
    nombres = string(T.Properties.VariableNames);

    % Prioriza fund_id y utiliza fund como alternativa.
    for clave = ["fund_id", "fund"]
        if ismember(clave, nombres)
            original = T.(char(clave));
            x = strtrim(string(original));
            validos = ~ismissing(original) & ...
                      ~ismissing(x) & strlength(x)>0;
            n = numel(unique(x(validos)));
            return;
        end
    end

    n = NaN;
    clave = "No encontrada";
end

function [d, nombre] = obtenerFechas(T, formato, conversionNumerica)
    nombres = string(T.Properties.VariableNames);
    candidatos = ["date", "month_date"];
    candidatos = candidatos(ismember(candidatos, nombres));

    assert(~isempty(candidatos), ...
        'No se encontró una columna date o month_date.');

    nombre = candidatos(1);
    x = T.(char(nombre));

    if isdatetime(x)
        d = x;

    elseif isnumeric(x)
        assert(~isempty(conversionNumerica), ...
            ['La columna %s es numérica. Especifica su formato: ' ...
             'datenum, excel o yyyymmdd.'], char(nombre));

        if strcmpi(conversionNumerica, 'yyyymmdd')
            d = NaT(size(x));
            validos = ~ismissing(x);
            d(validos) = datetime(string(x(validos)), ...
                'InputFormat', 'yyyyMMdd');
        else
            d = datetime(x, 'ConvertFrom', conversionNumerica);
        end

    else
        x = strtrim(string(x));
        validos = ~ismissing(x) & strlength(x)>0;
        d = NaT(size(x));

        if any(validos)
            try
                if isempty(formato)
                    d(validos) = datetime(x(validos));
                else
                    d(validos) = datetime(x(validos), ...
                        'InputFormat', formato);
                end
            catch
                error(['No se pudo interpretar %s. Completa el formato ' ...
                       'de fecha al inicio del script. Ejemplo: yyyy-MM.'], ...
                       char(nombre));
            end
        end
    end

    d.Format = 'yyyy-MM-dd';
end

function s = extremoFecha(d, operacion)
    d = d(~isnat(d));

    if isempty(d)
        s = "Sin fechas válidas";
    elseif strcmp(operacion, 'min')
        s = string(min(d), 'yyyy-MM-dd');
    else
        s = string(max(d), 'yyyy-MM-dd');
    end
end

function [tipo, unidad] = describirVariable(T, variable)
    nombres = string(T.Properties.VariableNames);
    posicion = find(nombres == variable, 1);

    if isempty(posicion)
        tipo = "No existe";
        unidad = "No existe";
        return;
    end

    tipo = string(class(T.(char(variable))));

    % Utilizar metadatos de unidades, cuando estén disponibles.
    unidades = T.Properties.VariableUnits;
    if ~isempty(unidades) && numel(unidades)>=posicion
        u = string(unidades{posicion});
        if ~ismissing(u) && strlength(strtrim(u))>0
            unidad = u;
            return;
        end
    end

    switch lower(variable)
        case {"fund", "fund_id"}
            unidad = "Identificador; sin unidad";
        case "fund_name_and_share"
            unidad = "Texto; sin unidad";
        case {"date", "month_date"}
            unidad = "Fecha calendario";
        case "fee"
            unidad = "Confirmar: % o decimal; anual o mensual";
        case {"net_return", "excess_return", "excess_return_passive"}
            unidad = "Confirmar: decimal o %; periodicidad";
        case "aum"
            unidad = "Confirmar: moneda y escala";
        otherwise
            unidad = "No documentada";
    end
end