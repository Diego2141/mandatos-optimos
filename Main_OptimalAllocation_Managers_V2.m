%% Optimal Number of managers
clear; clc;

%% Carga de data
load('ActiveData.mat')
numfunds = unique(ActiveData.fund);
dates = unique(ActiveData.date);
N = length(numfunds);

%% Matriz de alfas gross of fees por cada fondo
excess_return_matrix = nan(length(dates),N);
for i = 1:N
    excess_return_matrix(:,i) = ActiveData.excess_return(ismember(ActiveData.fund,numfunds(i)));
end

fees = nan(length(dates),N);
for i = 1:N
    fees(:,i) = ActiveData.fee(ismember(ActiveData.fund,numfunds(i)))./(12*100); %fees mensual
end

excess_return_gross = excess_return_matrix + fees; % Matriz de alfas gross of fees

%% Calculo de la nueva matriz considerando solo fondos con TE <= 0.01 
% Se considera que los fondos con IR>= 0.5 tienen fees más altos (promedio
% de amundi y bnp), mientras que los otros tienen los fees más bajos
% (pimco)
TE = std(excess_return_gross)*sqrt(12);
index_TE =  find(TE<=0.01);

% Separación por IR 
excess_return_gross = excess_return_gross(:,index_TE);
alpha = (prod(1+excess_return_gross)).^(12/length(dates))-1;
TE = std(excess_return_gross)*sqrt(12);
IR = alpha./TE;

index_IR_alto = find(IR >= 0.5);
index_IR_bajo = find(IR < 0.5);

fees_IR_alto = 0.0011; % promedio anual de los fees de Amundi y BNP
fees_IR_bajo = 0.00052; % promedio anual de los fees de PIMCO

% Se descuentan los fees dependiendo del IR (alto o bajo) del fondo 
for i = 1:size(excess_return_gross,2)
    if sum(i == index_IR_alto) == 1
        excess_return_net(:,i) = excess_return_gross(:,i)-fees_IR_alto/12;
    else
        excess_return_net(:,i) = excess_return_gross(:,i)-fees_IR_bajo/12;
    end
end

%% Boostraping 
% Se asume que la probabilidad de seleccionar un fondo con un IR alto es el
% doble de la de un fondo con IR bajo (considerando la experiencia con los
% AM - Amundi, BNP, Pimco)
weight_IR_alto = 2/3;
weight_index_IR_alto = weight_IR_alto/length(index_IR_alto); % prob de cada fondo con IR_alto
weight_index_IR_bajo = (1-weight_IR_alto)/length(index_IR_bajo);  % prob de cada fondo con IR_bajo

% Vector de probabilidades de los fondos
for i = 1:size(excess_return_net,2)
    if ismember(i,index_IR_alto)
    pesos(i) = weight_index_IR_alto;
    else
    pesos(i) = weight_index_IR_bajo;
    end
end

% Seleccion de 1000 muestras con reemplazo y nuevas probabilidades de la
% matriz exceso de retorno neto (previamente modificada)
Nsim = 1000;
for i = 1:Nsim
    resample_excess_return_net(:,:,i) = datasample(excess_return_net,size(excess_return_net,2),2,'Weights',pesos);
end

%% Calculo de estadísticos
resam_alpha = zeros(Nsim,size(resample_excess_return_net,2));
resam_TE = zeros(Nsim,size(resample_excess_return_net,2));
%resam_IR = zeros(Nsim,size(resample_excess_return_net,2));

% Percentil usado para calcular el cambio en el IR
%IR_per = 75; 

for i = 1:Nsim
    resam_alpha(i,:) = (prod(1+resample_excess_return_net(:,:,i))).^(12/length(dates))-1;
    resam_TE(i,:) = std(resample_excess_return_net(:,:,i))*sqrt(12);
    %resam_IR(i,:) = resam_alpha(i,:)./resam_TE(i,:);
    
    %resam_IR_2 = resam_IR(i,:);
    %resam_change_IR(i) = (mean(resam_IR_2(resam_IR_2>prctile(resam_IR_2,IR_per)))-prctile(resam_IR_2,IR_per))/(length(resam_IR_2)-1);

    pairwise_corr = corr(resample_excess_return_net(:,:,i));
    for j = 1:size(pairwise_corr,1)
        for k = 1:size(pairwise_corr,2)
            if j <= k
                pairwise_corr2(j,k)  = 0;
            elseif pairwise_corr(j,k) == 1
                pairwise_corr2(j,k) = 0;
            else 
                pairwise_corr2(j,k) = pairwise_corr(j,k);
            end
        end
    end
    resam_alpha_corr(i) = mean(pairwise_corr2(pairwise_corr2 ~= 0));
