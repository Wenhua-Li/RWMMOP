classdef RWMMOP6_NestingLayout < PROBLEM
% <2026> <multi> <real> <constrained> <multimodal>
% Two-dimensional nesting (cutting-stock layout) on a frozen instance (RWMMOP6).
%
%   Decision    : per part centre (x,y) and orientation theta, six parts in
%                 three identical pairs, D = 18 real.
%   Objectives  : [1] bounding-box area of the placed part corners (material
%                 used on the 12 x 8 sheet)
%                 [2] negative centre spread -sum over part pairs of centre
%                 distance (cutting robustness)
%                 CalObj returns these mapped affinely onto the archived
%                 Pareto range (constants frozen in the reference archive);
%                 CalObjRaw returns engineering units.
%   Constraints : signed: pairwise SAT penetration depth over the rectangle
%                 unions (<= 0 when disjoint) and per-part worst sheet
%                 boundary excess.
%   Reference   : high-budget-approx with a convergence criterion (three
%                 consecutive zero eps-cell-gain seeds) plus verified
%                 symmetry partners.
%   Modality    : MIX expected. EM: rotating the whole layout by 180 degrees
%                 about the sheet centre and swapping identical part pairs
%                 preserve both objectives (group of 8 archived per
%                 representative, cap 8). GLPF: distinct packing patterns are
%                 local Pareto regions under the single-part relocation
%                 lattice (+/-0.25 translation, +/-15 deg rotation).
%
%   Nesting / cutting-stock models are classical public-domain manufacturing
%   optimisation; the part set and sheet are original to this project.

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
            S = load(fullfile(fileparts(mfilename('fullpath')),'data','NestingLayout_1.mat'));
            obj.F = S;
            obj.D = 3 * S.nParts;
            obj.encoding = ones(1, obj.D);
            obj.lower = repmat([0 0 0], 1, S.nParts);
            obj.upper = repmat([S.sheet(1), S.sheet(2), 2*pi], 1, S.nParts);
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
            R = rwmmo_nestinglayout_objectives(X, obj.F);
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
                'RWMMOP6_NestingLayout_reference.mat');
            assert(isfile(f), 'RWMMO:ReferenceMissing', ...
                'Run tests/nestinglayout_reference_build.m to build %s.', f);
            S = load(f,'PS_ref','PF_ref','PF_ref_raw','objLo','objHi');
            assert(size(S.PS_ref,1) == size(S.PF_ref,1) && size(S.PS_ref,1) > 0, ...
                'RWMMO:ReferenceInvalid', 'Malformed reference archive.');
            assert(all(S.objHi > S.objLo), 'RWMMO:ReferenceInvalid', 'Degenerate objective scale.');
            obj.RefPS = S.PS_ref; obj.RefPF = S.PF_ref; obj.RefPFRaw = S.PF_ref_raw;
            obj.ObjLo = S.objLo(:)'; obj.ObjHi = S.objHi(:)';
        end
        function loadLocal(obj)
            f = fullfile(fileparts(mfilename('fullpath')),'ref_pf_ps', ...
                'RWMMOP6_NestingLayout_local_reference.mat');
            assert(isfile(f), 'RWMMO:ReferenceMissing', ...
                'Run tests/nestinglayout_reference_build.m to build %s.', f);
            S = load(f,'PS_local','PF_local','PF_local_raw');
            assert(size(S.PS_local,1) == size(S.PF_local,1) && size(S.PS_local,1) > 0, ...
                'RWMMO:ReferenceInvalid', 'Malformed local reference archive.');
            obj.LocPS = S.PS_local; obj.LocPF = S.PF_local; obj.LocPFRaw = S.PF_local_raw;
        end
    end
end
