clear all;
close all;
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% In this case we are considering Throughput as Utility Function
% and 4 RATs (see above) 
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% generation of pseudo random position for SMDs and association of APP
NMD = [500 1000 2000]; %1000 2000 5000
NMDmax = max(NMD);
rng(1);
pos = rand(2,NMDmax);
rng(1);
app_n = randi(3,1,NMDmax);

% Biased Randomization Values:
p = 0.01; % 
Nloop = 10;


%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% Environment 
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

% RAT instance
% object RAT(BW,BWtot,pos,n_max,n)
% BW - NOT UTILIZED bandwidth assigned for a request
% BWtot - channel capacity of the RAT
% pos - (x,y) cohordinates indicating the position of the RAT
% n_max - NOT UTILIZED maximum number of allowed connected devices
% n - number of connected devices

RAT1 = RAT(1,22,[0,0],100,0);
RAT2 = RAT(1,22,[500,999],100,0);
LTE  = RAT(1,100,[500,500],500,0);
RAT3 = RAT(1,22,[1000,0],100,0);

RAT  = [RAT1,RAT2,LTE, RAT3]; % RAT vector instance
M = length(RAT); % number of RAT

% Application instance
% object Application(O,D,gamma,delta,c1,c2,c3,Stro,Eo,To)
% O - number of Operations 
% D - amount of data to transfer
% gamma - percentage of O to be offloaded
% delta - percentage of D to be offloaded
% c1 - wheight of f1(Str) in the Utility Function
% c2 - wheight of f2(E) in the Utility Function
% c3 - wheight of f3(T) in the Utility Function
% Stro - reference value for f1(Str)
% Eo - reference value for f2(E) 
% To - reference value for f3(T)
App1 = Application(1000,1000, 0.5,0.5,0.6,0.2,0.2,0.52e3,     2.9e3      ,25000 ); % application 1
App2 = Application(1E7,10 ,0.01,0.9,0.2,0.2,0.6,1.42e3,     3.6e3       ,2500 ); % application 2
App3 = Application(1.5E7,10 ,0.01,0.9,0.2,0.6,0.2,0.93e3,     7.1e3      ,75000 ); % application 3
App = [App1,App2,App3]; % App vector instance

% Cloudserver instance
% object CloudServer(Scs)
% Scs - Computation speed 
CS1 = CloudServer(10^6);


% Device and application instances
for j=1:NMDmax  % N = number of devices
   % Device instance
   % object MobileDevice(Pid,Smd,SNR,Pl,Ptr,pos,do,Energy)
   % Pid - Power for idle while the device is waiting for the remote computing
   % Smd - Computation speed for local computation 
   % SNR - Signal to Noise Ratio (reference distance = 1m)
   % Pl - Power for local computation 
   % Ptr - Power for transmission 
   % pos  - (x,y) cohordinates indicating the position of the device
   % do - NOT UTILIZED coverage radius
   % Energy - NOT UTILIZED True if the mobile device has limited battery lifetime
   
   MD(j) = MobileDevice(0.3,400,1000,0.9,1.3,[pos(1,j)*1000,pos(2,j)*1000],800,true);
     
   % random requesting of application for the device     
   app(j) = App1;
   %App(app_n(j));
