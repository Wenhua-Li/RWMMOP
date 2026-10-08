function R = rwmmo_wta_objectives(X, W)
%RWMMO_WTA_OBJECTIVES Evaluate weapon-target assignments in engineering units.
%   X is nX-by-D with D = nT*nW and variable k = (j-1)*nT + i holding x(i,j).
%
%   f1 = -sum_i V_i * (1 - prod_j (1-p_ij)^x_ij)   minimised; more negative is a
%        higher expected retained value
%   f2 = sum_j c_j * sum_i x_ij                    ammunition cost
%   con_i = max(0, sum_j x_ij - salvoMax)          fire-control channel limit
%   Inventory limits are not reported as constraints because rwmmo_wta_repair
%   enforces them by construction; the residual violation is returned as a
%   diagnostic so that any caller can verify the repair actually held.
[nX, D] = size(X);
assert(D == W.D, 'RWMMO:WTADim', 'Expected %d decision variables, got %d.', W.D, D);
assert(all(isfinite(X(:))), 'RWMMO:WTAInput', 'Non-finite decision values.');
Xi = round(X);
assert(all(Xi(:) >= 0), 'RWMMO:WTAInput', 'Negative missile counts.');
Xr = reshape(Xi', W.nT, W.nW, nX);                 % Xr(i,j,t) = x(i,j)
% NB: every reduction below uses reshape rather than squeeze, because a
% single-row input makes Xr two-dimensional (nT-by-nW) and squeeze then
% returns a column where a row is required. MOEA/D evaluates one offspring at
% a time, so nX == 1 is an ordinary call rather than an edge case.
survive = ones(W.nT, nX);
for j = 1:W.nW
    survive = survive .* (1 - W.P(:,j)) .^ reshape(Xr(:,j,:), W.nT, nX);
end
Pkill = (1 - survive)';                            % nX-by-nT
value = Pkill * W.V;
used = reshape(sum(Xr, 1), W.nW, nX)';             % nX-by-nW spent per weapon type
perTarget = reshape(sum(Xr, 2), W.nT, nX)';        % nX-by-nT missiles per target
assert(size(Pkill,1) == nX && size(Pkill,2) == W.nT, 'RWMMO:WTADim', 'Kill probability shape.');
assert(size(used,1) == nX && size(used,2) == W.nW, 'RWMMO:WTADim', 'Expenditure shape.');
assert(size(perTarget,1) == nX && size(perTarget,2) == W.nT, 'RWMMO:WTADim', 'Per-target shape.');
R.objs = [-value, used * W.c'];
R.cons = max(0, perTarget - W.salvoMax);
R.value = value;
R.used = used;
R.perTarget = perTarget;
R.Pkill = Pkill;
R.inventoryViolation = max(0, used - W.q);
R.salvoViolation = sum(R.cons, 2);
end
