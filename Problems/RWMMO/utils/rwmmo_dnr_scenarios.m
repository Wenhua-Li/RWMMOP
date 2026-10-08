function S = rwmmo_dnr_scenarios(F, varargin)
%RWMMO_DNR_SCENARIOS Frozen operating scenarios of a radial test feeder.
%   S = rwmmo_dnr_scenarios(F) returns the scenario variants of the frozen feeder
%   snapshot F. A scenario is the same network at a uniformly scaled constant-PQ
%   load level, which is how multi-period feeder studies express base and peak
%   operation without inventing per-bus data: the published spatial distribution
%   of the test feeder is preserved exactly and only the level changes.
%
%   S = rwmmo_dnr_scenarios(F,'VminLim',0.90) overrides the lower voltage bound
%   for every scenario. The multi-scenario problem needs this because the peak
%   level is a genuine stress: measured over all 50751 spanning trees of the
%   IEEE 33-bus feeder, the best achievable minimum voltage is 0.92237 pu at
%   1.3x, 0.91591 pu at 1.4x and 0.90937 pu at 1.5x, so the [0.93, 1.05] pu
%   planning window inherited from the single-period problems leaves an EMPTY
%   feasible set at 1.2x and above. The window used here is the ANSI C84.1
%   Range B utilisation band [0.90, 1.05] pu. The full grid is recorded in
%   results/dnr/multiscenario_level_sweep.csv.
%
%   Two levels are frozen: base 1.0 (the published snapshot) and heavy 1.3
%   (peak stress). A light 0.6 level was measured and dropped: 24340 topologies
%   satisfy the window at 0.6x versus 11394 at 1.0x and 3852 at 1.3x, so the
%   light level never excludes a topology that the peak level admits and would
%   only add a power-flow pass.
%
%   Each variant recomputes baseLossKW / baseVmin / baseVDI / lossPenalty /
%   vdiPenalty from its own initial radial configuration, so a diverged power
%   flow stays strictly dominated in the scenario where it occurs, and inherits
%   the branch tables and the initial configuration from F unchanged.
assert(isfield(F,'busP') && isfield(F,'initialClosed'), 'RWMMO:DNRScenario', 'Not a frozen feeder snapshot.');
vminLim = F.VminLim;
k = 1;
while k <= numel(varargin)
    switch lower(string(varargin{k}))
        case 'vminlim', vminLim = varargin{k+1};
        otherwise, error('RWMMO:DNRScenario','Unknown option %s.', string(varargin{k}));
    end
    k = k + 2;
end
assert(vminLim < F.VmaxLim, 'RWMMO:DNRScenario', 'Degenerate voltage window.');
levels  = [1.0, 1.3];
names   = {'base','heavy'};
purpose = {'the published snapshot, unchanged', ...
           'peak stress, decides voltage feasibility'};
S = repmat(struct('name','','purpose','','multiplier',NaN,'F',[]), numel(levels), 1);
for i = 1:numel(levels)
    G = F;
    G.name = [F.name '_' names{i}];
    G.loadMultiplier = levels(i);
    G.busP = F.busP * levels(i);
    G.busQ = F.busQ * levels(i);
    G.VminLim = vminLim;
    b = rwmmo_dnr_powerflow(G, G.initialClosed');
    assert(b.converged, 'RWMMO:DNRScenario', ...
        'The initial radial configuration does not converge at load level %.2f.', levels(i));
    G.baseLossKW = b.lossKW;
    G.baseVmin = b.Vmin;
    G.baseVDI = b.VDI;
    G.lossPenalty = 10 * b.lossKW;
    G.vdiPenalty = 10 * b.VDI;
    S(i).name = names{i};
    S(i).purpose = purpose{i};
    S(i).multiplier = levels(i);
    S(i).F = G;
end
end