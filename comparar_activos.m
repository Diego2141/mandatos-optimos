%% COMPARAR_ACTIVOS  Reconciliacion de valores entre ActiveData y ActiveData2
%
%  Complementa la seccion "Comparación de ActiveData y ActiveData2" de
%  generar_datos_mandatos.m, que compara ESQUEMA (numero de portafolios,
%  variable de fecha, rangos, tipos y unidades). Este script compara VALORES:
%  para cada par (fondo, mes) presente en ambas bases, verifica si los
%  retornos coinciden.
%
%  Dos bases pueden tener esquemas identicos y datos distintos. Si la nueva
%  extraccion cambio retornos historicos ya publicados, el esquema no lo
%  muestra y el modelo correria sobre numeros distintos sin aviso.
%
%  Responde cuatro preguntas:
%    1. Que fondos estan en una y no en la otra.
%    2. Que periodo cubren en comun.
%    3. Para los pares comunes, coinciden los valores.
%    4. Si no coinciden, es un cambio de escala (pb vs decimal vs %) o son
%       datos genuinamente distintos.

clear; clc;

%% ------------------------------------------------------------------ Config
RUTA = pwd;   % ejecutar desde la carpeta Codigo

ARCHIVO_A = fullfile(RUTA, 'ActiveData.mat');    % base anterior
ARCHIVO_B = fullfile(RUTA, 'ActiveData2.mat');   % base nueva

% Variables numericas a reconciliar, si existen en ambas.
VARIABLES = ["excess_return", "net_return", "fee", "aum"];

% Diferencia absoluta por encima de la cual se considera discrepancia.
TOLERANCIA = 1e-9;

%% -------------------------------------------------------------------- Carga
A = cargar(ARCHIVO_A);
B = cargar(ARCHIVO_B);

fprintf('%s\n', repmat('=', 1, 78));
fprintf('  RECONCILIACION DE VALORES: ActiveData vs ActiveData2\n');
fprintf('%s\n', repmat('=', 1, 78));
fprintf('  A: %s  (%d filas, %d variables)\n', 'ActiveData.mat',  height(A), width(A));
fprintf('  B: %s  (%d filas, %d variables)\n', 'ActiveData2.mat', height(B), width(B));

[kA, nombre_kA] = clave_fondo(A, 'ActiveData');
[kB, nombre_kB] = clave_fondo(B, 'ActiveData2');
if nombre_kA ~= nombre_kB
    fprintf(['\n  AVISO: la clave de fondo difiere (A usa %s, B usa %s).\n' ...
             '         Se comparan como texto; si los identificadores no son\n' ...
             '         del mismo sistema, el solape sera espurio.\n'], ...
             nombre_kA, nombre_kB);
end

dA = clave_fecha(A, 'ActiveData');
dB = clave_fecha(B, 'ActiveData2');

% Homogeneizar al cierre de mes: la comparacion es mensual.
dA = dateshift(dateshift(dA, 'end', 'month'), 'start', 'day');
dB = dateshift(dateshift(dB, 'end', 'month'), 'start', 'day');

%% --------------------------------------------------- 1. Universo de fondos
fondos_A = unique(kA);
fondos_B = unique(kB);
solo_A   = setdiff(fondos_A, fondos_B);
solo_B   = setdiff(fondos_B, fondos_A);
comunes  = intersect(fondos_A, fondos_B);

fprintf('\n--- 1. Universo de fondos ---\n');
fprintf('  En A: %d | En B: %d | En ambas: %d\n', ...
        numel(fondos_A), numel(fondos_B), numel(comunes));
fprintf('  Solo en A (desaparecieron): %d\n', numel(solo_A));
if ~isempty(solo_A)
    mostrar_lista(solo_A, 15);
    fprintf(['    Si la base nueva omite fondos que la anterior tenia, hay que\n' ...
             '    saber si se liquidaron (informativo: mide supervivencia) o si\n' ...
             '    el extractor los perdio (error de datos).\n']);
end
fprintf('  Solo en B (nuevos): %d\n', numel(solo_B));
if ~isempty(solo_B), mostrar_lista(solo_B, 15); end

