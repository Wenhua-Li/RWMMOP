function quickstart()
%QUICKSTART  Verify an RWMMO + PlatEMO installation in one run.
%
%   1. Set PLATEMO_ROOT below to your PlatEMO folder (or export the
%      environment variable RWMMO_PLATEMO before starting MATLAB).
%   2. Run this file. For each of three showcase problems it
%        - builds a problem object (which loads the frozen data snapshot and
%          the certified reference archive shipped in this repository),
%        - evaluates a random initial population,
%        - prints the feasible fraction and the objective ranges,
%        - saves a figure comparing the feasible samples with the reference
%          Pareto front to the system temporary folder.
%
%   Requirements: MATLAB R2020b or newer, PlatEMO v4.x, this repository.
%   Validated with MATLAB R2025b and PlatEMO v4.16.

PLATEMO_ROOT = getenv('RWMMO_PLATEMO');
if isempty(PLATEMO_ROOT)
    PLATEMO_ROOT = 'C:/PlatEMO'; %#ok<NASGU>  % <-- EDIT: your PlatEMO folder
end
assert(isfolder(PLATEMO_ROOT), ...
    'PlatEMO not found at "%s". Edit PLATEMO_ROOT in quickstart.m.', PLATEMO_ROOT);

here = fileparts(mfilename('fullpath'));
addpath(genpath(PLATEMO_ROOT));
% Add the RWMMO problems AFTER PlatEMO so that this repository's copy wins
% even if PlatEMO already contains an older RWMMO folder.
addpath(genpath(fullfile(here,'..','Problems')));

showcase = { ...
    'RWMMOP8_Knapsack24', 200;  % exact reference, 27-fold exact tie groups (EM)
    'RWMMOP15_SiteSelect',  200;  % certified-dense, 958 mirror-equivalent optima (MIX)
    'RWMMOP11_DNR69',       100}; % exact reference, IEEE 69-bus feeder, M = 3 (GLPF)

fprintf('RWMMO quickstart\n');
for i = 1:size(showcase,1)
    name = showcase{i,1};
    N    = showcase{i,2};
    rng(20261002,'twister');
    pro  = feval(name,'N',N,'maxFE',10*N);

    fprintf('=== %s (D = %d, M = %d) ===\n', name, pro.D, pro.M);
    P    = pro.Initialization(N);
    Con  = P.cons;
    Obj  = P.objs;
    feas = all(Con <= 0, 2);
    fprintf('reference archive : %d rows\n', size(pro.PF,1));
    fprintf('sampled solutions : %d, feasible %d (%.1f%%)\n', N, sum(feas), 100*mean(feas));
    fprintf('objective ranges  :');
    for j = 1:pro.M
        fprintf('  f%d in [%g, %g]', j, min(Obj(:,j)), max(Obj(:,j)));
    end
    fprintf('\n');

    f = figure('Visible','off','Color','w');
    if pro.M == 2
        plot(pro.PF(:,1), pro.PF(:,2), '.', 'Color', [0 .45 .74], 'MarkerSize', 9);
        hold on;
        scatter(Obj(feas,1), Obj(feas,2), 22, [.85 .33 .10], 'filled');
        xlabel('f_1 (normalised)'); ylabel('f_2 (normalised)');
    else
        scatter3(pro.PF(:,1), pro.PF(:,2), pro.PF(:,3), 14, [0 .45 .74], 'filled');
        hold on;
        scatter3(Obj(feas,1), Obj(feas,2), Obj(feas,3), 26, [.85 .33 .10], 'filled');
        xlabel('f_1 (normalised)'); ylabel('f_2 (normalised)'); zlabel('f_3 (normalised)');
        view(135,25);
    end
    title(name, 'Interpreter', 'none');
    legend({'reference front', 'feasible samples'}, 'Location', 'best');
    out = fullfile(tempdir, ['rwmmo_quickstart_', name, '.png']);
    exportgraphics(f, out, 'Resolution', 130);
    close(f);
    fprintf('figure saved     : %s\n\n', out);
end

% Direct access to a reference archive file (decisions + objectives + scale):
S = load(fullfile(here, '..', 'Problems', 'RWMMO', 'ref_pf_ps', 'RWMMOP8_Knapsack24_reference.mat'));
fprintf('RWMMOP8_Knapsack24_reference.mat fields: %s\n', strjoin(fieldnames(S)', ', '));
fprintf('PS_ref is %s, PF_ref is %s\n', mat2str(size(S.PS_ref)), mat2str(size(S.PF_ref)));

% Run one full algorithm to see the PlatEMO toolchain in action (uncomment):
% [PopDec,PopObj,PopCon] = platemo('algorithm',@NSGAII, ...
%     'problem',@RWMMOP8_Knapsack24,'N',100,'maxFE',20000);

fprintf('\nInstallation verified.\n');
end
