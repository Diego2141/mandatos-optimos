function info = inspeccionar_tabla(T, nombre)
% INSPECCIONAR_TABLA  Reporte de esquema y calidad de una tabla.
%
%   info = inspeccionar_tabla(T, nombre)
%
% Imprime por cada variable: clase, numero de faltantes, valores unicos y
% rango. Devuelve una tabla con lo mismo para uso programatico.
%
% El objetivo no es decorar la consola: es que cualquier desalineacion de
% fechas, tipo inesperado o columna con NaN aparezca ANTES de que entre al
% modelo, no despues de que salga un N* raro.

    arguments
        T table
        nombre (1,:) char = 'tabla'
    end

    fprintf('\n%s\n', repmat('=', 1, 78));
    fprintf('  %s\n', upper(nombre));
    fprintf('%s\n', repmat('=', 1, 78));
    fprintf('  Filas: %d   Variables: %d\n\n', height(T), width(T));

    nv        = width(T);
    variable  = strings(nv,1);
    clase     = strings(nv,1);
    faltantes = zeros(nv,1);
    pct_falt  = zeros(nv,1);
    n_unicos  = zeros(nv,1);
    minimo    = strings(nv,1);
    maximo    = strings(nv,1);
    ejemplo   = strings(nv,1);

    for k = 1:nv
        col = T.(k);
        variable(k) = string(T.Properties.VariableNames{k});
        clase(k)    = string(class(col));

        try
            falt = sum(ismissing(col));
        catch
            falt = 0;   % tipos que no soportan ismissing
        end
        faltantes(k) = falt;
        pct_falt(k)  = 100 * falt / max(height(T), 1);

        try
            n_unicos(k) = numel(unique(col(~ismissing(col))));
        catch
            n_unicos(k) = NaN;
        end

        if isnumeric(col) || islogical(col)
            v = double(col(~isnan(double(col))));
            if isempty(v)
                minimo(k) = "-";  maximo(k) = "-";
            else
                minimo(k) = sprintf('%.6g', min(v));
                maximo(k) = sprintf('%.6g', max(v));
            end
        elseif isdatetime(col)
            v = col(~isnat(col));
            if isempty(v)
                minimo(k) = "-";  maximo(k) = "-";
            else
                minimo(k) = string(datestr(min(v), 'yyyy-mm-dd'));
                maximo(k) = string(datestr(max(v), 'yyyy-mm-dd'));
            end
        else
            minimo(k) = "-";  maximo(k) = "-";
        end

        if height(T) > 0
            try
                ejemplo(k) = string(col(1));
            catch
                ejemplo(k) = "<no imprimible>";
            end
        end
    end

    info = table(variable, clase, faltantes, pct_falt, n_unicos, ...
                 minimo, maximo, ejemplo);
    info.Properties.VariableNames = {'variable','clase','faltantes', ...
        'pct_faltantes','n_unicos','min','max','ejemplo'};
    disp(info);

    % --- Avisos que importan para este modelo -----------------------------
    con_falt = info.variable(info.faltantes > 0);
    if ~isempty(con_falt)
        fprintf('  AVISO: variables con datos faltantes: %s\n', ...
                strjoin(cellstr(con_falt), ', '));
        fprintf('         prod() sin ''omitnan'' convierte el alpha de ese\n');
        fprintf('         fondo en NaN y lo propaga al promedio.\n');
    end

    esperadas = ["fund","date","excess_return"];
    presentes = lower(info.variable);
    faltan = esperadas(~ismember(esperadas, presentes));
    if ~isempty(faltan)
        fprintf('  AVISO: no se encontraron las variables %s\n', ...
                strjoin(cellstr(faltan), ', '));
        fprintf('         el codigo del modelo las usa por nombre exacto.\n');
    end
end