if isempty(comunes)
    fprintf('\n  Sin fondos en comun: las bases no son comparables por clave.\n');
    return
end

%% ---------------------------------------------------- 2. Cobertura temporal
fprintf('\n--- 2. Cobertura temporal ---\n');
fprintf('  A: %s a %s  (%d meses distintos)\n', ...
        string(min(dA)), string(max(dA)), numel(unique(dA)));
fprintf('  B: %s a %s  (%d meses distintos)\n', ...
        string(min(dB)), string(max(dB)), numel(unique(dB)));

meses_comunes = intersect(unique(dA), unique(dB));
fprintf('  Meses en comun: %d\n', numel(meses_comunes));
if isempty(meses_comunes)
    fprintf('  Sin solape temporal: no hay nada que reconciliar.\n');
    return
end
fprintf('  Rango comun: %s a %s\n', string(min(meses_comunes)), string(max(meses_comunes)));

%% --------------------------------------------- 3. Reconciliacion de valores
fprintf('\n--- 3. Reconciliacion de valores en pares (fondo, mes) comunes ---\n');

vars_comunes = VARIABLES( ...
    ismember(VARIABLES, string(A.Properties.VariableNames)) & ...
    ismember(VARIABLES, string(B.Properties.VariableNames)));

if isempty(vars_comunes)
    fprintf('  Ninguna de las variables %s esta en ambas bases.\n', ...
            strjoin(cellstr(VARIABLES), ', '));
    return
end

resumen = table();

for v = vars_comunes
    TA = table(kA, dA, double(A.(char(v))), 'VariableNames', {'fondo','fecha','va'});
    TB = table(kB, dB, double(B.(char(v))), 'VariableNames', {'fondo','fecha','vb'});

    TA = colapsar_duplicados(TA, 'va', char(v), 'A');
    TB = colapsar_duplicados(TB, 'vb', char(v), 'B');

    J = innerjoin(TA, TB, 'Keys', {'fondo','fecha'});
    if isempty(J)
        fprintf('  %-16s sin pares coincidentes.\n', v);
        continue
    end

    ok = ~isnan(J.va) & ~isnan(J.vb);
    d  = J.va(ok) - J.vb(ok);
    n  = sum(ok);

    n_dif   = sum(abs(d) > TOLERANCIA);
    max_dif = max(abs(d), [], 'omitnan');
    if isempty(max_dif), max_dif = NaN; end

    % Escala: si B = c * A con c constante, es cambio de unidades, no de datos.
    sel   = ok & J.va ~= 0;
    ratio = J.vb(sel) ./ J.va(sel);
    if isempty(ratio)
        r_med = NaN; r_disp = NaN;
    else
        r_med  = median(ratio, 'omitnan');
        r_disp = iqr(ratio);
    end

    if n > 1
        c = corr(J.va(ok), J.vb(ok), 'rows', 'complete');
    else
        c = NaN;
    end

    resumen = [resumen; table(v, n, n_dif, 100*n_dif/n, max_dif, c, r_med, r_disp, ...
        'VariableNames', {'variable','n_pares','n_difieren','pct_difieren', ...
                          'max_dif_abs','correlacion','ratio_mediano','ratio_iqr'})]; %#ok<AGROW>
end

if isempty(resumen)
    fprintf('  Nada que reconciliar.\n');
    return
end
disp(resumen);

%% ------------------------------------------------------ 4. Interpretacion
fprintf('--- 4. Lectura ---\n');
for i = 1:height(resumen)
    r = resumen(i,:);
    fprintf('  %-16s ', r.variable);

    if r.n_difieren == 0
        fprintf('IDENTICA en los %d pares comunes.\n', r.n_pares);

    elseif abs(r.ratio_iqr) < 1e-6 && abs(r.ratio_mediano - 1) > 1e-6
        fprintf(['CAMBIO DE ESCALA: B = %.6g x A, constante.\n' ...
                 '                   No son datos distintos, son unidades\n' ...
                 '                   distintas. Hay que ajustar el modelo, que\n' ...
                 '                   supone una escala fija.\n'], r.ratio_mediano);

    elseif r.correlacion > 0.999
        fprintf(['difieren en %.1f%% de los pares (max %.3g) pero correlacionan\n' ...
                 '                   %.5f: probable redondeo o revision menor.\n'], ...
                 r.pct_difieren, r.max_dif_abs, r.correlacion);

    else
        fprintf(['DISCREPANCIA REAL: %.1f%% de los pares difieren, correlacion\n' ...
                 '                   %.4f, max %.3g. No es redondeo ni escala:\n' ...
                 '                   las dos bases contienen datos distintos para\n' ...
                 '                   el mismo fondo y mes. Hay que resolverlo con\n' ...
                 '                   la fuente antes de correr el modelo.\n'], ...
                 r.pct_difieren, r.correlacion, r.max_dif_abs);
    end