end

resam_port_alpha = mean(resam_alpha,2);
resam_port_TE = mean(resam_TE,2);

mean_resam_port_alpha = mean(resam_port_alpha);
mean_resam_port_TE = mean(resam_port_TE);
alpha_corr = mean(resam_alpha_corr);

alpha_active = mean_resam_port_alpha;
TE_active = mean_resam_port_TE;
IR_active = alpha_active/TE_active;
%mean_resam_change_IR = mean(resam_change_IR,'omitnan');

%% Data Pasiva (Portafolio interno - Tramo de Inversión, portafolio USD)
load("PassiveData_IndicesGOI.mat"); %La data está en pb

excess_return_passive = PassiveData_IndicesGOI.excess_return/10000;
alpha_passive = prod(1+excess_return_passive).^(12/length(excess_return_passive))-1;
%alpha_passive = alpha_passive*100;

TE_passive = std(excess_return_passive)*sqrt(12);
%TE_passive = TE_passive*100;

%% Asignación de pesos entre gestión activa y pasiva

%Paso 1: Selección de número de fondos de gestión activa que maximizan IR
%del portafolio total (gestión activa + pasiva) respecto a un portafolio de
%gestión activa

% Parametros
fees = 0.4/10000;
N = 1:20; % De 1 a 20 fondos de gestión activa 

alpha_port = alpha_active-fees.*N-alpha_passive;
TE_Nfunds = sqrt(TE_active^2*(alpha_corr+(1-alpha_corr)./N)); %Esta en porcentaje
TE_port = sqrt(TE_Nfunds.^2-TE_passive^2);

IR = alpha_port./TE_port;

Nopt = N(max(IR)==IR); % Numero optimo de mandatos con gestión activa

%Paso 2: Calcular el peso optimo del total de mandatos de gestión activa (W)
% Se pueden presentar 2 casos:
% Caso 1: Si TE_port(target) <= (TE(Nopt))^2 
% Caso 2: Si TE_port(target) > (TE(Nopt))^2 

TE_target = (0.0010:0.0001:0.0057)';

for i = 1:length(TE_target)
    if TE_target(i) <= TE_Nfunds(Nopt)
        W(i) = sqrt((TE_target(i)^2-TE_passive^2)/TE_port(Nopt)^2);
    else
        W(i) = 1.00;
        fun = @(N_active) (TE_target(i)^2-(TE_active^2*(alpha_corr+(1-alpha_corr)./N_active)))^2;
        A = -1;
        b = 0;
        N0 = 1;
        Nopt_new(i) = fmincon(fun,N0,A,b);
    end
end

W = W' ;

% Nopt = 5;
% risk_aversion = 3;
% (alpha_port(Nopt)/100)/(risk_aversion*(TE_port(Nopt)/100)^2)  






%% =======================================================================
%  GRAFICOS - Numero Optimo de Mandatos Activos (BCRP)
%  Este bloque va A CONTINUACION del script original (Optimal Number of
%  managers). Usa las variables ya calculadas: N, IR, alpha_port,
%  TE_Nfunds, TE_port, Nopt, TE_target, W, alpha_active, TE_active,
%  alpha_corr, alpha_passive, TE_passive.
%  =======================================================================

%% -----------------------------------------------------------------------
%  GRAFICO 7 - Numero optimo de portafolios activos
%  Replica: TE activo vs activo, alfa activo vs pasivo, IR (eje secundario)
%  -----------------------------------------------------------------------

fig7 = figure('Color','w','Position',[100 100 800 500]);

yyaxis left
hold on
plot(N, TE_Nfunds*100, '-', 'Color', [0.30 0.55 0.85], 'LineWidth', 2, ...
    'DisplayName', 'TE activo vs activo');
plot(N, alpha_port*100, '-', 'Color', [0.65 0.65 0.65], 'LineWidth', 2, ...
    'DisplayName', 'alfa activo vs pasivo');
ylabel('TE, alfa')
ytickformat('%.2f%%')
ylim([0, max(TE_Nfunds*100)*1.15])

yyaxis right
plot(N, IR, '-o', 'Color', [0.05 0.15 0.35], 'LineWidth', 2, ...
    'MarkerFaceColor', [0.05 0.15 0.35], 'MarkerSize', 5, ...
    'DisplayName', 'IR (eje secundario)');
ylabel('IR')

