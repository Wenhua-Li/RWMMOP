function Y = rwmmo_dnr_repair(X, from, to, n)
%RWMMO_DNR_REPAIR Kruskal repair of switch states into a radial topology.
%   Y = rwmmo_dnr_repair(X,from,to,n) maps each row of X to the incidence
%   vector of a spanning tree of the feeder graph. Closed branches (nonzero
%   entries) are preferred in ascending branch order, then open branches are
%   added in ascending order until n-1 branches form a tree. The map is
%   idempotent, and it is surjective onto all spanning trees because a
%   vector that already encodes a tree is returned unchanged. Every
%   evaluated solution is therefore a valid radial configuration, and the
%   effective decision space is exactly the set of spanning trees.
[nT, m] = size(X);
assert(m == numel(from), 'RWMMO:DNRRepair', 'Branch count mismatch.');
Y = false(nT, m);
for t = 1:nT
    b = (X(t,:) ~= 0);
    idx = [find(b), find(~b)];
    pf = 1:n; cnt = 0;
    for k = 1:m
        e = idx(k);
        a = localFind(pf, from(e)); c = localFind(pf, to(e));
        if a ~= c
            pf(a) = c; cnt = cnt + 1; Y(t, e) = true;
            if cnt == n - 1, break; end
        end
    end
    assert(cnt == n - 1, 'RWMMO:DNRRepair', 'Feeder graph is not connected.');
end
end
function r = localFind(pf, x)
r = x;
while pf(r) ~= r, r = pf(r); end
end
