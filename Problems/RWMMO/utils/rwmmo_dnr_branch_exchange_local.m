function R = rwmmo_dnr_branch_exchange_local(F, trees, feas, objs, chunkN)
%RWMMO_DNR_BRANCH_EXCHANGE_LOCAL Exact local Pareto certificate by branch exchange.
%   R = rwmmo_dnr_branch_exchange_local(F,trees,feas,objs) decides local Pareto
%   optimality exactly for every feasible row of an exhaustively enumerated
%   topology set. The neighbourhood is the classic distribution-system-operator
%   move: close one open tie line and open one sectionalising branch on the
%   unique cycle that this creates. Only neighbours that are themselves feasible
%   count, and a feasible topology is locally Pareto optimal when no feasible
%   neighbour dominates it. Topologies that are locally but not globally Pareto
%   optimal are the generalised local Pareto front (GLPF).
%
%   This is the shared, problem-independent version of the certificate used by
%   tests/dnr_local_pareto_audit.m for DNR33 旧版（退役）/RWMMOP11. It is verified against those
%   published numbers by tests/dnr_local_helper_crosscheck.m (DNR33: 1375 local
%   rows enumerated, 1364 local-only, 2.8 mean feasible neighbours) before it
%   is used for any new problem, so the two implementations cannot drift apart
%   silently. NOTE (DEC-20260928-064): this helper returns the FULL
%   enumeration; the PUBLISHED *_local_reference.mat archive is the subset
%   that passes the eps=0.3 quality gate (tests/rwmmo_local_quality_filter.m),
%   and the crosscheck compares the gated subset against the archive row for
%   row (DNR33 published: 392 rows / 381 local-only).
%
%   Inputs: F frozen feeder snapshot; trees nTree-by-nBranch incidence vectors
%   (every row a spanning tree); feas nTree-by-1 logical feasibility; objs
%   nTree-by-M objective matrix in raw engineering units. Neighbour lookup uses
%   an exact injective numeric key, split into two double parts when the branch
%   count exceeds 50 so that keys stay exactly representable.
if nargin < 5 || isempty(chunkN), chunkN = 400; end
assert(size(trees,1) == numel(feas) && size(trees,1) == size(objs,1), ...
    'RWMMO:DNRLocal', 'trees/feas/objs must have the same row count.');
assert(size(trees,2) == F.nBranch, 'RWMMO:DNRLocal', 'Branch count mismatch.');
m = F.nBranch;
fidx = find(feas(:));
nLocal = numel(fidx);
assert(nLocal > 0, 'RWMMO:DNRLocal', 'No feasible topology, so no certificate is possible.');
K = localTreeKeys(trees);
ties = find(F.branchIsTie)';
dominatedLocal = false(nLocal,1);
nbrSizes = zeros(nLocal,1);
t0 = tic;
for a = 1:chunkN:nLocal
    b = min(a+chunkN-1, nLocal);
    srcCell = cell(b-a+1,1); nbrCell = cell(b-a+1,1);
    for q = a:b
        tr = trees(fidx(q),:);
        cyc = localFundamentalCycles(F, tr, ties);
        blkAll = zeros(0, m);
        for c = 1:numel(cyc)
            e = cyc{c}.tie; fs = cyc{c}.branches;
            if isempty(fs), continue; end
            blk = repmat(tr, numel(fs), 1);
            blk(:, e) = true;
            for w = 1:numel(fs), blk(w, fs(w)) = false; end %#ok<NASGU>
            blkAll = [blkAll; blk]; %#ok<AGROW>
        end
        if isempty(blkAll), continue; end
        srcCell{q-a+1} = q * ones(size(blkAll,1), 1);
        nbrCell{q-a+1} = blkAll;
    end
    keepCell = ~cellfun(@isempty, nbrCell);
    if ~any(keepCell), continue; end
    srcRows = cell2mat(srcCell(keepCell));
    nbrRows = cell2mat(nbrCell(keepCell));
    [~, loc] = ismember(localTreeKeys(nbrRows), K, 'rows');
    assert(all(loc > 0), 'RWMMO:DNRLocal', 'A neighbour is not an enumerated spanning tree.');
    ok = feas(loc);
    srcRows = srcRows(ok); loc = loc(ok);
    for q = a:b
        s = srcRows == q;
        nbrSizes(q) = nnz(s);
        if ~any(s), continue; end
        O = objs(loc(s),:);
        Oi = repmat(objs(fidx(q),:), nnz(s), 1);
        dominatedLocal(q) = any(all(O <= Oi, 2) & any(O < Oi, 2));
    end
end
R.feasibleRows = fidx;
R.localMask = ~dominatedLocal;
R.localRows = fidx(~dominatedLocal);
R.nbrSizes = nbrSizes;
R.meanNbr = mean(nbrSizes);
R.maxNbr = max(nbrSizes);
R.seconds = toc(t0);
end
function K = localTreeKeys(T)
% Exact injective numeric key for a branch incidence vector (two double parts).
m = size(T,2);
p = min(m, 50);
K1 = double(T(:,1:p)) * (2.^(0:p-1))';
if m > p
    K2 = double(T(:,p+1:m)) * (2.^(0:m-p-1))';
else
    K2 = zeros(size(K1));
end
K = [K1, K2];
end
function cyc = localFundamentalCycles(F, tree, ties)
% For every open tie line, list the tree branches on the unique cycle it creates.
n = F.nbus;
idx = find(tree);
hd = -ones(n,1); nx = zeros(2*(n-1),1); tn = nx; br = nx;
c = 0;
for e = idx
    c = c + 1; nx(c) = hd(F.branchFrom(e)); hd(F.branchFrom(e)) = c; tn(c) = F.branchTo(e); br(c) = e;
    c = c + 1; nx(c) = hd(F.branchTo(e)); hd(F.branchTo(e)) = c; tn(c) = F.branchFrom(e); br(c) = e;
end
par = zeros(n,1); pb = zeros(n,1); dep = zeros(n,1); vis = false(n,1);
vis(F.slack) = true; q = zeros(n,1); q(1) = F.slack; h = 1; qt = 1;
while h <= qt
    u = q(h); h = h + 1; p = hd(u);
    while p > 0
        v = tn(p);
        if ~vis(v)
            vis(v) = true; par(v) = u; pb(v) = br(p); dep(v) = dep(u) + 1;
            qt = qt + 1; q(qt) = v;
        end
        p = nx(p);
    end
end
assert(all(vis), 'RWMMO:DNRLocal', 'Topology is not spanning.');
cyc = cell(0);
for e = ties
    if tree(e), continue; end
    u = F.branchFrom(e); v = F.branchTo(e);
    path = zeros(1,0);
    while dep(u) > dep(v), path(end+1) = pb(u); u = par(u); end %#ok<AGROW>
    while dep(v) > dep(u), path(end+1) = pb(v); v = par(v); end %#ok<AGROW>
    while u ~= v
        path(end+1) = pb(u); u = par(u); %#ok<AGROW>
        path(end+1) = pb(v); v = par(v); %#ok<AGROW>
    end
    cyc{end+1} = struct('tie',e,'branches',unique(path)); %#ok<AGROW>
end
end