% Punto optimo resaltado (rojo, como en el documento)
plot(Nopt, IR(N==Nopt), 'o', 'MarkerSize', 10, 'MarkerFaceColor', 'r', ...
    'MarkerEdgeColor', 'r', 'HandleVisibility','off')
xline(Nopt, '--r', 'HandleVisibility','off')

xlabel('Numero de fondos activos (N)')
title('Gráfico 7 – Número óptimo de portafolios activos')
legend('Location','southoutside','Orientation','horizontal','Box','off')
xlim([1, max(N)])
xticks(1:1:max(N))
grid on
box on
hold off

exportgraphics(fig7, 'grafico7_numero_optimo_portafolios.png', 'Resolution', 300)

fprintf('N óptimo (Paso 1) = %d\n', Nopt)
fprintf('IR máximo = %.4f\n', IR(N==Nopt))
fprintf('TE(N*) = %.2f pbs\n', TE_Nfunds(Nopt)*10000)

%% -----------------------------------------------------------------------
%  GRAFICO 8 - Peso optimo de la gestion activa (W*) vs TE objetivo
%  -----------------------------------------------------------------------

fig8 = figure('Color','w','Position',[100 100 800 500]);

plot(TE_target*10000, W*100, '-', 'Color', [0.15 0.35 0.65], 'LineWidth', 2.2)
xlabel('TE objetivo (en pbs)')
ylabel('Peso óptimo gestión activa (W*)')
ytickformat('%.1f%%')
title('Gráfico 8 – Peso óptimo de la gestión activa')
grid on
box on

% Marcadores de referencia citados en el texto: 10, 15, 20 pbs
ref_pbs = [10, 15, 20];
hold on
for r = ref_pbs
    [~, idx] = min(abs(TE_target*10000 - r));
    plot(TE_target(idx)*10000, W(idx)*100, 'o', 'MarkerFaceColor','r', ...
        'MarkerEdgeColor','r', 'MarkerSize', 7, 'HandleVisibility','off')
    text(TE_target(idx)*10000, W(idx)*100 + 1.5, ...
        sprintf('%.0f%%', W(idx)*100), 'HorizontalAlignment','center', ...
        'FontSize', 9)
end
hold off

exportgraphics(fig8, 'grafico8_peso_optimo_gestion_activa.png', 'Resolution', 300)

for r = ref_pbs
    [~, idx] = min(abs(TE_target*10000 - r));
    fprintf('TE objetivo = %d pbs  ->  W* = %.1f%%\n', r, W(idx)*100)
end

%% -----------------------------------------------------------------------
%  NOTA: verificacion N=5 vs entero vecino (discutido en la conversacion)
%  El optimo continuo de la cuadratica puede no coincidir exactamente
%  con el entero de mayor IR discreto. Se verifica explicitamente aqui.
%  -----------------------------------------------------------------------
[~, idx_disc] = max(IR);
fprintf('\nVerificación discreta: N que maximiza IR en la grilla N=1:%d es N=%d\n', ...
    max(N), N(idx_disc))
if N(idx_disc) ~= Nopt
    fprintf('ADVERTENCIA: difiere del Nopt calculado por igualdad exacta (revisar empate/redondeo)\n')
end








%% =======================================================================
%  ANALISIS DE SENSIBILIDAD - N* optimo (BCRP)
%  Va a continuacion de los scripts anteriores. Si las variables
%  alpha_active, TE_active, alpha_corr, alpha_passive, TE_passive, fees
%  ya existen en el workspace (del script original), las usa. Si no,
%  usa los valores reportados en el informe como fallback.
%  =======================================================================

if ~exist('alpha_active','var'),  alpha_active  = 0.0040; end   % alfa neto activo
if ~exist('TE_active','var'),     TE_active     = 0.0076; end   % TE de cada fondo activo
if ~exist('alpha_corr','var'),    alpha_corr    = 0.46;   end   % rho
if ~exist('alpha_passive','var'), alpha_passive = 0.0014; end   % alfa pasivo
if ~exist('TE_passive','var'),    TE_passive    = 0.0009; end   % TE pasivo
if ~exist('fees','var'),          fees          = 0.4/10000; end % k, costo de diligencia

alpha_base = alpha_active;
rho_base   = alpha_corr;
k_base     = fees;
sigma      = TE_active;
alpha_p    = alpha_passive;
sigma_p    = TE_passive;

