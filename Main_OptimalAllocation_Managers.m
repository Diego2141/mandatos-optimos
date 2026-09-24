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
