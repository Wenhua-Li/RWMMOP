function [Xr, R] = rwmmo_ecodispatch15_repair(X, G)
%RWMMO_ECODISPATCH15_REPAIR Clip to the box and repair the power balance (RWMMOP7).
%   Same deterministic largest-head-room-first repair as EcoDispatch6（退役）, generalised to
%   fifteen units, with the multi-fuel piecewise cost in the objective:
%   below the fuel-switch point Ps_u the (a1,b1,c1) quadratic applies, above
%   it (a2,b2,c2), continuous at Ps_u by construction; valve-point units add
%   e_u |sin(fv_u (P_u - Pmin_u))|.
X = double(X);
n = size(X,1);
Xr = min(max(X, G.lower), G.upper);
for k = 1:n
    room = G.upper - Xr(k,:);
    slot = G.lower - Xr(k,:);
    delta = G.D - sum(Xr(k,:), 2);
    for it = 1:8
        if abs(delta) < 1e-9, break; end
        if delta > 0
            cap = room; cap(cap <= 0) = 0;
            tot = sum(cap);
            if tot <= 0, break; end
            step = min(delta, tot);
            Xr(k,:) = Xr(k,:) + step * cap / tot;
        else
            cap = -slot; cap(cap <= 0) = 0;
            tot = sum(cap);
            if tot <= 0, break; end
            step = min(-delta, tot);
            Xr(k,:) = Xr(k,:) - step * cap / tot;
        end
        Xr(k,:) = min(max(Xr(k,:), G.lower), G.upper);
        delta = G.D - sum(Xr(k,:), 2);
    end
end
R.objs = [fuelCost(Xr, G), ...
          sum(Xr.^2 .* G.alpha + Xr .* G.beta, 2) + sum(G.gamma)];
R.cons = abs(sum(Xr, 2) - G.D) - 1e-9;
R.feasible = R.cons <= 0;
end

function v = fuelCost(X, G)
lo = X <= G.Ps;
v1 = X.^2 .* G.a1 + X .* G.b1 + G.c1;
v2 = X.^2 .* G.a2 + X .* G.b2 + G.c2;
v = sum(lo .* v1 + ~lo .* v2, 2) + valveSum(X, G);
end

function v = valveSum(X, G)
v = sum(G.e .* abs(sin(G.fv .* (X - G.lower))), 2);
end