end

fprintf('\n  Recordatorio: esta comparacion no valida cual de las dos es\n');
fprintf('  correcta, solo si coinciden. Coincidir no es estar bien.\n\n');


%% ====================================================================== %%
%  FUNCIONES
%  ====================================================================== %%

function T = cargar(archivo)
    assert(isfile(archivo), 'No se encontro: %s', archivo);
    S = load(archivo);
    nombres = fieldnames(S);
    esTabla = cellfun(@(x) istable(S.(x)) || isstruct(S.(x)), nombres);
    nombres = nombres(esTabla);
    assert(numel(nombres) == 1, ...
        'Se esperaba una sola tabla en %s, hay %d.', archivo, numel(nombres));
    T = S.(nombres{1});
    if isstruct(T), T = struct2table(T); end
end


function [k, nombre] = clave_fondo(T, etiqueta)
% fund_id es un codigo estable; fund es un correlativo que puede cambiar
% entre extracciones. Se prefiere fund_id.

    vars = string(T.Properties.VariableNames);
    for cand = ["fund_id", "fund"]
        if ismember(cand, vars)
            k = strtrim(string(T.(char(cand))));
            nombre = cand;
            return
        end
    end
    error('comparar:clave', '%s no tiene ni fund_id ni fund.', etiqueta);
end


function d = clave_fecha(T, etiqueta)
% Resuelve la fecha sea datetime, texto 'yyyy-MM' o numero serial.

    vars = string(T.Properties.VariableNames);
    for cand = ["date", "month_date", "fecha"]
        if ~ismember(cand, vars), continue; end
        x = T.(char(cand));

        if isdatetime(x)
            d = x; return
        end
        if iscell(x) || isstring(x) || ischar(x)
            s = string(x);
            for f = ["yyyy-MM", "yyyy-MM-dd", "MM/yyyy", "dd/MM/yyyy"]
                d = datetime(s, 'InputFormat', f);
                if ~any(isnat(d)), return; end
            end
            error('comparar:fechaTexto', ...
                ['%s: no se pudo interpretar "%s" con ningun formato conocido.\n' ...
                 'Primer valor: "%s"'], etiqueta, cand, s(1));
        end
        if isnumeric(x)
            error('comparar:fechaNumerica', ...
                ['%s: "%s" es numerica. No se adivina si es serial de MATLAB\n' ...
                 'o de Excel: la diferencia son 693960 dias. Convertir en origen.'], ...
                etiqueta, cand);
        end
    end
    error('comparar:sinFecha', '%s no tiene variable de fecha reconocible.', etiqueta);
end


function T = colapsar_duplicados(T, var, nombre_var, etiqueta)
% innerjoin exige claves unicas. Si hay duplicados, se avisa y se conserva
% la primera aparicion: promediarlos escondería un problema de origen.

    [~, ia] = unique(T(:, {'fondo','fecha'}), 'rows', 'stable');
    n_dup = height(T) - numel(ia);
    if n_dup > 0
        fprintf(['  AVISO: %d fila(s) con (fondo, mes) duplicado en %s para %s.\n' ...
                 '         Se conserva la primera. Revisar el origen.\n'], ...
                 n_dup, etiqueta, nombre_var);
        T = T(ia, :);
    end
end


function mostrar_lista(x, n)
    m = min(numel(x), n);
    fprintf('    %s', strjoin(cellstr(x(1:m)), ', '));
    if numel(x) > m
        fprintf(', ... (+%d mas)', numel(x) - m);
    end
    fprintf('\n');
end
