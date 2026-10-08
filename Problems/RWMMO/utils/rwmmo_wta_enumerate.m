function X = rwmmo_wta_enumerate(W)
%RWMMO_WTA_ENUMERATE Every feasible assignment of a frozen WTA instance.
%   The feasible set is the Cartesian product of the per-weapon-type allocation
%   sets (all vectors in [0,q_j]^nT summing to at most q_j), so it can be listed
%   exhaustively. The row count is cross-checked against the product of the
%   per-type counts, and every row is verified to respect its inventory.
Cj = cell(1, W.nW);
counts = zeros(1, W.nW);
for j = 1:W.nW
    Cj{j} = rwmmo_wta_compositions(W.nT, W.q(j));
    counts(j) = size(Cj{j}, 1);
end
total = prod(counts);
assert(total == W.nFeasible, 'RWMMO:WTAEnum', ...
    'Closed-form feasible count %d disagrees with the per-type product %d.', W.nFeasible, total);
X = zeros(total, W.D);
rep = 1;
for j = 1:W.nW
    nc = counts(j);
    blk = repelem(Cj{j}, rep, 1);
    blk = repmat(blk, total / (nc * rep), 1);
    base = (j - 1) * W.nT;
    X(:, base+1 : base+W.nT) = blk;
    rep = rep * nc;
end
assert(size(X,1) == total, 'RWMMO:WTAEnum', 'Enumeration produced %d rows.', size(X,1));
nq = size(unique(X,'rows'), 1);
assert(nq == total, 'RWMMO:WTAEnum', ...
    'Cartesian product collapsed to %d distinct allocations out of %d rows.', nq, total);
Xr = reshape(X', W.nT, W.nW, total);
used = squeeze(sum(Xr, 1))';
for j = 1:W.nW
    assert(all(used(:,j) <= W.q(j)), 'RWMMO:WTAEnum', 'Weapon type %d exceeds its inventory.', j);
end
assert(all(all(X >= 0)) && all(all(X == round(X))), 'RWMMO:WTAEnum', 'Non-integer or negative allocation.');
end
