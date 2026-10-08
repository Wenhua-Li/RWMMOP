function R = rwmmo_reservoirops_objectives(X, F)
%RWMMO_RESERVOIROPS_OBJECTIVES Vectorised evaluator of the frozen reservoir instance.
%   X is n x (nRes*T) releases (row-major: reservoir 1 periods, reservoir 2
%   periods), F the frozen snapshot struct. Returns raw engineering units:
%     objs(:,1) = downstream flood peak (max over periods of total release
%                 plus lateral inflow)
%     objs(:,2) = negative hydropower sum of head*release
%     cons      = [per reservoir/period storage bound violation (nRes*T),
%                  per reservoir terminal-target violation (nRes)]
%   Storage trajectories are simulated forward; spills are lost water.
n = size(X,1);
nR = F.nRes; T = F.T;
% decision layout is reservoir-major: columns (r-1)*T + t
Rl = permute(reshape(X, n, T, nR), [1 3 2]);      % n x nR x T
S = zeros(n, nR, T+1);
S(:,:,1) = F.S0;
spill = zeros(n, nR, T);
H = zeros(n, nR, T);
for t = 1:T
    Sin = S(:,:,t) + F.inflow(t) - Rl(:,:,t);
    spill(:,:,t) = max(0, Sin - F.Smax);
    S(:,:,t+1) = Sin - spill(:,:,t);
    H(:,:,t) = F.H0 + F.kH * (S(:,:,t) - F.Smin);
end
down = reshape(sum(Rl, 2), n, T) + F.lateral;     % n x T (reshape: squeeze flips n=1)
f1 = max(down, [], 2);
gen = sum(sum(H .* Rl, 3), 2);
f2 = -gen;
sup = max(S(:,:,2:end) - F.Smax, [], 3);
slo = max(F.Smin - S(:,:,2:end), [], 3);
sto = max(sup, slo);                              % n x nR per-period bound viol
term = abs(S(:,:,T+1) - F.Starget) - F.Stol;      % n x nR
R.objs = [f1, f2];
R.cons = [sto, term];
R.feasible = all(R.cons <= 0, 2);
end
