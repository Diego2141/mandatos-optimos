%% PREPARAR_DATOS  Apila los tramos y genera ActiveData2.mat / PassiveData2.mat
%
%  Entrada : Data/data_global, data_short, data_ultrashort
%            Data/passive_data_global, passive_data_short, passive_data_ultrashort
%            (la extension se detecta sola: .mat, .xlsx, .xls, .csv, .txt)
%
%  Salida  : ActiveData2.mat   con la variable  ActiveData
%            PassiveData2.mat  con la variable  PassiveData
%
%  Los nombres de las variables guardadas son ActiveData y PassiveData, no
%  ActiveData2, para que el codigo existente los encuentre sin cambios.
%
%  IMPORTANTE - por que se agrega la columna `tramo`:
%  Main_OptimalAllocation_Managers_V2.m:13 hace
%      excess_return_matrix(:,i) = ActiveData.excess_return(ismember(ActiveData.fund, numfunds(i)))
%  y supone que cada fondo aporta exactamente length(dates) filas. Si un
%  mismo identificador de fondo aparece en dos tramos, ismember devuelve las
%  filas de ambos concatenadas y la matriz queda desalineada SIN ERROR: el
%  modelo corre y entrega un N* incorrecto. Este script detecta ese caso y
%  lo reporta antes de guardar.

clear; clc;

%% ------------------------------------------------------------------ Config
CARPETA_DATA = 'Data';

ACTIVOS = { 'data_global',         'global'
            'data_short',          'short'
            'data_ultrashort',     'ultrashort' };

PASIVOS = { 'passive_data_global',     'global'
            'passive_data_short',      'short'
            'passive_data_ultrashort', 'ultrashort' };

%% ----------------------------------------------------- Construir y guardar
ActiveData  = construir_panel(CARPETA_DATA, ACTIVOS,  'MANDATOS ACTIVOS');
PassiveData = construir_panel(CARPETA_DATA, PASIVOS, 'MANDATOS PASIVOS');

save('ActiveData2.mat',  'ActiveData');
save('PassiveData2.mat', 'PassiveData');

fprintf('\n%s\n', repmat('=', 1, 78));
fprintf('  GUARDADO\n');
fprintf('%s\n', repmat('=', 1, 78));
fprintf('  ActiveData2.mat   -> variable ActiveData   (%d filas, %d vars)\n', ...
        height(ActiveData), width(ActiveData));
fprintf('  PassiveData2.mat  -> variable PassiveData  (%d filas, %d vars)\n', ...
        height(PassiveData), width(PassiveData));
fprintf('\n  Estos .mat NO deben subirse al repositorio: contienen datos\n');
fprintf('  de gestores. El .gitignore ya bloquea *.mat.\n\n');


%% ========================================================================
%  FUNCIONES
%  ========================================================================

function P = construir_panel(carpeta, spec, titulo)
% Carga, inspecciona, valida y apila los tramos de un panel.

    fprintf('\n\n%s\n', repmat('#', 1, 78));
    fprintf('#  %s\n', titulo);
    fprintf('%s\n', repmat('#', 1, 78));

    n = size(spec, 1);
    piezas = cell(n, 1);

    % --- 1. Cargar e inspeccionar cada tramo por separado -----------------
    for i = 1:n
        base  = spec{i,1};
        tramo = spec{i,2};
        ruta  = resolver_archivo(carpeta, base);

        fprintf('\n>> %s  (%s)\n', base, ruta);
        T = cargar_tabla(ruta);
        T = normalizar_fechas(T, base);
        inspeccionar_tabla(T, sprintf('%s  [tramo: %s]', base, tramo));

        T.tramo = repmat(string(tramo), height(T), 1);
        piezas{i} = T;
    end

    % --- 2. Verificar que los esquemas coinciden ANTES de apilar ----------
    verificar_esquemas(piezas, spec(:,1));

    % --- 3. Apilar --------------------------------------------------------
    P = vertcat(piezas{:});
    P.tramo = categorical(P.tramo);

    % --- 4. Validar el panel apilado --------------------------------------
    validar_panel(P, titulo);

    inspeccionar_tabla(P, sprintf('PANEL APILADO - %s', titulo));
end