%% -----------------------------------------------------------------------
%  Funcion: N* continuo via la cuadratica cerrada (derivada de la FOC)
%  2k(sigma^2*rho - sigma_p^2)N^2 + 3k*sigma^2*(1-rho)N
%    - sigma^2*(1-rho)*(alpha-alpha_p) = 0
%  -----------------------------------------------------------------------
nstar_fun = @(a_, rho_, k_) local_nstar(a_, rho_, k_, sigma, alpha_p, sigma_p);

function Nc = local_nstar(alpha_, rho_, k_, sigma_, alpha_p_, sigma_p_)
    A = 2*k_*(sigma_^2*rho_ - sigma_p_^2);
    B = 3*k_*sigma_^2*(1-rho_);
    C = -sigma_^2*(1-rho_)*(alpha_ - alpha_p_);

    if abs(A) < 1e-14
        % Caso degenerado (A~0): la ecuacion es lineal, no cuadratica
        if abs(B) < 1e-14
            Nc = NaN; % sin costo de diligencia ni curvatura -> no hay maximo finito
        else
            Nc = -C/B;
        end
        return
    end

    disc = B^2 - 4*A*C;
    if disc < 0
        Nc = NaN; % no hay raiz real -> IR monotona en el rango, sin maximo interior
        return
    end
    r1 = (-B + sqrt(disc)) / (2*A);
    r2 = (-B - sqrt(disc)) / (2*A);
    cand = [r1 r2];
    cand = cand(cand > 0 & isreal(cand));
    if isempty(cand)
        Nc = NaN;
    else
        Nc = min(cand); % raiz positiva relevante (la mas chica y positiva es el maximo)
    end
end

fprintf('N* continuo en el caso base: %.2f\n', nstar_fun(alpha_base, rho_base, k_base))

%% =======================================================================
%  1) HEATMAP CONJUNTO: N*(rho, alpha) con k fijo en su valor base
%     Esta es la pieza principal: muestra la interaccion entre los dos
%     parametros mas influyentes, algo que un tornado NO puede mostrar.
%  =======================================================================

rho_grid   = linspace(0.20, 0.75, 60);
alpha_grid = linspace(0.0020, 0.0060, 60);   % 20 a 60 pbs

Nstar_grid = nan(length(rho_grid), length(alpha_grid));
for i = 1:length(rho_grid)
    for j = 1:length(alpha_grid)
        Nstar_grid(i,j) = nstar_fun(alpha_grid(j), rho_grid(i), k_base);
    end
end

% Cap visual para valores no finitos / extremos (evita escala distorsionada)
Nstar_plot = Nstar_grid;
Nstar_plot(isnan(Nstar_plot)) = 40;
Nstar_plot(Nstar_plot > 40) = 40;

figA = figure('Color','w','Position',[100 100 850 620]);
contourf(alpha_grid*10000, rho_grid, Nstar_plot, 20, 'LineColor','none')
colormap(turbo)
cb = colorbar;
cb.Label.String = 'N* (número óptimo de mandatos)';
hold on

% Curvas de nivel enteras para lectura directa
[C1,h1] = contour(alpha_grid*10000, rho_grid, Nstar_plot, [3 5 7 10 15 20], ...
    'LineColor','w','LineWidth',1.1);
clabel(C1,h1,'Color','w','FontWeight','bold','FontSize',9)

% Punto base (caso del informe)
plot(alpha_base*10000, rho_base, 'p', 'MarkerSize', 16, ...
    'MarkerFaceColor','r', 'MarkerEdgeColor','k', 'LineWidth',1.2)
text(alpha_base*10000+1, rho_base+0.02, 'Caso base', ...
    'Color','w','FontWeight','bold','FontSize',10)

xlabel('\alpha activo neto (pbs)')
ylabel('\rho (correlación entre fondos activos)')
title('Sensibilidad conjunta de N* a \rho y \alpha (k fijo = costo de diligencia base)')
hold off

exportgraphics(figA, 'sensibilidad_heatmap_rho_alpha.png', 'Resolution', 300)

%% =======================================================================
%  2) TORNADO: sensibilidad de N* a cada parametro por separado
%     (rho, alpha, k), +/-25% del valor base, los demas fijos.
%     Util como resumen de una sola tabla, pero NO reemplaza al heatmap:
%     no captura la interaccion/covarianza entre parametros.
%  =======================================================================

pct = 0.25; % rango +/- 25% respecto al valor base

