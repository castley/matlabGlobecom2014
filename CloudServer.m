classdef CloudServer
    % CloudServer  � il Cloud Server su cui viene 
    % effettuato l'OD
    properties
        Scs % velocit� di calcolo del cloud server   
    end
    methods
        function CS = CloudServer(Scs)
            CS.Scs = Scs;        
        end
    end  
end