function ruta = resolver_archivo(carpeta, base)
% Encuentra el archivo probando extensiones conocidas.

    exts = {'.mat', '.xlsx', '.xls', '.csv', '.txt'};
    for k = 1:numel(exts)
        cand = fullfile(carpeta, [base exts{k}]);
        if isfile(cand)
            ruta = cand;
            return
        end
    end
    error('preparar_datos:archivoNoEncontrado', ...
          ['No se encontro "%s" en "%s" con ninguna de estas extensiones: %s\n' ...
           'Revisa el nombre exacto con: dir(''%s'')'], ...
          base, carpeta, strjoin(exts, ' '), carpeta);
end


function T = normalizar_fechas(T, origen)
% Crea una variable `date` de tipo datetime a partir de `month_date`.
%
% Los archivos traen `month_date` como texto 'yyyy-MM'. Sin convertirla,
% toda la validacion de panel (balanceo, duplicados, cobertura) se salta en
% silencio, y el modelo no encuentra la variable `date` que usa por nombre.

    vars = string(T.Properties.VariableNames);

    if ismember("date", vars) && isdatetime(T.date)
        return
    end

    if ~ismember("month_date", vars)
        error('preparar_datos:sinFecha', ...
              ['"%s" no tiene ni `date` ni `month_date`. Sin variable de\n' ...
               'fecha no se puede validar el panel ni alinear los retornos.'], ...
              origen);
    end

    md = T.month_date;
    if iscell(md) || isstring(md) || ischar(md)
        d = datetime(string(md), 'InputFormat', 'yyyy-MM');
    elseif isdatetime(md)
        d = md;
    elseif isnumeric(md)
        error('preparar_datos:fechaNumerica', ...
              ['"%s": `month_date` es numerica. No se adivina si son fechas\n' ...
               'seriales de MATLAB o de Excel: la diferencia son 693960 dias.'], ...
              origen);
    else
        error('preparar_datos:fechaTipo', ...
              '"%s": `month_date` es %s, tipo no soportado.', origen, class(md));
    end

    if any(isnat(d))
        malas = find(isnat(d), 5);
        error('preparar_datos:fechaNoParseable', ...
              ['"%s": %d valores de `month_date` no se pudieron interpretar\n' ...
               'como yyyy-MM. Primeras filas problematicas: %s'], ...
              origen, sum(isnat(d)), mat2str(malas'));
    end

    d.Format = 'yyyy-MM';
    T.date = d;
    fprintf('   `date` creada desde `month_date` (%s a %s)\n', ...
            string(min(d)), string(max(d)));
end


function T = cargar_tabla(ruta)
% Carga .mat / .xlsx / .csv a tabla, sin adivinar nombres de variables.

    [~, ~, ext] = fileparts(ruta);

    switch lower(ext)
        case '.mat'
            S = load(ruta);
            campos = fieldnames(S);
            if numel(campos) ~= 1
                error('preparar_datos:matAmbiguo', ...
                      ['"%s" contiene %d variables (%s). El script no adivina\n' ...
                       'cual usar: guarda una sola, o edita cargar_tabla.'], ...
                      ruta, numel(campos), strjoin(campos', ', '));
            end
            T = S.(campos{1});
            if isstruct(T)
                T = struct2table(T);
            elseif ~istable(T)
                error('preparar_datos:tipoInesperado', ...
                      '"%s" contiene un %s, se esperaba table o struct.', ...
                      ruta, class(T));
            end

        case {'.xlsx', '.xls'}
            T = readtable(ruta, 'VariableNamingRule', 'preserve');

        case {'.csv', '.txt'}
            T = readtable(ruta, 'VariableNamingRule', 'preserve');

        otherwise
            error('preparar_datos:extension', 'Extension no soportada: %s', ext);
    end
end


function verificar_esquemas(piezas, nombres)
% Falla ruidosamente si los tramos no tienen las mismas variables y tipos.
% vertcat tambien fallaria, pero con un mensaje que no dice cual difiere.

    fprintf('\n--- Consistencia de esquemas entre tramos ---\n');

    ref_vars = string(piezas{1}.Properties.VariableNames);
    problemas = strings(0,1);

    for i = 2:numel(piezas)
        vars = string(piezas{i}.Properties.VariableNames);

        sobra = setdiff(vars, ref_vars);
        falta = setdiff(ref_vars, vars);

        if ~isempty(sobra)
            problemas(end+1) = sprintf('%s tiene variables que %s no tiene: %s', ...
                nombres{i}, nombres{1}, strjoin(cellstr(sobra), ', ')); %#ok<AGROW>
        end
        if ~isempty(falta)
            problemas(end+1) = sprintf('%s NO tiene: %s', ...
                nombres{i}, strjoin(cellstr(falta), ', ')); %#ok<AGROW>
        end

        comunes = intersect(ref_vars, vars);
        for v = comunes(:)'
            c1 = class(piezas{1}.(char(v)));
            c2 = class(piezas{i}.(char(v)));
            if ~strcmp(c1, c2)
                problemas(end+1) = sprintf('"%s": %s es %s pero %s es %s', ...
                    v, nombres{1}, c1, nombres{i}, c2); %#ok<AGROW>
            end
        end
    end

    if isempty(problemas)
        fprintf('  OK: los %d tramos comparten variables y tipos.\n', numel(piezas));
    else
        fprintf('  PROBLEMAS:\n');
        fprintf('    - %s\n', problemas{:});
        error('preparar_datos:esquemaInconsistente', ...
              ['Los tramos no son apilables tal cual. Corrige los nombres o\n' ...
               'tipos en origen: renombrarlos aqui a ciegas esconde el error.']);
    end
end


function validar_panel(P, titulo)
% Chequeos que deciden si el panel sirve para el modelo.

    fprintf('\n--- Validacion del panel apilado: %s ---\n', titulo);

    tiene = @(v) ismember(v, string(P.Properties.VariableNames));

    % 1. Fondos que aparecen en mas de un tramo -> rompen ismember() del modelo
    if tiene("fund")
        [g, fondos] = findgroups(P.fund);
        n_tramos = splitapply(@(t) numel(unique(t)), P.tramo, g);
        repetidos = fondos(n_tramos > 1);

        if isempty(repetidos)
            fprintf('  OK: ningun fondo aparece en mas de un tramo.\n');
        else
            fprintf('  CRITICO: %d fondo(s) aparecen en mas de un tramo:\n', ...
                    numel(repetidos));
            disp(repetidos);
            fprintf(['    Main_OptimalAllocation_Managers_V2.m:13 usa\n' ...
                     '    ismember(ActiveData.fund, ...) sin filtrar por tramo:\n' ...
                     '    concatenaria las filas de ambos tramos y desalinearia\n' ...
                     '    la matriz de retornos SIN dar error.\n' ...
                     '    Hay que decidir: filtrar por tramo, o construir una\n' ...
                     '    clave compuesta fund+tramo.\n']);
        end
    end

    % 2. Panel balanceado: el modelo asume misma cantidad de fechas por fondo
    if tiene("fund") && tiene("date")
        meses_totales = numel(unique(P.date));
        [g, f_id, f_tr] = findgroups(P.fund, P.tramo);
        n_obs   = splitapply(@numel, P.date, g);
        f_ini   = splitapply(@min,   P.date, g);
        f_fin   = splitapply(@max,   P.date, g);

        fprintf('  Meses distintos en la muestra: %d  (%s a %s)\n', meses_totales, ...
                string(min(P.date)), string(max(P.date)));
        fprintf('  Observaciones por fondo: min=%d  mediana=%d  max=%d\n', ...
                min(n_obs), round(median(n_obs)), max(n_obs));

        incompletos = find(n_obs < meses_totales);
        if isempty(incompletos)
            fprintf('  OK: panel balanceado (%d observaciones por fondo).\n', meses_totales);
        else
            fprintf('  DESBALANCEADO: %d de %d fondos no tienen los %d meses.\n', ...
                    numel(incompletos), numel(n_obs), meses_totales);
            detalle = table(f_id(incompletos), f_tr(incompletos), ...
                            n_obs(incompletos), meses_totales - n_obs(incompletos), ...
                            f_ini(incompletos), f_fin(incompletos), ...
                'VariableNames', {'fund','tramo','n_obs','faltan','desde','hasta'});
            disp(detalle);
            fprintf(['    Main_OptimalAllocation_Managers_V2.m:13 asigna\n' ...
                     '    excess_return_matrix(:,i) suponiendo length(dates)\n' ...
                     '    valores. Con estos fondos lanza error de dimensiones.\n' ...
                     '    El arreglo correcto es unstack() por fecha, no recortar\n' ...
                     '    la muestra al minimo comun.\n']);
        end

        % --- Sesgo de supervivencia -------------------------------------
        % Un panel de fondos mutuos completo a 10 anios no es natural: los
        % fondos cierran, se fusionan y se lanzan. Si casi todos tienen
        % historia integra, el universo se filtro a sobrevivientes y el
        % alpha estimado es una cota superior.
        completos = sum(n_obs == meses_totales);
        pct_comp  = 100 * completos / numel(n_obs);
        fprintf('  Historia completa: %d de %d fondos (%.1f%%)\n', ...
                completos, numel(n_obs), pct_comp);

        n_altas = sum(f_ini > min(P.date));
        n_bajas = sum(f_fin < max(P.date));
        fprintf('  Fondos que entran despues del inicio: %d | que salen antes del final: %d\n', ...
                n_altas, n_bajas);

        if pct_comp > 90 && meses_totales >= 60
            fprintf(['  AVISO - SESGO DE SUPERVIVENCIA: %.0f%% de los fondos\n' ...
                     '         cubren los %d meses completos y solo %d causan baja.\n' ...
                     '         Si el extractor no incluyo fondos liquidados o\n' ...
                     '         fusionados, alpha esta inflado y N* es cota superior.\n' ...
                     '         Hay que confirmarlo con la fuente y declararlo.\n'], ...
                     pct_comp, meses_totales, n_bajas);
        end

        % 3. Claves duplicadas
        if numel(unique(n_obs)) >= 1
            clave = strcat(string(P.fund), '|', string(P.tramo), '|', string(P.date));
            n_dup = numel(clave) - numel(unique(clave));
            if n_dup > 0
                fprintf('  CRITICO: %d fila(s) con clave fund+tramo+date duplicada.\n', n_dup);
            else
                fprintf('  OK: sin duplicados en fund+tramo+date.\n');
            end
        end

        % 4. Cobertura temporal por tramo
        fprintf('  Cobertura por tramo:\n');
        tramos = categories(P.tramo);
        for k = 1:numel(tramos)
            sel = P.tramo == tramos{k};
            fprintf('    %-12s %s a %s   (%d fondos, %d filas)\n', tramos{k}, ...
                    string(min(P.date(sel))), string(max(P.date(sel))), ...
                    numel(unique(P.fund(sel))), sum(sel));
        end
    end

    % 5. La variable de comisiones que usa el modelo
    if ~tiene("fee")
        fprintf(['  AVISO: no hay variable "fee".\n' ...
                 '         Main_OptimalAllocation_Managers_V2.m:18 la usa para\n' ...
                 '         reconstruir el retorno bruto. Sin ella ese paso falla.\n']);
    else
        % :18 hace fee./(12*100), o sea la trata como porcentaje anual.
        fprintf('  fee: rango [%.4f, %.4f] -- se interpreta como %% anual en :18\n', ...
                min(P.fee), max(P.fee));
        if max(P.fee) < 0.05
            fprintf(['  AVISO: fee maximo < 0.05. Si viniera en decimal y no en\n' ...
                     '         porcentaje, :18 lo dividiria por 100 de mas.\n']);
        end
        n_cero = sum(P.fee == 0);
        if n_cero > 0
            fondos_cero = unique(P.fund(P.fee == 0));
            fprintf(['  AVISO: %d fila(s) con fee exactamente 0, en %d fondo(s).\n' ...
                     '         Un mandato sin comision no existe: probablemente\n' ...
                     '         es un faltante codificado como cero. El termino de\n' ...
                     '         comisiones decide N* al margen, asi que importa.\n'], ...
                     n_cero, numel(fondos_cero));
            disp(fondos_cero');
        end
    end

    % 6. aum: no lo usa el modelo hoy, pero si algun dia se pondera por tamanio
    if tiene("aum") && tiene("fund")
        [g, fondos_a] = findgroups(P.fund);
        falt_aum = splitapply(@(x) sum(ismissing(x)), P.aum, g);
        n_obs_a  = splitapply(@numel, P.aum, g);
        sin_aum  = fondos_a(falt_aum == n_obs_a);
        if ~isempty(sin_aum)
            fprintf(['  AVISO: %d fondo(s) sin ningun dato de aum.\n' ...
                     '         El modelo equipondera, asi que hoy no estorba;\n' ...
                     '         bloquea cualquier ponderacion por tamanio.\n'], ...
                     numel(sin_aum));
            disp(sin_aum');
        end
    end
end
