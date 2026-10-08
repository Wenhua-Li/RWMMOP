function Y = rwmmo_wta_repair(X, W)
%RWMMO_WTA_REPAIR Project allocations onto the inventory-feasible set.
%   Each weapon type's allocation is reduced, deterministically from the last
%   target backwards, until it respects its inventory q_j. The map is idempotent
%   and every inventory-feasible allocation is a fixed point, so the repair
%   never hides a feasible solution and the effective decision space is exactly
%   the feasible set. Rounding and bound clipping come first, which also makes
%   the map well defined on the continuous offspring of real-coded operators.
Y = min(repmat(W.upper, size(X,1), 1), max(repmat(W.lower, size(X,1), 1), round(X)));
nX = size(Y,1);
Yr = reshape(Y', W.nT, W.nW, nX);
for j = 1:W.nW
    col = reshape(Yr(:,j,:), W.nT, nX)';         % nX-by-nT (reshape, not squeeze: nX may be 1)
    tot = sum(col, 2);
    bad = find(tot > W.q(j));
    for t = bad'
        e = tot(t) - W.q(j);
        for i = W.nT:-1:1
            if e == 0, break; end
            take = min(col(t,i), e);
            col(t,i) = col(t,i) - take;
            e = e - take;
        end
        assert(e == 0, 'RWMMO:WTARepair', 'Inventory %d cannot absorb the allocation.', j);
    end
    Yr(:,j,:) = col';
end
Y = reshape(Yr, W.nT*W.nW, nX)';
end