params = struct( ...
    'name',  {'\rho (correlación)', '\alpha (alfa activo neto)', 'k (costo diligencia)'}, ...
    'base',  {rho_base,             alpha_base,                  k_base}, ...
    'low',   {rho_base*(1-pct),     alpha_base*(1-pct),          k_base*(1-pct)}, ...
    'high',  {rho_base*(1+pct),     alpha_base*(1+pct),          k_base*(1+pct)} ...
);

Nstar_low  = zeros(1,3);
Nstar_high = zeros(1,3);

for p = 1:3
    switch p
        case 1 % rho varia
            Nstar_low(p)  = nstar_fun(alpha_base, params(p).low,  k_base);
            Nstar_high(p) = nstar_fun(alpha_base, params(p).high, k_base);
        case 2 % alpha varia
            Nstar_low(p)  = nstar_fun(params(p).low,  rho_base, k_base);
            Nstar_high(p) = nstar_fun(params(p).high, rho_base, k_base);
        case 3 % k varia
            Nstar_low(p)  = nstar_fun(alpha_base, rho_base, params(p).low);
            Nstar_high(p) = nstar_fun(alpha_base, rho_base, params(p).high);
    end
end

Nstar_base_val = nstar_fun(alpha_base, rho_base, k_base);
delta_range = abs(Nstar_high - Nstar_low);
[~, ord] = sort(delta_range, 'descend'); % mayor impacto arriba

figB = figure('Color','w','Position',[100 100 800 420]);
hold on
y_pos = length(ord):-1:1;
for idx = 1:length(ord)
    p = ord(idx);
    lo = min(Nstar_low(p), Nstar_high(p));
    hi = max(Nstar_low(p), Nstar_high(p));
    barh(y_pos(idx), hi-lo, 0.5, 'BaseValue', lo, ...
        'FaceColor', [0.25 0.45 0.75], 'EdgeColor','k')
end
xline(Nstar_base_val, '--r', 'LineWidth', 1.5)
yticks(1:length(ord))
yticklabels({params(ord(end:-1:1)).name})
xlabel('N* (rango al variar cada parámetro ±25% del caso base)')
title('Tornado: sensibilidad de N* a cada parámetro por separado')
legend({'Rango N*','N* caso base'}, 'Location','southoutside','Orientation','horizontal','Box','off')
grid on
box on
hold off

exportgraphics(figB, 'sensibilidad_tornado.png', 'Resolution', 300)

%% =======================================================================
%  3) TABLA RESUMEN (para reporte / comité)
%  =======================================================================

Tabla = table( ...
    {params.name}', [params.low]', [params.base]', [params.high]', ...
    Nstar_low', repmat(Nstar_base_val,3,1), Nstar_high', delta_range', ...
    'VariableNames', {'Parametro','Valor_bajo','Valor_base','Valor_alto', ...
                       'Nstar_bajo','Nstar_base','Nstar_alto','Rango_Nstar'});
Tabla = sortrows(Tabla, 'Rango_Nstar', 'descend');

disp(Tabla)
writetable(Tabla, 'tabla_sensibilidad_Nstar.csv')

fprintf('\nInterpretación rápida: el parámetro con mayor Rango_Nstar domina la incertidumbre de N*.\n')
fprintf('Este resultado (tornado) asume independencia entre parámetros;\n')
fprintf('el heatmap de la sección 1 es la referencia correcta si sospechas covarianza entre rho y alpha.\n')





%% =======================================================================
%  TABLAS DE SENSIBILIDAD ESTILO "STOCK PITCH" (data tables 2-way)
%  Tres tablas, cada una cruza dos parametros y deja el tercero fijo en
%  su valor base. Usa la misma funcion nstar_fun / local_nstar definida
%  en sensibilidad_Nstar.m -- correr ese script primero, o pegar este
%  bloque a continuacion en el mismo archivo.
%  =======================================================================

% Grillas discretas, estilo tabla de sensibilidad (no 60 puntos, sino
% un numero manejable de filas/columnas para lectura directa, como en
% una tabla de sensibilidad de WACC x g en un DCF)

rho_vals   = [0.30 0.38 0.46 0.54 0.62 0.70];         % filas
alpha_vals = [0.0025 0.0030 0.0035 0.0040 0.0045 0.0050 0.0055]*10000/10000; % columnas (en decimal)
k_vals     = [0.0002 0.0003 0.0004 0.0005 0.0006 0.0007]; % en decimal (0.4pbs base = 0.00004... ojo unidades)

% OJO DE UNIDADES: en el script original, fees = 0.4/10000 = 0.00004
% (0.4 pbs expresado en decimal). Redefino k_vals en esas mismas unidades:
k_vals = [0.2 0.3 0.4 0.5 0.6 0.7]/10000;

