function R = rwmmo_arraynull_objectives(X, G)
%RWMMO_ARRAYNULL_OBJECTIVES Shared evaluator for RWMMOP4_ArrayNull (RWMMOP4).
%   X is an N x 8 matrix of element amplitudes (already inside the box; the
%   class clips in CalDec before calling this). Returns the raw objectives
%   [peak sidelobe level dB, worst null-depth error dB], no constraints,
%   and the feasibility flag (always true - the box is the only limit).
%   Row-wise arithmetic only, no matrix products: BLAS reductions depend on
%   the batch shape, and a 1 x 8 call must produce bit-identical values to
%   the same row inside an N x 8 call (the single-row path MOEA/D uses).
X = double(X);
n = size(X,1);
th = 0:G.gridStep:180;
u = cos(deg2rad(th));
E = exp(1j * pi * (0:G.N-1).' * u);              % 8 x T steering rows
P = sum(reshape(X, n, G.N, 1) .* reshape(E, 1, G.N, numel(th)), 2);   % n x T
p = abs(P) ./ sum(X, 2);
pDB = 20 * log10(max(p, 1e-12));
side = abs(th - 90) > G.mainlobeHalfWidth;
e1 = pDBat(X, G, G.nullTheta(1));
e2 = pDBat(X, G, G.nullTheta(2));
R.objs = [max(pDB(:, side), [], 2), max(abs(e1 - G.nullTargetDB), abs(e2 - G.nullTargetDB))];
R.cons = zeros(n,0);
R.feasible = true(n,1);
end

function v = pDBat(X, G, thetaDeg)
%Pattern level in dB at one exact angle, row-wise.
u = cos(deg2rad(thetaDeg));
E = exp(1j * pi * (0:G.N-1).' * u).';           % 1 x 8
P = sum(X .* E, 2);
v = 20 * log10(max(abs(P) ./ sum(X, 2), 1e-12));
end
