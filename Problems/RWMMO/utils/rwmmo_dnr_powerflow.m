function S = rwmmo_dnr_powerflow(F, closed)
%RWMMO_DNR_POWERFLOW Backward/forward sweep for radial feeder topologies.
%   S = rwmmo_dnr_powerflow(F,closed) solves the constant-power-load power
%   flow of every row of `closed` (nTree x nBranch branch incidence vectors
%   that must form spanning trees of F). Loads are constant PQ, matching the
%   c=[1 0 0], d=[1 0 0] composite load model of the source Newton-Raphson
%   implementation. All returned quantities are in physical units:
%   lossKW in kW, branchMVA in MVA, Vmag/Vmin in pu.
[nT, m] = size(closed);
n = F.nbus;
assert(m == F.nBranch, 'RWMMO:DNRDimension', 'Branch count mismatch.');
Z = F.branchR + 1i*F.branchX;
Sload = F.busP + 1i*F.busQ;
Vmag = nan(nT, n);
lossKW = nan(nT, 1);
VDI = nan(nT, 1);
Vmin = nan(nT, 1);
% An open branch carries no power, so its loading is exactly zero; keeping NaN
% here would propagate into the thermal constraint and mark every topology
% infeasible.
branchMVA = zeros(nT, m);
converged = false(nT, 1);
bf = F.branchFrom; bt = F.branchTo;
for t = 1:nT
    idx = find(closed(t,:));
    if numel(idx) ~= n - 1, continue; end
    % Forward-star adjacency of the selected tree.
    hd = -ones(n, 1); nx = zeros(2*(n-1), 1); tn = nx; br = nx;
    c = 0;
    for e = idx
        c = c + 1; nx(c) = hd(bf(e)); hd(bf(e)) = c; tn(c) = bt(e); br(c) = e;
        c = c + 1; nx(c) = hd(bt(e)); hd(bt(e)) = c; tn(c) = bf(e); br(c) = e;
    end
    par = zeros(n, 1); pb = zeros(n, 1); vis = false(n, 1); vis(F.slack) = true;
    ord = zeros(n-1, 1); k = 0; q = zeros(n, 1); q(1) = F.slack; h = 1; qt = 1;
    while h <= qt
        u = q(h); h = h + 1; p = hd(u);
        while p > 0
            v = tn(p);
            if ~vis(v)
                vis(v) = true; par(v) = u; pb(v) = br(p);
                k = k + 1; ord(k) = v; qt = qt + 1; q(qt) = v;
            end
            p = nx(p);
        end
    end
    if ~all(vis), continue; end
    Vv = ones(n, 1);
    ok = false;
    for it = 1:300
        I = conj(Sload ./ Vv);
        for i = (n-1):-1:1
            v = ord(i); I(par(v)) = I(par(v)) + I(v);
        end
        Vn = Vv;
        for i = 1:n-1
            v = ord(i); Vn(v) = Vn(par(v)) - Z(pb(v)) * I(v);
        end
        d = max(abs(Vn - Vv)); Vv = Vn;
        if d < 1e-11, ok = true; break; end
    end
    if ~ok, continue; end
    I = conj(Sload ./ Vv);
    for i = (n-1):-1:1
        v = ord(i); I(par(v)) = I(par(v)) + I(v);
    end
    vm = abs(Vv);
    Vmag(t,:) = vm';
    Vmin(t) = min(vm);
    VDI(t) = sum((1 - vm).^2);
    lossKW(t) = sum(F.branchR(pb(ord)) .* abs(I(ord)).^2) * F.Sbase * 1000;
    branchMVA(t, pb(ord)) = abs(Vv(par(ord)) .* conj(I(ord))) * F.Sbase;
    converged(t) = true;
end
S.Vmag = Vmag; S.Vmin = Vmin; S.VDI = VDI; S.lossKW = lossKW;
S.branchMVA = branchMVA; S.converged = converged;
end
