% Optimal Number of managers
clear; clc;

load('ActiveData.mat')
numfunds = unique(ActiveData.fund);
dates = unique(ActiveData.date);
N = length(numfunds);

excess_return_matrix = nan(length(dates),N);
for i = 1:N
    excess_return_matrix(:,i) = ActiveData.excess_return(ismember(ActiveData.fund,numfunds(i)));
end

alpha = (prod(1+excess_return_matrix)).^(12/length(dates))-1;
alpha= mean(alpha)*100;

%forma alternativa de calcular alpha
%excess_return_port= mean(excess_return_matrix,2);
%alpha = ((prod(1+excess_return_port))^(12/length(dates))-1)*100;

pairwise_corr = corr(excess_return_matrix);
for i = 1:size(pairwise_corr,1)
    for j = 1:size(pairwise_corr,2)
        if i <= j
            pairwise_corr2(i,j)  = 0;
        else pairwise_corr2(i,j) = pairwise_corr(i,j);
        end
    end
end
alpha_corr = mean(pairwise_corr2(pairwise_corr2 ~= 0));

TE = std(excess_return_matrix);
TE = mean(TE)*sqrt(12)*100;

IR = alpha/TE;

% Tabla de resultados
categorias = {'Short-Term Bond'};
resultados = table(alpha, TE, IR,alpha_corr, 'RowNames', categorias);
disp(resultados);

% Parametros
% fees = 0.005/100;
% change_IR = 0;
% risk_aversion = 3;
% alpha = -0.06/100;
% TE = 5.257/100;
% alpha_corr = 0.27;
% Nopt = OptManagers(TE,alpha_corr,fees,change_IR,risk_aversion);

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%clear,clc,
load('PassiveData.mat')
numfunds_passive = unique(PassiveData.fund);
dates_passive = unique(PassiveData.date);
N_passive = length(numfunds_passive);

excess_return_matrix_passive = nan(length(dates_passive),N_passive);
for i = 1:N_passive
    excess_return_matrix_passive(:,i) = PassiveData.excess_return(ismember(PassiveData.fund,numfunds_passive(i)));
    non_NaN = sum(~isnan(excess_return_matrix_passive(:,i)));
    alpha_passive(i) = (prod(1+excess_return_matrix_passive(:,i),"omitnan")).^(12/non_NaN)-1;
end
alpha_passive = mean(alpha_passive)*100;


%forma alternativa de calcular alpha
%excess_return_port_passive = sum(excess_return_matrix_passive,2,"omitnan")./N_passive;
%alpha_passive = ((prod(1+excess_return_port_passive))^(12/length(dates_passive))-1)*100; 

TE_passive = std(excess_return_matrix_passive,"omitnan");
TE_passive = mean(TE_passive)*sqrt(12)*100;

%% Asignación de pesos entre gestión activa y pasiva

%Paso 1: Selección de número de fondos de gestión activa que maximizan IR
%del portafolio total (gestión activa + pasiva) respecto a un portafolio de
%gestión activa

% Parametros
fees = 0.005;
N = 1:20; % De 1 a 20 fondos de gestión activa

alpha_port = alpha-fees.*N-alpha_passive;
TE_Nfunds = sqrt(TE^2*(alpha_corr+(1-alpha_corr)./N)); %Esta en porcentaje
TE_port = sqrt(TE_Nfunds.^2-TE_passive^2);

IR = alpha_port./TE_port;

Nopt = N(max(IR)==IR); % Numero optimo de mandatos con gestión activa

%Paso 2.1: Calcular el peso optimo del total de mandatos de gestión activa (W)
% Se pueden presentar 2 casos:
% Caso 1: Si TE_port(target) <= (TE(Nopt))^2 
% Caso 2: Si TE_port(target) > (TE(Nopt))^2 

% TE_target = 1.0; %Representa 100pb de TE
% 
% if TE_target <= TE_Nfunds(Nopt)
%     W = sqrt((TE_target^2-TE_passive^2)/TE_port(Nopt)^2);
% else
%     W = 1.00;
%     fun = @(N_active) (TE_target^2-(TE^2*(alpha_corr+(1-alpha_corr)./N_active)))^2;
%     A = -1;
%     b = 0;
%     N0 = 1;
%     Nopt = round(fmincon(fun,N0,A,b));
% end

%Paso 2.2 (alternativo)