%% -----------------------------------------------------------------------
%  TABLA 1: rho (filas) x alfa (columnas), k fijo en base
%  -----------------------------------------------------------------------
Tabla1 = nan(length(rho_vals), length(alpha_vals));
for i = 1:length(rho_vals)
    for j = 1:length(alpha_vals)
        Tabla1(i,j) = local_nstar(alpha_vals(j), rho_vals(i), k_base, sigma, alpha_p, sigma_p);
    end
end

fig1 = figure('Color','w','Position',[100 100 780 480]);
h1 = heatmap(alpha_vals*10000, rho_vals, round(Tabla1,1), ...
    'Colormap', turbo, 'ColorbarVisible','on');
h1.Title = sprintf('N* — \\rho vs \\alpha  (k fijo = %.2f pbs)', k_base*10000);
h1.XLabel = '\alpha activo neto (pbs)';
h1.YLabel = '\rho (correlación)';
h1.MissingDataColor = [0.85 0.85 0.85];
h1.MissingDataLabel = 'sin máximo';

exportgraphics(fig1, 'tabla1_rho_vs_alpha.png', 'Resolution', 300)

%% -----------------------------------------------------------------------
%  TABLA 2: rho (filas) x k (columnas), alfa fijo en base
%  -----------------------------------------------------------------------
Tabla2 = nan(length(rho_vals), length(k_vals));
for i = 1:length(rho_vals)
    for j = 1:length(k_vals)
        Tabla2(i,j) = local_nstar(alpha_base, rho_vals(i), k_vals(j), sigma, alpha_p, sigma_p);
    end
end

fig2 = figure('Color','w','Position',[100 100 780 480]);
h2 = heatmap(k_vals*10000, rho_vals, round(Tabla2,1), ...
    'Colormap', turbo, 'ColorbarVisible','on');
h2.Title = sprintf('N* — \\rho vs k  (\\alpha fijo = %.0f pbs)', alpha_base*10000);
h2.XLabel = 'k, costo de diligencia (pbs)';
h2.YLabel = '\rho (correlación)';
h2.MissingDataColor = [0.85 0.85 0.85];
h2.MissingDataLabel = 'sin máximo';

exportgraphics(fig2, 'tabla2_rho_vs_k.png', 'Resolution', 300)

%% -----------------------------------------------------------------------
%  TABLA 3: alfa (filas) x k (columnas), rho fijo en base
%  -----------------------------------------------------------------------
Tabla3 = nan(length(alpha_vals), length(k_vals));
for i = 1:length(alpha_vals)
    for j = 1:length(k_vals)
        Tabla3(i,j) = local_nstar(alpha_vals(i), rho_base, k_vals(j), sigma, alpha_p, sigma_p);
    end
end

fig3 = figure('Color','w','Position',[100 100 780 480]);
h3 = heatmap(k_vals*10000, alpha_vals*10000, round(Tabla3,1), ...
    'Colormap', turbo, 'ColorbarVisible','on');
h3.Title = sprintf('N* — \\alpha vs k  (\\rho fijo = %.2f)', rho_base);
h3.XLabel = 'k, costo de diligencia (pbs)';
h3.YLabel = '\alpha activo neto (pbs)';
h3.MissingDataColor = [0.85 0.85 0.85];
h3.MissingDataLabel = 'sin máximo';

exportgraphics(fig3, 'tabla3_alpha_vs_k.png', 'Resolution', 300)

%% -----------------------------------------------------------------------
%  Exportar las tres matrices como CSV (para pegar en Excel/informe)
%  -----------------------------------------------------------------------
T1 = array2table(round(Tabla1,2), 'VariableNames', ...
    matlab.lang.makeValidName(string(alpha_vals*10000)+"pbs"), ...
    'RowNames', matlab.lang.makeValidName("rho_"+string(rho_vals)));
T2 = array2table(round(Tabla2,2), 'VariableNames', ...
    matlab.lang.makeValidName(string(k_vals*10000)+"pbs_k"), ...
    'RowNames', matlab.lang.makeValidName("rho_"+string(rho_vals)));
T3 = array2table(round(Tabla3,2), 'VariableNames', ...
    matlab.lang.makeValidName(string(k_vals*10000)+"pbs_k"), ...
    'RowNames', matlab.lang.makeValidName("alpha_"+string(alpha_vals*10000)+"pbs"));

