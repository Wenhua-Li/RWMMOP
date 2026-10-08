classdef RWMMOP5_WindFarm < PROBLEM
% <2026> <multi> <real> <constrained> <multimodal>
% Wind-farm layout optimisation on a frozen self-constructed instance (RWMMOP5).
%
%   Decision    : 8 identical turbine coordinates in km, D = 16, inside a
%                 [0,10] x [0,7] box; feasibility is decided by the convex
%                 site polygon, a pairwise minimum spacing and two circular
%                 exclusion zones (all analytic point-location tests).
%   Objectives  : [1] negative annual energy production [MWh] under the
%                 frozen 12-sector wind rose with Jensen/Park wakes and a
%                 generic cubic power curve
%                 [2] collection cable length [km]: minimum spanning tree
%                 over the eight turbines plus the substation
%                 CalObj returns these mapped affinely onto the archived
%                 Pareto range (constants frozen in the reference archive);
%                 CalObjRaw returns engineering units.
%   Constraints : four signed violations: site-polygon clearance, spacing,
%                 one per exclusion zone (max over turbines).
%   Reference   : high-budget-approx with a convergence criterion (three
%                 consecutive zero eps-cell-gain seeds, recorded in
%                 results\windfarm\windfarm_stability_curve.csv).
%   Modality    : EM (certificate label since DEC-20260928-064; previously
%                 MIX expected). EM: the eight turbines are identical, so any
%                 permutation of the (x,y) pairs is objective-preserving
%                 (verified bit-identical, archived as copied-objective
%                 partners, multiplicity capped at 8). Wake shadows do make
%                 19 layouts locally Pareto under the single-turbine 0.5 km
%                 relocation lattice, but all 19 sit 19.7-47.2 front ranges
%                 above the front maximum on the cable axis (raw cable
%                 9.2-18.2 km vs a 2.46-2.79 km front range), so the eps=0.3
%                 quality gate removes every separated local optimum from the
%                 published certificate and no GLPF claim is made; the
%                 unfiltered enumeration stays in the sidecar metadata.
%
%   The wake model, power curve and wind rose are classical public-domain
%   wind engineering; the instance geometry is original to this project.

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
            S = load(fullfile(fileparts(mfilename('fullpath')),'data','WindFarm_1.mat'));
            obj.F = S;
            obj.D = 2 * S.N;
            obj.encoding = ones(1, obj.D);
            obj.lower = repmat(S.boxLower, 1, S.N);
            obj.upper = repmat(S.boxUpper, 1, S.N);
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
            R = rwmmo_windfarm_objectives(X, obj.F);
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
                'RWMMOP5_WindFarm_reference.mat');
            assert(isfile(f), 'RWMMO:ReferenceMissing', ...
                'Run tests/windfarm_reference_build.m to build %s.', f);
            S = load(f,'PS_ref','PF_ref','PF_ref_raw','objLo','objHi');
            assert(size(S.PS_ref,1) == size(S.PF_ref,1) && size(S.PS_ref,1) > 0, ...
                'RWMMO:ReferenceInvalid', 'Malformed reference archive.');
            assert(all(S.objHi > S.objLo), 'RWMMO:ReferenceInvalid', 'Degenerate objective scale.');
            obj.RefPS = S.PS_ref; obj.RefPF = S.PF_ref; obj.RefPFRaw = S.PF_ref_raw;
            obj.ObjLo = S.objLo(:)'; obj.ObjHi = S.objHi(:)';
        end
        function loadLocal(obj)
            f = fullfile(fileparts(mfilename('fullpath')),'ref_pf_ps', ...
                'RWMMOP5_WindFarm_local_reference.mat');
            assert(isfile(f), 'RWMMO:ReferenceMissing', ...
                'Run tests/windfarm_reference_build.m to build %s.', f);
            S = load(f,'PS_local','PF_local','PF_local_raw');
            assert(size(S.PS_local,1) == size(S.PF_local,1) && size(S.PS_local,1) > 0, ...
                'RWMMO:ReferenceInvalid', 'Malformed local reference archive.');
            obj.LocPS = S.PS_local; obj.LocPF = S.PF_local; obj.LocPFRaw = S.PF_local_raw;
        end
    end
end
