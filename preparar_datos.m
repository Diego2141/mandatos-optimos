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
        [g, ~]   = findgroups(P.fund, P.tramo);
        n_obs    = splitapply(@numel, P.date, g);
        fprintf('  Observaciones por fondo-tramo: min=%d  mediana=%d  max=%d\n', ...
                min(n_obs), round(median(n_obs)), max(n_obs));
        if numel(unique(n_obs)) > 1
            fprintf(['  AVISO: panel DESBALANCEADO. El modelo preasigna\n' ...
                     '         nan(length(dates), N) y asume paneles completos.\n' ...
                     '         Con historias distintas hay que hacer join por\n' ...
                     '         fecha, no asignacion posicional.\n']);
        else
            fprintf('  OK: panel balanceado (%d observaciones por fondo).\n', n_obs(1));
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
    end
end