end

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%    
%
%  Computing the distance and the constant part of the througput
%  (as RAT(i).n = 1
%
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
for j=1:NMDmax
    for i=1:M
        dist(j,i)= Distanza(RAT(i),MD(j));
        Th_K(j,i)= RAT(i).BWtot * log2(1+MD(j).SNR/(dist(j,i)^2));
    end
    distmin(j)= min(dist(j,:));
    ratsceltadist(j) = find(dist(j,:) == distmin(j),1, 'first');    
end

for N = NMD
clearvars -except MD app CS1 RAT N M NMD p Nloop Sdef ...
    dist Th_K distmin ratsceltadist ...
    S_mindist_av E_mindist_av T_mindist_av ...
    S_M_av       E_M_av       T_M_av ...
    S_RND_av     E_RND_av     T_RND_av ...
    Eloc_M Tloc_M ...
    elabtimeGA   elabtimeBRA(N);

close all;

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%    
%
%  algorithm 0: Near Cell Association
%
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
for i = 1:M
	RAT(i).n = sum(ratsceltadist(1:N) == i); % assignation of the MD to the nearest RAT
end

for j=1:N
    Str_mindist(j) = Th_K(j,i)/RAT(ratsceltadist(j)).n;
    E_mindist(j)= EnergiapartialOD(RAT(ratsceltadist(j)),MD(j),app(j),CS1);
    T_mindist(j)= TempopartialOD(RAT(ratsceltadist(j)),MD(j),app(j),CS1);
end
% mean values of S E T 
S_mindist_av(N) = mean(Str_mindist(1:N));
E_mindist_av(N) = mean(E_mindist(1:N));
T_mindist_av(N) = mean(T_mindist(1:N));

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%    
%
%  algorithm 1: Throughput Cell Association
%
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

startGA = tic;
% matrix initialization
S = zeros(N,M); % Throughput
ratscelta = zeros(N,1);
Smax = zeros(N,1);

% reset assignation of the MD
for i = 1:M
    RAT(i).n = 0;
end

% Throughput computation for a single device, considering only the previous assignations 
   
for j=1:N  
    %  Throughput computation for the device j
    %  (computed for every RAT)
    cont = 1;
    while cont <= M % for every RAT
        RAT(cont).n = RAT(cont).n + 1; % add a connection to the RAT            
        S(j,cont) = Str(RAT(cont),MD(j)); % computation of Throughput
        cont = cont + 1;
    end
    % find the RAT which maximize the Throughput
    Smax(j) = max(S(j,:));
    % choose the RAT which maximize the Throughput
    ratscelta(j) = find(S(j,:) == Smax(j),1, 'first');
    
    % resetting the not chosen RAT with the right connected number of devices
    for i = 1:M
        if i ~= ratscelta(j)
            RAT(i).n = RAT(i).n - 1;
        end
    end
end


% compute the  S E T for the chosen RATs ratscelta

% number of connected devices for each RAT
for i = 1:M
    RAT(i).n = sum(ratscelta == i);
end
% S E T  computation for a single device, considering the chosen assignations 
for j=1:N
    S_M(j)= Str(RAT(ratscelta(j)),MD(j));
    E_M(j)= EnergiapartialOD(RAT(ratscelta(j)),MD(j),app(j),CS1);
    T_M(j)= TempopartialOD(RAT(ratscelta(j)),MD(j),app(j),CS1); 
end

% mean values of S E T and Utility Functon
S_M_av(N) = mean(S_M(1:N));
E_M_av(N) = mean(E_M(1:N));
T_M_av(N) = mean(T_M(1:N));
elabtimeGA(N) = toc(startGA);
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%
%  Biased Randomization
%
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

startBRA=tic;


% matrix initialization
S2 = zeros(N,M); % Throughput
E2 = zeros(N,M); % Energy
T2 = zeros(N,M); % Time
ratsceltaRND = zeros(N,1);
Sdef = 0;


for w=1:Nloop % number of loops calculating biased randomization
    % setting to 0 the number of connected devices for each RAT
    for i = 1:M
        RAT(i).n = 0;
    end
    for j = 1:N
        %  Throughput computation for the device j
        %  (computed for every RAT)
        cont = 1;
        while cont <= M
            RAT(cont).n = RAT(cont).n + 1;
            S2(j,cont)= Str(RAT(cont),MD(j));
            cont = cont + 1;
        end
        % sorting of the S for the device j
        Ssorted(j,:) = sort(S2(j,:),'descend');
        % choice of a value with geometric distribution
        choice = mod(geoinv(p,rand()),M)+1;
        Schosen(j) = Ssorted(j,choice);
        % which RAT is chosen?
         ratsceltaRND(j) = find(S2(j,:) == Schosen(j),1, 'first');
        % setting of the not chosen RAT with the right connected number of devices
        for i = 1:M
           if i ~= ratsceltaRND(j)
              RAT(i).n = RAT(i).n - 1;
           end
        end
    end  
 
 connected = zeros(1:M);

 for j= 1:N
     connected(ratsceltaRND(j)) = connected(ratsceltaRND(j))+1;
 end
% S E T  computation for a single device, considering the chosen assignations 
for i = 1:M
    RAT(i).n = connected(i);
end
for j=1:N
    if ratsceltaRND(j)== 0
        S_RND(j)= 0;
        E_RND(j)= EnergiaLocale(MD(j),app(j));
        T_RND(j)= TempoLocale(MD(j),app(j));
    else
        S_RND(j)= Str(RAT(ratsceltaRND(j)),MD(j));
        E_RND(j)= EnergiapartialOD(RAT(ratsceltaRND(j)),MD(j),app(j),CS1);
        T_RND(j)= TempopartialOD(RAT(ratsceltaRND(j)),MD(j),app(j),CS1);
    end
end    
%comparing Utility Function with the previous trials
S_media = mean(S_RND(1:N)); 
if Sdef < S_media
        Sdef = S_media;
        ratsceltadef = ratsceltaRND;
    end
    ratsceltaMAT(:,w) = ratsceltaRND;
end


% % compute the  S E T for the chosen RATs ratsceltadef
% for i = 1:M
%     RAT(i).n = sum(ratsceltadef == i);
% end
% % number of connected devices for each RAT
% for j=1:N
%     S_RND(j)= Str(RAT(ratsceltadef(j)),MD(j));
%     E_RND(j)= EnergiapartialOD(RAT(ratsceltadef(j)),MD(j),app(j),CS1);
%     T_RND(j)= TempopartialOD(RAT(ratsceltadef(j)),MD(j),app(j),CS1);
% end
% mean values of S E T and Utility Functon
S_RND_av(N) = mean(S_RND(1:N));
E_RND_av(N) = mean(E_RND(1:N));
T_RND_av(N) = mean(T_RND(1:N));
elabtimeBRA(N) = toc(startBRA);


% number of different choices of RAT with respect to the algorithm 1
diversi = find(ratscelta-ratsceltadef);
dch=length(diversi);

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%
%  Local computation
%
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
for j=1:N
    Eloc(j)= EnergiaLocale(MD(j),app(j));
    Tloc(j)= TempoLocale(MD(j),app(j)); 
end

Eloc_M(N) = mean(Eloc(1:N));
Tloc_M(N) = mean(Tloc(1:N));


% print of results

fprintf(1,'*****************************************************');
fprintf('\n')
fprintf(1,'Results for:  ');
fprintf('\n')
fprintf(1,'Number of devices:  ');
fprintf(1,'\b%d',N); 
fprintf(1,'    p:  ');
fprintf(1,'\b%.2f',p);
fprintf(1,'    Number of loop:  ');
fprintf(1,'\b%d',Nloop); 
fprintf('\n')
fprintf(1,'Different choices:  ');
fprintf('\n')
fprintf(1,'\b%d',dch); 
fprintf('\n')
fprintf(1,'************ Throughput [Kbps] **********');
fprintf('\n')
fprintf(1,'nearest node:                 ');
fprintf(1,'\b%.2f\n',S_mindist_av(N)*1000); 
fprintf('\n')
fprintf(1,'Ref Value:                 ');
S_GA(N) = S_M_av(N)*1000;

fprintf(1,'\b%.2f\n',S_M_av(N)*1000); 
fprintf(1,'Biased Rand Utility:       ');
S_BRA(N) = S_RND_av(N)*1000;

fprintf(1,'\b%.2f\n',S_RND_av(N)*1000); 
if S_M_av(N) < S_RND_av(N)
    fprintf(1,'BETTER:                  ');
elseif S_M_av(N) > S_RND_av(N)
    fprintf(1,'WORSE:                   ');
else
    fprintf(1,'NOT IMPROVED               ');
end
fprintf('\n')
S_p(N) = (S_RND_av(N)-S_M_av(N))*100/S_M_av(N);

fprintf(1,'\b%.2f',(S_RND_av(N)-S_M_av(N))*100/S_M_av(N));
fprintf(1,'%%');
fprintf('\n')

fprintf(1,'************ Energy [mWs]**********');
fprintf('\n')
fprintf(1,'Nearest Node:                 ');
fprintf(1,'\b%.2f\n',E_mindist_av(N)/10^9); 

fprintf('\n')
fprintf(1,'Greedy Algorithm:                ');
E_GA(N)= E_M_av(N)/10^9;

fprintf(1,'\b%.2f\n',E_M_av(N)/10^9); 
fprintf(1,'Biased Rand Algorithm:      ');

E_BRA(N)= E_RND_av(N)/10^9;
fprintf(1,'\b%.2f\n',E_RND_av(N)/10^9); 
if E_M_av(N) < E_RND_av(N)
    fprintf(1,'BRA is WORSE:                   ');
elseif E_M_av(N) > E_RND_av(N) 
    fprintf(1,'BRA is BETTER:                 ');
else
    fprintf(1,'BRA NOT IMPROVES               ');
end
fprintf('\n')

E_p(N) = (E_RND_av(N)-E_M_av(N))*100/E_M_av(N);
fprintf(1,'\b%.2f',E_p(N));
fprintf(1,'%%');
fprintf('\n')
fprintf(1,'Local Computation:      ');
fprintf(1,'\b%.2f\n',Eloc_M(N)/10^9);
fprintf('\n')
fprintf(1,'************ Time [s]**********');
fprintf('\n')
fprintf(1,'Nearest Node:                 ');
fprintf(1,'\b%.2f\n',T_mindist_av(N)/10^9); 

fprintf('\n')
fprintf(1,'Greedy Algorithm:                 ');

T_GA(N) = T_M_av(N)/10^9;
fprintf(1,'\b%.2f\n',T_M_av(N)/10^9); 
fprintf(1,'Biased Rand Algorithm:       ');

T_BRA(N) = T_RND_av(N)/10^9;
fprintf(1,'\b%.2f\n',T_BRA(N));

if T_M_av(N) < T_RND_av(N)
    fprintf(1,'WORSE:                    ');
elseif T_M_av(N) > T_RND_av(N)
    fprintf(1,'BETTER:                   ');
else
    fprintf(1,'NOT IMPROVED               ');
end
fprintf('\n')

T_p(N) = (T_RND_av(N)-T_M_av(N))*100/T_M_av(N);
fprintf(1,'\b%.2f',T_p(N));
fprintf(1,'%%');
fprintf('\n')
fprintf(1,'Local Computation:      ');
fprintf(1,'\b%.2f\n',Tloc_M(N)/10^9);
fprintf('\n')


fprintf(1,'************ Elaboration time **********');
fprintf('\n')

[ho mi se]= sec2hms(elabtimeGA(N));
fprintf(1,'Greedy Algorithm:  \n');
fprintf(1,'ore:  ');
fprintf(1,'\b%d',ho); 
fprintf(1,' min:  ');
fprintf(1,'\b%d',mi); 
fprintf(1,' sec:  ');
fprintf(1,'\b%.2f',se); 
fprintf('\n')
[ho mi se]= sec2hms(elabtimeBRA(N));
fprintf(1,'Biased Rand:  \n');
fprintf(1,'ore:  ');
fprintf(1,'\b%d',ho); 
fprintf(1,' min:  ');
fprintf(1,'\b%d',mi); 
fprintf(1,' sec:  ');
fprintf(1,'\b%.2f',se); 
fprintf('\n')
end
%clearvars -except N p Nloop NMD S_mindist_av E_mindist_av T_mindist_av S_M_av E_M_av T_M_av elabtimeGA S_RND_av E_RND_av T_RND_av(N) elabtimeBRA(N);
figure('Name','Throughput');
loglog(NMD,S_mindist_av(NMD),'-*',NMD,S_M_av(NMD),'-v',NMD,S_RND_av(NMD),'-o')
legend('Nearest Node Algorithm','Gready Heuristic','Biased-randomized Algorithm');
title(['Throughput']);
xlabel(['Mobile Devices [n]']);
ylabel('Throughput [pbs]','interpreter','latex')
grid on;

figure('Name','Energy');
loglog(NMD,E_mindist_av(NMD),'-*',NMD,E_M_av(NMD),'-v',NMD,E_RND_av(NMD),'-o',NMD,Eloc_M(NMD),'-s')
legend('Nearest Node Algorithm','Gready Heuristic','Biased-randomized Algorithm','Local Computation');
title(['Energy']);
xlabel(['Mobile Devices [n]']);
ylabel('Energy []','interpreter','latex')
grid on;

figure('Name','Time');
loglog(NMD,T_mindist_av(NMD),'-*',NMD,T_M_av(NMD),'-v',NMD,T_RND_av(NMD),'-o',NMD,Tloc_M(NMD),'-s')
legend('Nearest Node Algorithm','Gready Heuristic','Biased-randomized Algorithm','Local Computation');
title(['Computation Time']);
xlabel(['Mobile Devices [n]']);
ylabel('Time [s]','interpreter','latex')
grid on;

