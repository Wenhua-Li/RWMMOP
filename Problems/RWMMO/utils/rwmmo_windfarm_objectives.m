function R = rwmmo_windfarm_objectives(X, F)
%RWMMO_WINDFARM_OBJECTIVES Vectorised evaluator of the frozen wind-farm instance.
%   X is n x 2N turbine coordinates in km (pairs x_i y_i), F the frozen
%   snapshot struct from windfarm_instance. Returns raw engineering units:
%     objs(:,1) = negative annual energy production [MWh]
%     objs(:,2) = collection cable length [km] (MST over turbines+substation)
%     cons      = [site clearance violation, spacing violation,
%                  zone-1 violation, zone-2 violation]  (all <= 0 feasible)
%   Jensen/Park wake with root-sum-square superposition; generic cubic power
%   curve. The permutation invariance over the N turbine pairs is structural:
%   every aggregate here (sum, MST, max) ignores pair order.
n = size(X,1);
N = F.N;
Px = X(:,1:2:end); Py = X(:,2:2:end);          % n x N
% ---- constraints ---------------------------------------------------------------
E = F.sitePolygon; mE = size(E,1);
clearIn = inf(n,N);
for e = 1:mE
    v = E(e,:); w = E(mod(e,mE)+1,:); ed = w - v;
    cr = ed(1)*(Py - v(2)) - ed(2)*(Px - v(1));   % convex CCW: positive inside
    clearIn = min(clearIn, cr);
end
violBound = -min(clearIn, [], 2);
DX = zeros(n,N,N); DY = zeros(n,N,N);
for i = 1:N
    DX(:,i,:) = Px(:,i) - Px;                     % n x 1 x N broadcast
    DY(:,i,:) = Py(:,i) - Py;
end
Dpair = sqrt(DX.^2 + DY.^2);
Dpair(:,logical(eye(N))) = inf;
violSpacing = max(F.minSpacing - min(Dpair,[],3), [], 2);
violZone = zeros(n,size(F.exclCenters,1));
for k = 1:size(F.exclCenters,1)
    dz = sqrt((Px - F.exclCenters(k,1)).^2 + (Py - F.exclCenters(k,2)).^2);
    violZone(:,k) = max(F.exclRadii(k) - dz, [], 2);
end
cons = [violBound, violSpacing, violZone];
% ---- annual energy production ----------------------------------------------------
AEP = zeros(n,1);
ct = 1 - sqrt(1 - F.thrustCt);
for s = 1:numel(F.windFreq)
    t = [cosd(F.windDirDeg(s)+180), sind(F.windDirDeg(s)+180)];   % travel direction
    along = DX*t(1) + DY*t(2);                  % n x N x N, i downstream of j
    lat = sqrt(max(DX.^2 + DY.^2 - along.^2, 0));
    rw = F.rotorRadius + F.wakeDecay*max(along,0);
    infl = (along > 0) & (lat < rw);
    delta = ct * (F.rotorRadius./rw).^2 .* infl;
    sumsq = sum(delta.^2, 3);                   % n x N
    v = F.windSpeed(s) * (1 - sqrt(sumsq));
    v = max(v, 0);
    AEP = AEP + F.windFreq(s) * F.hours * sum(windfarm_power(v, F), 2);
end
% ---- collection cable: MST over turbines + substation (Prim) ----------------------
cable = zeros(n,1);
nodes = zeros(n, N+1, 2);
nodes(:,1:N,1) = Px;
nodes(:,1:N,2) = Py;
nodes(:,N+1,1) = F.substation(1);
nodes(:,N+1,2) = F.substation(2);
for a = 1:n
    Da = squeeze(sqrt((nodes(a,:,1) - nodes(a,:,1)').^2 + (nodes(a,:,2) - nodes(a,:,2)').^2));
    cable(a) = primMST(Da);
end
R.objs = [-AEP, cable];
R.cons = cons;
R.feasible = all(cons <= 0, 2);
end

function p = windfarm_power(v, F)
p = zeros(size(v));
mR = v >= F.rated & v <= F.cutOut;
p(mR) = F.ratedMW;
mC = v >= F.cutIn & v < F.rated;
p(mC) = F.ratedMW * (v(mC).^3 - F.cutIn^3) / (F.rated^3 - F.cutIn^3);
end

function w = primMST(D)
%Prim on a dense distance matrix; O(V^2), deterministic.
V = size(D,1);
inTree = false(V,1); inTree(1) = true;
best = D(1,:);
w = 0;
for k = 2:V
    cand = best; cand(inTree) = inf;
    [bv, bi] = min(cand);
    w = w + bv;
    inTree(bi) = true;
    best = min(best, D(bi,:));
end
end
