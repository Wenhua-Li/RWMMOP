classdef RWMMOP12_DNR33MS < PROBLEM
% <2026> <multi> <binary> <constrained> <multimodal>
% Multi-scenario radial distribution network reconfiguration on the frozen IEEE
% 33-bus test feeder.
%
%   Decision    : one binary state per branch (37 sectionalising and tie
%                 switches), repaired to a spanning tree by Kruskal preference so
%                 that every evaluated solution is a valid radial configuration.
%                 One topology must serve every operating scenario, which is the
%                 day-ahead reconfiguration decision a distribution operator
%                 actually takes.
%   Scenarios   : the published load level (base, x1.0) and a peak stress
%                 (heavy, x1.3), both constant-PQ uniform scalings of the frozen
%                 snapshot, so no per-bus data is invented. See
%                 rwmmo_dnr_scenarios.m for why the light level was measured and
%                 dropped and why the peak level forces a wider voltage band.
%   Objectives  : [1] active power loss at the base level [kW]  (economy)
%                 [2] voltage deviation index at the peak level [pu^2] (security)
%                 [3] switching operations against the initial configuration
%                 CalObj returns these mapped affinely onto the exact Pareto
%                 range; CalObjRaw returns engineering units. The positive affine
%                 map preserves dominance and the Pareto set exactly.
%   Constraints : bus voltage inside the ANSI C84.1 Range B utilisation band
%                 [0.90, 1.05] pu in EVERY scenario, and no diverged power flow
%                 in any scenario. The coupling is strongly binding: 11394
%                 topologies satisfy the band at the base level but only 3852
%                 survive the peak level as well. Topologies whose power flow
%                 diverges receive a dominated penalty point and can never enter
%                 the Pareto set.
%   Reference   : exact. The feasible topology space is precisely the set of
%                 spanning trees of the feeder graph (50751 of them), enumerated
%                 exhaustively and cross-checked against the Kirchhoff
%                 matrix-tree count, so the Pareto set needs no convergence
%                 argument. The front is confirmed by a second, independent
%                 dominance filter before anything is written.
%   Modality    : GLPF. An exact local Pareto certificate over the single
%                 branch-exchange neighbourhood (close a tie, open a branch on
%                 the unique cycle) is stored next to the global reference and
%                 exposed through GetPSLocal/GetPFLocal. The certificate helper
%                 is verified against the published DNR33 旧版（退役） numbers row for row by
%                 tests/dnr_local_helper_crosscheck.m.
%
%   Power flow is the constant-PQ backward/forward sweep validated against the
%   upstream Newton-Raphson implementation (tests/dnr_differential_powerflow.m),
%   reused unchanged from DNR33 旧版（退役）: this class adds scenarios, not a new solver.

    methods(Access = private)
        function s = msFile(~)
            s = 'DNR33MS_1.mat';
        end
        function s = feederFile(~)
            s = 'DNR33_1.mat';
        end
        function s = classFile(~)
            s = 'RWMMOP12_DNR33MS';
        end
    end

    properties(SetAccess = private)
        F;
        MS;
    end
    properties(Access = private)
        Sc = [];
        CacheX = [];
        CacheR = [];
        RefPS = [];
        RefPF = [];
        RefPFRaw = [];
        LocPS = [];
        LocPF = [];
        LocPFRaw = [];
        ObjLo = [];
        ObjHi = [];
    end
    methods
        function obj = Setting(obj)
            d = fullfile(fileparts(mfilename('fullpath')),'data');
            SM = load(fullfile(d,obj.msFile()),'MS');
            obj.MS = SM.MS;
            SF = load(fullfile(d,obj.feederFile()),'F');
            obj.F = SF.F;
            assert(strcmp(obj.MS.sourceFeeder, obj.F.name), 'RWMMO:DNRMS', ...
                'Snapshot %s is not derived from feeder %s.', obj.MS.sourceFeeder, obj.F.name);
            obj.M = numel(obj.MS.objSpec);
            obj.D = obj.F.nBranch;
            obj.encoding = 4*ones(1,obj.D);
            obj.lower = zeros(1,obj.D);
            obj.upper = ones(1,obj.D);
            obj.Sc = rwmmo_dnr_scenarios(obj.F, 'VminLim', obj.MS.vminLim);
            assert(isequal({obj.Sc.name}, obj.MS.scenarioNames), 'RWMMO:DNRMS', 'Scenario names drifted.');
            assert(max(abs([obj.Sc.multiplier] - obj.MS.levels)) < 1e-12, 'RWMMO:DNRMS', 'Load levels drifted.');
            Fs = [obj.Sc.F];
            assert(all(abs([Fs.VminLim] - obj.MS.vminLim) < 1e-12) && ...
                   all(abs([Fs.VmaxLim] - obj.MS.vmaxLim) < 1e-12), 'RWMMO:DNRMS', 'Voltage window drifted.');
        end
        function X = CalDec(obj,X)
            X = double(rwmmo_dnr_repair(X, obj.F.branchFrom, obj.F.branchTo, obj.F.nbus));
            obj.CacheX = []; obj.CacheR = [];
        end
        function PopObj = CalObj(obj,X)
            PopObj = rwmmo_dnr_normalize(obj.evaluate(X).objs, obj.scaleLo(), obj.scaleHi());
        end
        function PopObjRaw = CalObjRaw(obj,X)
            PopObjRaw = obj.evaluate(X).objs;
        end
        function PopCon = CalCon(obj,X)
            PopCon = obj.evaluate(X).cons;
        end
        function R = GetOptimum(obj,~)
            % The frozen archive as-is (uniform convention across RWMMO).
            R = obj.referencePF();
        end
        function R = GetPF(obj)
            R = obj.referencePF();
        end
        function R = GetPS(obj)
            R = obj.referencePS();
        end
        function R = GetPFRaw(obj)
            obj.loadReference();
            R = obj.RefPFRaw;
        end
        function R = GetPSLocal(obj)
            obj.loadLocal();
            R = obj.LocPS;
        end
        function R = GetPFLocal(obj)
            obj.loadLocal();
            R = obj.LocPF;
        end
        function R = GetObjectiveScale(obj)
            R = [obj.scaleLo(); obj.scaleHi()];
        end
        function Sc = GetScenarios(obj)
            Sc = obj.Sc;
        end
        function score = CalMetric(obj,metName,Population)
            if strcmp(metName,'IGDX')
                score = feval(metName, Population, obj.referencePS());
            else
                score = feval(metName, Population, obj.optimum);
            end
        end
        function DrawObj(obj,Population)
        %Platform rendering: population markers plus the frozen reference
        %archive as points. obj.PF is consumed only by PROBLEM.DrawObj, so
        %clearing it lets the platform plot obj.optimum (the frozen archive)
        %as reference points instead of joining the discrete archive rows
        %into a line.
            obj.PF = [];
            DrawObj@PROBLEM(obj,Population);
        end
        function varargout = DrawSolution(obj,dec)
        %DrawSolution - Display ONE solution's domain picture in a new figure.
        %   f = P.DrawSolution(x) renders the concrete engineering shape of
        %   the single decision row x (repaired through CalDec and evaluated
        %   once) with the same domain renderer as the offline gallery
        %   (viz\rwmmo_render_solution) and returns the figure handle.
        %   DrawDec, inherited from PROBLEM, shows the population
        %   distribution in the decision space; the single-solution view is
        %   deliberately a separate entry point.
            [varargout{1:nargout}] = rwmmo_show_solution(obj, dec);
        end
    end
    methods(Access = private)
        function R = evaluate(obj,X)
            if ~isempty(obj.CacheX) && isequal(size(obj.CacheX),size(X)) && all(obj.CacheX(:) == X(:))
                R = obj.CacheR;
                return;
            end
            R = rwmmo_dnr_ms_evaluate(X, obj.Sc, false, obj.MS.objSpec);
            obj.CacheX = X; obj.CacheR = R;
        end
        function lo = scaleLo(obj)
            if isempty(obj.ObjLo), obj.loadReference(); end
            lo = obj.ObjLo;
        end
        function hi = scaleHi(obj)
            if isempty(obj.ObjHi), obj.loadReference(); end
            hi = obj.ObjHi;
        end
        function PS = referencePS(obj)
            if isempty(obj.RefPS), obj.loadReference(); end
            PS = obj.RefPS;
        end
        function PF = referencePF(obj)
            if isempty(obj.RefPF), obj.loadReference(); end
            PF = obj.RefPF;
        end
        function loadReference(obj)
            f = fullfile(fileparts(mfilename('fullpath')),'ref_pf_ps', ...
                [obj.classFile() '_reference.mat']);
            assert(isfile(f), 'RWMMO:ReferenceMissing', ...
                'Run tests/dnr_ms_reference_exact.m to build %s.', f);
            S = load(f,'PS_ref','PF_ref','PF_ref_raw','objLo','objHi');
            assert(size(S.PS_ref,1) == size(S.PF_ref,1) && size(S.PS_ref,1) > 0, ...
                'RWMMO:ReferenceInvalid', 'Malformed reference archive.');
            assert(all(S.objHi > S.objLo), 'RWMMO:ReferenceInvalid', 'Degenerate objective scale.');
            obj.RefPS = S.PS_ref; obj.RefPF = S.PF_ref; obj.RefPFRaw = S.PF_ref_raw;
            obj.ObjLo = S.objLo(:)'; obj.ObjHi = S.objHi(:)';
        end
        function loadLocal(obj)
            f = fullfile(fileparts(mfilename('fullpath')),'ref_pf_ps', ...
                [obj.classFile() '_local_reference.mat']);
            assert(isfile(f), 'RWMMO:ReferenceMissing', ...
                'Run tests/dnr_ms_reference_exact.m to build %s.', f);
            S = load(f,'PS_local','PF_local','PF_local_raw');
            assert(size(S.PS_local,1) == size(S.PF_local,1) && size(S.PS_local,1) > 0, ...
                'RWMMO:ReferenceInvalid', 'Malformed local reference archive.');
            obj.LocPS = S.PS_local; obj.LocPF = S.PF_local; obj.LocPFRaw = S.PF_local_raw;
        end
    end
end