writetable(T1, 'tabla1_rho_vs_alpha.csv', 'WriteRowNames', true)
writetable(T2, 'tabla2_rho_vs_k.csv', 'WriteRowNames', true)
writetable(T3, 'tabla3_alpha_vs_k.csv', 'WriteRowNames', true)

fprintf('Caso base: rho=%.2f, alpha=%.0fpbs, k=%.2fpbs -> N*=%.2f\n', ...
    rho_base, alpha_base*10000, k_base*10000, ...
    local_nstar(alpha_base, rho_base, k_base, sigma, alpha_p, sigma_p))
fprintf('Tres tablas exportadas (png + csv). Celdas grises = sin máximo interior (IR monótono).\n')




%% =======================================================================
%  COMPARACION FAIR DE SENSIBILIDAD
%  Dos metricas, no una:
%  (A) Elasticidad puntual analitica (derivada exacta en el caso base,
%      NO depende de ningun rango elegido a mano -> comparable entre
%      parametros de forma limpia)
%  (B) Impacto esperado = derivada x incertidumbre REAL de cada parametro
%      (idealmente el error estandar del bootstrap, Nivel 1). Esta es la
%      metrica que de verdad le importa a un comite: no "que tan
%      empinada es la curva" sino "cuanto se mueve el resultado dado lo
%      que realmente no sabemos".
%  =======================================================================

syms a r k s sp ap real  % alpha, rho, k, sigma, sigma_p, alpha_p simbolicos

% F(N; a,r,k) = 0 es la condicion de primer orden (ver derivacion previa),
% expresada como raiz de la cuadratica en N. En vez de resolver N(a,r,k)
% simbolicamente (feo, con raiz cuadrada anidada), uso diferenciacion
% implicita directa sobre F(N,a,r,k)=0:
%   F = 2k(s^2 r - sp^2) N^2 + 3k s^2 (1-r) N - s^2(1-r)(a-ap)
% dN/dtheta = - (dF/dtheta) / (dF/dN)   [teorema de la funcion implicita]

syms N real
F = 2*k*(s^2*r - sp^2)*N^2 + 3*k*s^2*(1-r)*N - s^2*(1-r)*(a-ap);

dF_dN     = diff(F, N);
dF_dalpha = diff(F, a);
dF_drho   = diff(F, r);
dF_dk     = diff(F, k);

dN_dalpha = -dF_dalpha / dF_dN;
dN_drho   = -dF_drho   / dF_dN;
dN_dk     = -dF_dk     / dF_dN;

%% -----------------------------------------------------------------------
%  Evaluar en el caso base (mismos valores que ya vienes usando)
%  -----------------------------------------------------------------------
base = struct('a', 0.0040, 'r', 0.46, 'k', 0.4/10000, ...
              's', 0.0076, 'sp', 0.0009, 'ap', 0.0014);

N_base = double(local_nstar_check(base));  % N* en el caso base (via cuadratica)

subs_vals = [a r k s sp ap N] == [base.a base.r base.k base.s base.sp base.ap N_base];

dN_dalpha_val = double(subs(dN_dalpha, [a r k s sp ap N], ...
    [base.a base.r base.k base.s base.sp base.ap N_base]));
dN_drho_val   = double(subs(dN_drho,   [a r k s sp ap N], ...
    [base.a base.r base.k base.s base.sp base.ap N_base]));
dN_dk_val     = double(subs(dN_dk,     [a r k s sp ap N], ...
    [base.a base.r base.k base.s base.sp base.ap N_base]));

%% -----------------------------------------------------------------------
%  (A) Elasticidad puntual: adimensional, NO depende de ningun rango
%  -----------------------------------------------------------------------
elast_alpha = dN_dalpha_val * (base.a / N_base);
elast_rho   = dN_drho_val   * (base.r / N_base);
elast_k     = dN_dk_val     * (base.k / N_base);

fprintf('=== (A) ELASTICIDAD PUNTUAL (comparable, sin rango arbitrario) ===\n')
fprintf('  alpha : %.3f\n', elast_alpha)
fprintf('  rho   : %.3f\n', elast_rho)
fprintf('  k     : %.3f\n', elast_k)
fprintf('  (mayor |valor| = mas influyente en el margen, en el caso base)\n\n')

