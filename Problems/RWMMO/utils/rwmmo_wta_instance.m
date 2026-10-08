function W = rwmmo_wta_instance(name)
%RWMMO_WTA_INSTANCE Fixed weapon-target assignment instance.
%   W = rwmmo_wta_instance('WTA66') returns the frozen 6-target, 6-weapon-type
%   instance used by RWMMOP9_WTA66.
%
%   Model (classic static WTA, standard in the defence resource-allocation
%   literature; see e.g. Z. J. Lee et al. 2003 and V. K. Ahuja et al. 2007):
%     x(i,j) = number of missiles of weapon type j assigned to target i
%     P_i(X) = 1 - prod_j (1 - p(i,j))^x(i,j)      interception probability
%     maximise sum_i V_i * P_i(X)                  expected retained value
%     minimise sum_j c_j * sum_i x(i,j)            ammunition cost
%     subject to sum_i x(i,j) <= q_j               inventory per weapon type
%              and 0 <= x(i,j) <= q_j, integer
%
%   p(i,j) = 0 encodes an engagement-envelope exclusion: that weapon type
%   cannot reach that target. Weapon types 3/4 and 5/6 are twin batches with
%   identical kill probability and identical unit cost, which is the realistic
%   source of exactly equivalent assignment plans and therefore of equivalent
%   multimodality. The WTA44/WTA33 instances were retired 2026-09-28 with
%   their classes (their frozen instances live in the archive); this helper
%   now carries only the official WTA66 instance.
switch upper(name)
    case 'WTA66'
        W.name = 'WTA66';
        W.nT = 6;                                   % targets
        W.nW = 6;                                   % weapon types
        W.V  = [12; 10; 9; 8; 7; 6];                % threat value per target
        W.q  = [4 4 6 6 8 8];                       % inventory per weapon type
        W.c  = [6 4 2 2 1 1];                       % unit engagement cost
        W.P  = [0.85 0.60 0.00 0.00 0.00 0.00;      % target 1 x weapon types
                0.80 0.65 0.00 0.00 0.30 0.30;
                0.75 0.70 0.55 0.55 0.45 0.45;
                0.70 0.65 0.60 0.60 0.50 0.50;
                0.65 0.60 0.65 0.65 0.55 0.55;
                0.60 0.55 0.60 0.60 0.50 0.50];
        % Fire-control / doctrine limit on simultaneous engagements of one
        % target. Inventory limits are enforced by the repair map, so this is
        % the constraint that actually shapes the feasible region. The cap of
        % five channels against a total inventory of 36 missiles is what keeps
        % saturated allocations infeasible and the salvo-aware front nontrivial.
        W.salvoMax = 5;
        W.weaponRole = {'long-range','medium-range SAM','short-range batch A', ...
            'short-range batch B','loitering batch A','loitering batch B'};
        W.envelopeExclusions = {[1 3],[1 4],[2 3],[2 4],[1 5],[1 6]};  % [target, weapon] pairs with p=0
        % Weapon types 3/4 and 5/6 are two pairs of twin batches (identical kill
        % probability column and unit cost), the structural source of exactly
        % equivalent assignment plans. The twin equivalence class of one
        % allocation is huge (per-target redistribution between the twin
        % columns), so unlike WTA44 the feasible set cannot be enumerated and
        % the reference is high-budget-approx (DEC-20260923-061); the exact
        % product below overflows meaningful double precision, hence the
        % uint64 companion value.
        W.twinPairs = [3 4; 5 6];
        W.nFeasibleExact = uint64(210) * 210 * 924 * 924 * 3003 * 3003;
    otherwise
        error('RWMMO:UnknownInstance','Unknown WTA instance %s.', name);
end
assert(all(size(W.P) == [W.nT W.nW]), 'RWMMO:WTAShape', 'Kill probability matrix shape.');
assert(all(W.P(:) >= 0 & W.P(:) <= 1), 'RWMMO:WTAData', 'Kill probabilities outside [0,1].');
assert(numel(W.q) == W.nW && numel(W.c) == W.nW && numel(W.V) == W.nT, 'RWMMO:WTAShape', 'Vector lengths.');
assert(all(W.q > 0) && all(W.c > 0) && all(W.V > 0), 'RWMMO:WTAData', 'Non-positive instance data.');
W.D = W.nT * W.nW;
W.lower = zeros(1, W.D);
W.upper = repelem(W.q, W.nT);        % variable k = (j-1)*nT + i is x(i,j)
W.maxValue = sum(W.V);               % best attainable expected value
W.maxCost = sum(W.c .* W.q);         % most expensive full expenditure
% Number of feasible allocations, as the product over weapon types of the
% number of ways to spend at most q_j missiles over nT targets.
cnt = arrayfun(@(qq) size(rwmmo_wta_compositions(W.nT, qq), 1), W.q);
W.perTypeFeasible = cnt;
W.nFeasible = prod(cnt);
W.spaceSize = prod(W.upper + 1);
% Objective scale derived from the instance alone, not from any archive, so the
% normalisation constants cannot drift when the reference is improved.
%   f1 in [-maxValue, 0]  (0 means nothing intercepted)
%   f2 in [0, maxCost]    (full expenditure of every inventory)
W.objLo = [-W.maxValue, 0];
W.objHi = [0, W.maxCost];
W.M = 2;
W.source = 'classic static WTA model; instance parameters frozen by this project';
end