classdef RWMMOP8_Knapsack24 < PROBLEM
% <2026> <multi> <binary> <constrained> <multimodal>
% Bi-objective 0/1 knapsack (resource/portfolio selection), 24 items.
%
%   Decision    : one binary variable per item (24 items); D = 24, so the
%                 design space is exactly 2^24 = 16777216 and stays fully
%                 enumerable in chunks (scale-up of Knapsack12（退役） under
%                 DEC-20260923-061: the front is far beyond a few thousand
%                 evaluations while the reference stays EXACT).
%   Objectives  : [1] negative total value  -sum v_i x_i   (minimise)
%                 [2] total weight           sum w_i x_i   (minimise)
%                 The two conflict because the valuable items are the heavy
%                 ones, and the capacity constraint cuts the feasible set.
%   Constraints : sum w_i x_i <= capacity (positive value means violated).
%   Multimodality: items 1-2, 3-4 and 5-6 are three identical twin pairs,
%                 so exchanging the members of any pair leaves both
%                 objectives bit-identical while the decision vector
%                 changes: exact equivalent-multimodality by construction
%                 (swap group of eight per representative). Values and
%                 weights elsewhere are distinct primes, so accidental
%                 subset-sum collisions are rare.
%   Reference   : exact. The full 2^24 space is enumerated in chunks and the
%                 Pareto set is cross-checked by a second dominance filter.
%                 No local certificate is archived: under the single-item
%                 flip neighbourhood a flip always trades value against
%                 weight, so NO feasible design is dominated by a neighbour
%                 and the locally Pareto set would be the entire feasible
%                 set (the Knapsack12（退役） certificate was exactly this trivial set);
%                 the honest modality claim is therefore EM only.
%   Licence     : the 0/1 knapsack model is classical public-domain
%                 optimisation theory and the instance is frozen by this
%                 project (same position as WTA44（退役）/RWMMOP13/Knapsack12（退役）).
    properties(SetAccess = private)
        KS;
    end
    properties(Access = private)
        CacheX = [];
        CacheR = [];
        RefPS = [];
        RefPF = [];
        RefPFRaw = [];
        ObjLo = [];
        ObjHi = [];
    end
    methods
        function obj = Setting(obj)
            d = fullfile(fileparts(mfilename('fullpath')),'data');
            S = load(fullfile(d,'Knapsack24_1.mat'));
            obj.KS = S;
            obj.M = 2;
            obj.D = S.n;
            obj.encoding = 4*ones(1,obj.D);
            obj.lower = zeros(1,obj.D);
            obj.upper = ones(1,obj.D);
        end
        function X = CalDec(obj,X)
            X = min(1, max(0, round(X)));
            obj.CacheX = []; obj.CacheR = [];
        end
        function PopObj = CalObj(obj,X)
            PopObj = rwmmo_normalize_objectives(obj.CalObjRaw(X), obj.scaleLo(), obj.scaleHi());
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
            X = obj.CalDec(X);
            if ~isempty(obj.CacheX) && isequal(size(obj.CacheX),size(X)) && all(obj.CacheX(:) == X(:))
                R = obj.CacheR;
                return;
            end
            KS = obj.KS;
            val = X * KS.v(:);
            wt = X * KS.w(:);
            R.objs = [-val, wt];
            R.cons = wt - KS.capacity;
            R.feasible = R.cons <= 0;
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
            f = fullfile(fileparts(mfilename('fullpath')),'ref_pf_ps','RWMMOP8_Knapsack24_reference.mat');
            assert(isfile(f), 'RWMMO:ReferenceMissing', 'Run tests/knapsack24_reference_exact.m to build %s.', f);
            S = load(f,'PS_ref','PF_ref','PF_ref_raw','objLo','objHi');
            assert(size(S.PS_ref,1) == size(S.PF_ref,1) && size(S.PS_ref,1) > 0, 'RWMMO:ReferenceInvalid', 'Malformed reference archive.');
            assert(all(S.objHi > S.objLo), 'RWMMO:ReferenceInvalid', 'Degenerate objective scale.');
            obj.RefPS = S.PS_ref; obj.RefPF = S.PF_ref; obj.RefPFRaw = S.PF_ref_raw;
            obj.ObjLo = S.objLo(:)'; obj.ObjHi = S.objHi(:)';
        end
    end
end