%% -----------------------------------------------------------------------
%  (B) Impacto esperado = derivada x incertidumbre REAL (bootstrap)
%  Reemplaza estos SE por los que salgan de tu bootstrap real (Nivel 1):
%  SE_alpha = std(resam_port_alpha), SE_rho = std(resam_alpha_corr), etc.
%  Aqui dejo valores ilustrativos -- CAMBIALOS por los tuyos.
%  -----------------------------------------------------------------------
SE_alpha_bootstrap = 0.0006;   % <-- reemplazar con std(resam_port_alpha)
SE_rho_bootstrap   = 0.08;     % <-- reemplazar con std(resam_alpha_corr)
SE_k_bootstrap      = 0.05/10000; % k no viene del bootstrap de fondos;
                                   % si no tienes incertidumbre real de k,
                                   % NO lo incluyas en esta comparacion --
                                   % es deshonesto inventarle un SE.

impacto_alpha = abs(dN_dalpha_val) * SE_alpha_bootstrap;
impacto_rho   = abs(dN_drho_val)   * SE_rho_bootstrap;
impacto_k     = abs(dN_dk_val)     * SE_k_bootstrap;

fprintf('=== (B) IMPACTO ESPERADO (derivada x incertidumbre real) ===\n')
fprintf('  alpha : %.3f puntos de N* por 1 SE de incertidumbre real\n', impacto_alpha)
fprintf('  rho   : %.3f puntos de N*\n', impacto_rho)
fprintf('  k     : %.3f puntos de N*  [OJO: SE inventado, ver comentario abajo]\n', impacto_k)
fprintf(['\nADVERTENCIA: si no tienes un SE real para k (no sale del bootstrap ' ...
    'de fondos porque k se calibra aparte, con sueldo de analista y AUM supuesto), ' ...
    'no lo incluyas en el ranking de (B) como si tuviera el mismo tipo de evidencia ' ...
    'que alpha y rho. Repórtalo aparte, con su propia fuente de incertidumbre ' ...
    '(ej. rango de sueldos de mercado para el especialista, no un bootstrap de fondos).\n'])

function Nc = local_nstar_check(b)
    A = 2*b.k*(b.s^2*b.r - b.sp^2);
    B = 3*b.k*b.s^2*(1-b.r);
    C = -b.s^2*(1-b.r)*(b.a - b.ap);
    disc = B^2 - 4*A*C;
    r1 = (-B + sqrt(disc)) / (2*A);
    r2 = (-B - sqrt(disc)) / (2*A);
    cand = [r1 r2];
    cand = cand(cand > 0);
    Nc = min(cand);
end


















%% Comparación bootstrap: historia completa vs. ventanas de 5 años
b5_meses = 90;
[b5_T, b5_F] = size(excess_return_net);
assert(b5_T >= b5_meses, 'Se requieren al menos 60 meses.');
assert(b5_F >= 2, 'Se requieren al menos dos fondos.');

b5_stats = nan(Nsim,3);  % Alfa, TE y correlación

for b5_i = 1:Nsim
    % Seleccionar una ventana de 60 meses y remuestrear fondos
    b5_inicio = randi(b5_T - b5_meses + 1);
    b5_muestra = datasample( ...
        excess_return_net(b5_inicio:b5_inicio+b5_meses-1,:), ...
        b5_F, 2, 'Replace', true, 'Weights', pesos);

    % Estadísticos: mismas definiciones que en el caso base
    b5_stats(b5_i,1) = mean(prod(1+b5_muestra).^(12/b5_meses)-1);
    b5_stats(b5_i,2) = mean(std(b5_muestra)*sqrt(12));

    b5_R = corr(b5_muestra);
    b5_pares = b5_R(tril(true(b5_F),-1));
    b5_stats(b5_i,3) = mean(b5_pares(b5_pares ~= 0 & b5_pares ~= 1));
end

% Resultados por simulación, incluyendo IR
b5_base = [resam_port_alpha(:), resam_port_TE(:), resam_alpha_corr(:)];
b5_base(:,4)  = b5_base(:,1)./b5_base(:,2);
b5_stats(:,4) = b5_stats(:,1)./b5_stats(:,2);

% Estimaciones finales: IR = alfa medio / TE medio
b5_media_base = [alpha_active, TE_active, alpha_corr, IR_active];
b5_media = mean(b5_stats(:,1:3),1);
b5_media(4) = b5_media(1)/b5_media(2);

cuadro_bootstrap = table( ...
    ["Alfa anual"; "TE anual"; "Correlacion"; "IR"], ...
    b5_media_base', b5_media', (b5_media-b5_media_base)', ...
    std(b5_base,0,1)', std(b5_stats,0,1)', ...
    'VariableNames', {'Estadistico','Base','Cinco_anios', ...
                      'Diferencia','Desv_base','Desv_5a'});

disp(cuadro_bootstrap)
















