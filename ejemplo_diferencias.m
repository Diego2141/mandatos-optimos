%% EJEMPLO_DIFERENCIAS  Casos concretos de discrepancia entre ActiveData y ActiveData2
%
%  comparar_activos.m dice CUANTO difieren las bases. Este script dice POR QUE,
%  mostrando fondos y meses concretos.
%
%  Parte de una lectura que los agregados ya sugieren: net_return correlaciona
%  0.9996 entre bases pero excess_return solo 0.9299. Como
%  excess_return = net_return - benchmark, si el retorno del fondo coincide y
%  el exceso no, lo que cambio es el benchmark. Este script reconstruye el
%  benchmark implicito de cada base y lo compara directamente.
%
%  Revisa ademas:
%    - si `fee` es una serie historica o una foto propagada a todas las filas
%    - hasta cuando llegan los fondos que desaparecieron en la base nueva,
%      que es la forma de distinguir una baja real de una perdida del extractor

clear; clc;

%% ------------------------------------------------------------------ Config
RUTA = pwd;

% Dejar vacio para elegir automaticamente el fondo con mayor discrepancia
% media en excess_return. O fijar uno: FONDO = "FSUSA001MG";
FONDO = "";

N_RANKING = 10;   % fondos a listar en el ranking
N_MESES   = 24;   % meses a mostrar del fondo elegido

%% -------------------------------------------------------------------- Carga
A = cargar(fullfile(RUTA, 'ActiveData.mat'));
B = cargar(fullfile(RUTA, 'ActiveData2.mat'));

TA = normalizar(A);
TB = normalizar(B);

J = innerjoin(TA, TB, 'Keys', {'fondo','fecha'}, ...
    'LeftVariables',  {'fondo','fecha','net_return','excess_return','fee'}, ...
    'RightVariables', {'net_return','excess_return','fee'});
J.Properties.VariableNames = {'fondo','fecha','net_A','exc_A','fee_A', ...
                              'net_B','exc_B','fee_B'};

% Benchmark implicito: lo que cada base resto para obtener el exceso.
J.bench_A = J.net_A - J.exc_A;
J.bench_B = J.net_B - J.exc_B;

fprintf('%s\n', repmat('=', 1, 78));
fprintf('  DIFERENCIAS CONCRETAS  (%d pares fondo-mes en comun)\n', height(J));
fprintf('%s\n', repmat('=', 1, 78));

%% ------------------------------------------- 1. De donde viene la diferencia
fprintf('\n--- 1. El retorno del fondo o el benchmark ---\n');

d_net   = abs(J.net_A   - J.net_B);
d_exc   = abs(J.exc_A   - J.exc_B);
d_bench = abs(J.bench_A - J.bench_B);

fprintf('  %-22s %10s %12s %12s\n', '', 'media', 'maxima', '% pares > 1e-9');
imprimir_fila('net_return',    d_net);
imprimir_fila('excess_return', d_exc);
imprimir_fila('benchmark imp.', d_bench);

if mean(d_bench, 'omitnan') > 10 * mean(d_net, 'omitnan')
    fprintf(['\n  El benchmark difiere en un orden de magnitud mas que el\n' ...
             '  retorno del fondo: la discrepancia en alpha viene de la\n' ...
             '  referencia, no de los retornos. Hay que confirmar con la\n' ...
             '  fuente que benchmark se asigno en cada extraccion.\n']);
end

%% ------------------------------------------------- 2. Ranking de fondos
fprintf('\n--- 2. Fondos con mayor discrepancia en excess_return ---\n');

[g, fondos] = findgroups(J.fondo);
dif_media = splitapply(@(x) mean(x, 'omitnan'), d_exc, g);
dif_max   = splitapply(@(x) max(x,  [], 'omitnan'), d_exc, g);
n_meses   = splitapply(@numel, d_exc, g);
db_media  = splitapply(@(x) mean(x, 'omitnan'), d_bench, g);

rk = sortrows(table(fondos, n_meses, dif_media, dif_max, db_media, ...
    'VariableNames', {'fondo','n_meses','dif_media_exc','dif_max_exc','dif_media_bench'}), ...
    'dif_media_exc', 'descend');
disp(head(rk, N_RANKING));

%% ---------------------------------------------- 3. Detalle de un fondo
if FONDO == ""
    FONDO = rk.fondo(1);
    fprintf('  Fondo elegido automaticamente (mayor discrepancia): %s\n', FONDO);
end

sel = J(J.fondo == FONDO, :);
sel = sortrows(sel, 'fecha');
if isempty(sel)
    error('ejemplo:sinFondo', '%s no esta en los pares comunes.', FONDO);
end

fprintf('\n--- 3. Detalle mensual: %s ---\n', FONDO);
fprintf('  (todo en pb; bench = net - exc, el benchmark que cada base resto)\n\n');

m = min(height(sel), N_MESES);
det = table( ...
    sel.fecha(1:m), ...
    round(sel.net_A(1:m)*10000, 2),   round(sel.net_B(1:m)*10000, 2), ...
    round(sel.exc_A(1:m)*10000, 2),   round(sel.exc_B(1:m)*10000, 2), ...
    round(sel.bench_A(1:m)*10000, 2), round(sel.bench_B(1:m)*10000, 2), ...
    round((sel.bench_A(1:m)-sel.bench_B(1:m))*10000, 2), ...
    'VariableNames', {'fecha','net_A','net_B','exc_A','exc_B', ...
                      'bench_A','bench_B','dif_bench'});
disp(det);

