function Nopt = OptManagers(sigma,alpha_corr,fees,change_IR,risk_aversion)
 Nlim = 100;  
 Nopt =[];
 for i = 2:Nlim
     if risk_aversion*sigma^2*(1-alpha_corr)/(2*i*(i-1)) >= fees-change_IR*sigma
         Nopt = i;
     end 
 end
 
 if Nopt == []
     display("No solution was found");
 end

