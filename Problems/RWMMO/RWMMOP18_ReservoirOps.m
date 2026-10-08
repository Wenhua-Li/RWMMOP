classdef RWMMOP18_ReservoirOps < PROBLEM
% <2026> <multi> <real> <constrained> <multimodal>
% Parallel-reservoir flood-control vs hydropower operation (RWMMOP18).
%
%   Decision    : releases of two identical parallel reservoirs over four
%                 periods, D = 8 real in [0, 250].
%   Objectives  : [1] downstream flood peak (max over periods of total
%                 release plus lateral inflow)
%                 [2] negative hydropower (sum of head*release, head from
%                 the storage trajectory)
%                 CalObj returns these mapped affinely onto the archived
%                 Pareto range (constants frozen in the reference archive);
%                 CalObjRaw returns engineering units.
%   Constraints : signed: per reservoir worst storage bound violation and
%                 per reservoir terminal-target violation (4 columns).
%   Reference   : high-budget-approx with a convergence criterion (three
%                 consecutive zero eps-cell-gain seeds) plus verified swap
%                 partners.
%   Modality    : MIX expected. EM: the two reservoirs are identical, so
%                 swapping their release trajectories preserves both
%                 objectives exactly. GLPF: distinct operation policies
%                 (pre-release / hold / late release) are local Pareto
%                 regions under the per-release relocation lattice.
%
%   Reservoir mass balance and head-power relations are classical
%   public-domain water-resources engineering; the hydrology is original.

    properties(SetAccess = private)
        F;
    end
    properties(Access = private)
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
            obj.M = 2;
            S = load(fullfile(fileparts(mfilename('fullpath')),'data','ReservoirOps_1.mat'));
            obj.F = S;
            obj.D = S.nRes * S.T;
            obj.encoding = ones(1, obj.D);
            obj.lower = zeros(1, obj.D);
            obj.upper = S.relMax * ones(1, obj.D);
        end
        function X = CalDec(obj,X)
            X = min(max(X, obj.lower), obj.upper);
            obj.CacheX = []; obj.CacheR = [];
        end
        function PopObj = CalObj(obj,X)
            PopObj = rwmmo_normalize_objectives(obj.evaluate(X).objs, obj.scaleLo(), obj.scaleHi());
        end
        function PopObjRaw = CalObjRaw(obj,X)
            PopObjRaw = obj.evaluate(X).objs;
        end
        function PopCon = CalCon(obj,X)
            PopCon = obj.evaluate(X).cons;
        end
        function R = GetOptimum(obj,~)
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
        function score = CalMetric(obj,metName,Population)
            if strcmp(metName,'IGDX')
                score = feval(metName, Population, obj.referencePS());
            else
                score = feval(metName, Population, obj.optimum);
            end
        end
        function DrawObj(obj,Population)
            obj.PF = [];
            DrawObj@PROBLEM(obj,Population);
        end
        function varargout = DrawSolution(obj,dec)
            [varargout{1:nargout}] = rwmmo_show_solution(obj, dec);
        end
    end
    methods(Access = private)
        function R = evaluate(obj,X)
            if ~isempty(obj.CacheX) && isequal(size(obj.CacheX),size(X)) && all(obj.CacheX(:) == X(:))
                R = obj.CacheR;
                return;
            end
            R = rwmmo_reservoirops_objectives(X, obj.F);
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
                'RWMMOP18_ReservoirOps_reference.mat');
            assert(isfile(f), 'RWMMO:ReferenceMissing', ...
                'Run tests/reservoirops_reference_build.m to build %s.', f);
            S = load(f,'PS_ref','PF_ref','PF_ref_raw','objLo','objHi');
            assert(size(S.PS_ref,1) == size(S.PF_ref,1) && size(S.PS_ref,1) > 0, ...
                'RWMMO:ReferenceInvalid', 'Malformed reference archive.');
            assert(all(S.objHi > S.objLo), 'RWMMO:ReferenceInvalid', 'Degenerate objective scale.');
            obj.RefPS = S.PS_ref; obj.RefPF = S.PF_ref; obj.RefPFRaw = S.PF_ref_raw;
            obj.ObjLo = S.objLo(:)'; obj.ObjHi = S.objHi(:)';
        end
        function loadLocal(obj)
            f = fullfile(fileparts(mfilename('fullpath')),'ref_pf_ps', ...
                'RWMMOP18_ReservoirOps_local_reference.mat');
            assert(isfile(f), 'RWMMO:ReferenceMissing', ...
                'Run tests/reservoirops_reference_build.m to build %s.', f);
            S = load(f,'PS_local','PF_local','PF_local_raw');
            assert(size(S.PS_local,1) == size(S.PF_local,1) && size(S.PS_local,1) > 0, ...
                'RWMMO:ReferenceInvalid', 'Malformed local reference archive.');
            obj.LocPS = S.PS_local; obj.LocPF = S.PF_local; obj.LocPFRaw = S.PF_local_raw;
        end
    end
end