if height(sel) > m
    fprintf('  (%d meses mas no mostrados)\n', height(sel) - m);
end

%% ------------------------------------------------------ 4. La variable fee
fprintf('\n--- 4. fee: serie historica o foto? ---\n');

n_unicos_A = numel(unique(sel.fee_A));
n_unicos_B = numel(unique(sel.fee_B));
fprintf('  %s: %d valor(es) distinto(s) de fee en A, %d en B, sobre %d meses.\n', ...
        FONDO, n_unicos_A, n_unicos_B, height(sel));
fprintf('  A: %s\n', mat2str(unique(sel.fee_A)'));
fprintf('  B: %s\n', mat2str(unique(sel.fee_B)'));

const_A = splitapply(@(x) numel(unique(x)) == 1, J.fee_A, g);
const_B = splitapply(@(x) numel(unique(x)) == 1, J.fee_B, g);
fprintf('  Fondos con fee constante en toda su historia: %d de %d en A, %d de %d en B.\n', ...
        sum(const_A), numel(const_A), sum(const_B), numel(const_B));

if mean(const_A) > 0.9 && mean(const_B) > 0.9
    fprintf(['  fee es una FOTO, no una serie: un valor por fondo propagado a\n' ...
             '  todas las filas. Main_OptimalAllocation_Managers_V2.m:18 la usa\n' ...
             '  mes a mes como si variara. Al diferir entre extracciones, lo que\n' ...
             '  cambia es la fecha de la foto, no la comision historica.\n']);
end

%% -------------------------------- 5. Los fondos que ya no estan en la base B
fprintf('\n--- 5. Fondos de A ausentes en B: baja real o perdida del extractor? ---\n');

solo_A = setdiff(unique(TA.fondo), unique(TB.fondo));
if isempty(solo_A)
    fprintf('  Ninguno.\n');
else
    sub = TA(ismember(TA.fondo, solo_A), :);
    [g2, f2] = findgroups(sub.fondo);
    ult = splitapply(@max, sub.fecha, g2);
    pri = splitapply(@min, sub.fecha, g2);
    nob = splitapply(@numel, sub.fecha, g2);

    t = sortrows(table(f2, pri, ult, nob, ...
        'VariableNames', {'fondo','primera','ultima','n_obs'}), 'ultima');
    disp(t);

    fin_A = max(TA.fecha);
    vivos_al_final = sum(t.ultima >= fin_A);
    fprintf(['  %d de %d llegaban hasta el final de A (%s).\n'], ...
            vivos_al_final, height(t), string(fin_A));
    if vivos_al_final > 0.5 * height(t)
        fprintf(['  La mayoria seguia reportando cuando A termina, asi que su\n' ...
                 '  ausencia en B no es una baja dentro de la muestra de A: o\n' ...
                 '  cerraron entre %s y %s, o el extractor de B solo trajo\n' ...
                 '  fondos con historia completa hasta el final.\n' ...
                 '  En el segundo caso B esta filtrada a sobrevivientes y su\n' ...
                 '  alpha es una cota superior. Hay que preguntarlo a la fuente.\n'], ...
                 string(fin_A), string(max(TB.fecha)));
    end
end

fprintf('\n');


%% ====================================================================== %%
%  FUNCIONES
%  ====================================================================== %%

function T = cargar(archivo)
    assert(isfile(archivo), 'No se encontro: %s', archivo);
    S = load(archivo);
    nombres = fieldnames(S);
    nombres = nombres(cellfun(@(x) istable(S.(x)) || isstruct(S.(x)), nombres));
    assert(numel(nombres) == 1, 'Se esperaba una sola tabla en %s.', archivo);
    T = S.(nombres{1});
    if isstruct(T), T = struct2table(T); end
end


function U = normalizar(T)
% Clave de fondo, fecha a cierre de mes y las tres variables de interes.

    vars = string(T.Properties.VariableNames);

    clave = "";
    for c = ["fund_id", "fund"]
        if ismember(c, vars), clave = c; break; end
    end
    assert(clave ~= "", 'Sin fund_id ni fund.');
    fondo = strtrim(string(T.(char(clave))));

    fecha = datetime.empty(height(T), 0);
    for c = ["date", "month_date", "fecha"]
        if ~ismember(c, vars), continue; end
        x = T.(char(c));
        if isdatetime(x)
            fecha = x; break
        elseif iscell(x) || isstring(x) || ischar(x)
            s = string(x);
            for f = ["yyyy-MM", "yyyy-MM-dd", "MM/yyyy", "dd/MM/yyyy"]
                d = datetime(s, 'InputFormat', f);
                if ~any(isnat(d)), fecha = d; break; end
            end
            if ~isempty(fecha), break; end
        end
    end
    assert(~isempty(fecha), 'Sin variable de fecha reconocible.');
    fecha = dateshift(dateshift(fecha, 'end', 'month'), 'start', 'day');

    tomar = @(n) double(T.(n));
    U = table(fondo, fecha, tomar('net_return'), tomar('excess_return'), tomar('fee'), ...
        'VariableNames', {'fondo','fecha','net_return','excess_return','fee'});

    [~, ia] = unique(U(:, {'fondo','fecha'}), 'rows', 'stable');
    U = U(ia, :);
end


function imprimir_fila(etiqueta, d)
    fprintf('  %-22s %10.3g %12.3g %12.1f%%\n', etiqueta, ...
            mean(d, 'omitnan'), max(d, [], 'omitnan'), ...
            100 * mean(d > 1e-9, 'omitnan'));
end
