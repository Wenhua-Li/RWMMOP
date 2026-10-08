function R = rwmmo_dnr_ms_evaluate(X, Sc, repaired, objSpec)
%RWMMO_DNR_MS_EVALUATE Evaluate a topology under every frozen scenario.
%   R = rwmmo_dnr_ms_evaluate(X,Sc) evaluates each row of X (branch incidence
%   vectors, repaired to spanning trees unless repaired=true) under every
%   scenario produced by rwmmo_dnr_scenarios, using the validated per-scenario
%   evaluator rwmmo_dnr_objectives and therefore the same backward/forward sweep
%   that is differentially tested against the upstream Newton-Raphson solver.
%
%   Per-scenario quantities are stored as <kind>_<scenario> fields (lossKW_base,
%   VDI_heavy, Vmin_heavy, ...) so a design study can assemble any objective
%   combination without re-solving. R.objs assembles the one frozen combination
%   of the problem class; pass objSpec to assemble a different one, as cells
%   {kind, scenario} with kind in {'lossKW','VDI'} or the scenario-independent
%   {'NSO',''}. Keeping the assembly here is what prevents the class, the
%   reference builder and the audits from drifting apart.
%
%   Constraints are scenario coupled on purpose: a topology is acceptable only
%   when the voltage window holds in every scenario, so c1 is the sum of the
%   per-scenario voltage violations and a diverged power flow in any scenario
%   contributes its collapse violation. The switching objective NSO does not
%   depend on the scenario because all scenarios share the same network and the
%   same initial radial configuration; that is asserted rather than assumed.
if nargin < 3, repaired = false; end
if nargin < 4 || isempty(objSpec)
    % Frozen objective set of RWMMOP12_DNR33MS: economy at the published load
    % level, voltage security at the peak level, and operational switching cost.
    objSpec = {{'lossKW','base'},{'VDI','heavy'},{'NSO',''}};
end
nS = numel(Sc);
assert(nS >= 1, 'RWMMO:DNRMultiScenario', 'No scenarios supplied.');
nT = size(X, 1);
R = struct();
R.nScenario = nS;
R.scenarioNames = {Sc.name};
R.multipliers = [Sc.multiplier];
R.collapsedAny = false(nT, 1);
violTotal = zeros(nT, 1);
violThermalTotal = zeros(nT, 1);
NSOref = [];
for k = 1:nS
    Rk = rwmmo_dnr_objectives(X, Sc(k).F, repaired);
    if k == 1
        R.closed = Rk.closed;
        NSOref = Rk.NSO;
    else
        assert(isequal(Rk.closed, R.closed), 'RWMMO:DNRMultiScenario', ...
            'Scenario %s repaired to a different topology.', Sc(k).name);
        assert(isequal(Rk.NSO, NSOref), 'RWMMO:DNRMultiScenario', ...
            'The switching objective depends on the scenario.');
    end
    R.(['lossKW_' Sc(k).name]) = Rk.lossKW;
    R.(['VDI_' Sc(k).name]) = Rk.VDI;
    R.(['Vmin_' Sc(k).name]) = Rk.Vmin;
    R.(['Vmax_' Sc(k).name]) = max(Rk.Vmag, [], 2);
    R.(['collapsed_' Sc(k).name]) = Rk.collapsed;
    R.(['violV_' Sc(k).name]) = Rk.cons(:,1);
    R.(['violT_' Sc(k).name]) = Rk.cons(:,2);
    R.collapsedAny = R.collapsedAny | Rk.collapsed;
    violTotal = violTotal + Rk.cons(:,1);
    violThermalTotal = violThermalTotal + Rk.cons(:,2);
end
R.NSO = NSOref;
R.violVTotal = violTotal;
R.violThermalTotal = violThermalTotal;
R.cons = [violTotal, violThermalTotal];
R.feasible = (~R.collapsedAny) & (violTotal <= 0);
R.objSpec = objSpec;
R.objs = zeros(nT, numel(objSpec));
for j = 1:numel(objSpec)
    kind = objSpec{j}{1}; scen = objSpec{j}{2};
    if strcmp(kind, 'NSO')
        R.objs(:,j) = NSOref;
    else
        assert(any(strcmp(kind,{'lossKW','VDI'})), 'RWMMO:DNRMultiScenario', 'Unknown objective kind %s.', kind);
        assert(~isempty(scen) && any(strcmp(scen, R.scenarioNames)), ...
            'RWMMO:DNRMultiScenario', 'Objective %d refers to an unknown scenario %s.', j, string(scen));
        R.objs(:,j) = R.([kind '_' scen]);
    end
end
end