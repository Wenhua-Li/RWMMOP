classdef RWMMOP9_WTA66 < PROBLEM
% <2026> <multi> <integer> <constrained> <multimodal>
% Weapon-target assignment on a frozen 6-target, 6-weapon-type instance.
%
%   Decision    : x(i,j) = missiles of weapon type j assigned to target i,
%                 36 integer variables in [0, q_j]. rwmmo_wta_repair projects
%                 every allocation onto the inventory-feasible set, so each
%                 evaluated solution is physically meaningful. The feasible
%                 set is the product of the per-type composition sets,
%                 210^2 * 924^2 * 3003^2 = 339541760652494400 allocations -
%                 far beyond enumeration, which is why the reference is
%                 high-budget-approx (DEC-20260923-061 scale-up replacing
%                 WTA44/WTA33).
%   Objectives  : [1] negative expected retained value -sum_i V_i P_i(X)
%                 [2] ammunition cost sum_j c_j sum_i x(i,j)
%                 CalObj returns both mapped affinely onto the instance-derived
%                 ranges [-maxValue, 0] and [0, maxCost]; CalObjRaw returns
%                 engineering units. The constants come from the frozen
%                 instance, never from an archive, so they cannot drift.
%   Constraints : at most salvoMax = 5 missiles per target (fire-control
%                 channels). Inventory limits are enforced by the repair map.
%                 The platform default initialiser is kept: almost no
%                 unguided draw satisfies the five-channel cap (measured,
%                 tests/wta66_build_snapshot.m), and spreading fire across
%                 targets IS the constraint-handling difficulty under test
%                 (documented default exception, same position as RWMMOP8/RWMMOP20/RWMMOP14).
%   Reference   : high-budget-approx. The archive is grown by independent
%                 seeds of a fixed multi-algorithm search plus uniform
%                 inventory-feasible fills, and is declared CONVERGED when
%                 further seeds neither add nor drop a non-dominated row
%                 (the RWMMOP2 criterion); see tests/wta66_reference_build.m.
%   Modality    : EM. Weapon types 3/4 and 5/6 are two pairs of twin batches
%                 (identical kill probabilities, identical unit cost, equal
%                 inventories), so exchanging the two columns of a pair maps
%                 every plan to a plan with identical objectives. The archive
%                 stores up to 8 verified twin partners per objective vector
%                 (the RWMMOP1/RWMMOP2 multiplicity cap), with objectives copied from
%                 the representative after the agreement has been measured -
%                 swapping the columns reorders the survive product, so raw
%                 evaluations agree only to float round-off. No local Pareto
%                 certificate exists (the feasible set cannot be enumerated),
%                 so GLPF is not claimed.

    properties(SetAccess = private)
        W;
    end
    properties(Access = private)
        CacheX = [];
        CacheR = [];
        RefPS = [];
        RefPF = [];
        RefPFRaw = [];
    end
    methods
        function obj = Setting(obj)
            S = load(fullfile(fileparts(mfilename('fullpath')),'data','WTA66_1.mat'),'W');
            obj.W = S.W;
            obj.M = obj.W.M;
            obj.D = obj.W.D;
            obj.encoding = 2*ones(1,obj.D);
            obj.lower = obj.W.lower;
            obj.upper = obj.W.upper;
        end
        function X = CalDec(obj,X)
            X = rwmmo_wta_repair(X, obj.W);
            obj.CacheX = []; obj.CacheR = [];
        end
        function PopObj = CalObj(obj,X)
            PopObj = rwmmo_normalize_objectives(obj.CalObjRaw(X), obj.W.objLo, obj.W.objHi);
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
            obj.loadReference();
            R = obj.RefPS;
        end
        function R = GetPFRaw(obj)
            obj.loadReference();
            R = obj.RefPFRaw;
        end
        function R = GetObjectiveScale(obj)
            R = [obj.W.objLo(:)'; obj.W.objHi(:)'];
        end
        function score = CalMetric(obj,metName,Population)
            if strcmp(metName,'IGDX')
                score = feval(metName, Population, obj.GetPS());
            else
                score = feval(metName, Population, obj.optimum);
            end
        end
        function DrawObj(obj,Population)
        %Platform rendering: population markers plus the frozen reference
        %archive as points (same convention as every RWMMO class).
            obj.PF = [];
            DrawObj@PROBLEM(obj,Population);
        end
        function varargout = DrawSolution(obj,dec)
        %DrawSolution - Display ONE solution's domain picture in a new figure.
        %   f = P.DrawSolution(x) renders the concrete engagement plan of
        %   the single decision row x (repaired through CalDec and evaluated
        %   once) with the same domain renderer as the offline gallery
        %   (viz\rwmmo_render_solution) and returns the figure handle.
            [varargout{1:nargout}] = rwmmo_show_solution(obj, dec);
        end
    end
    methods(Access = private)
        function R = evaluate(obj,X)
            if ~isempty(obj.CacheX) && isequal(size(obj.CacheX),size(X)) && all(obj.CacheX(:) == X(:))
                R = obj.CacheR;
                return;
            end
            R = rwmmo_wta_objectives(rwmmo_wta_repair(X, obj.W), obj.W);
            obj.CacheX = X; obj.CacheR = R;
        end
        function PF = referencePF(obj)
            if isempty(obj.RefPF), obj.loadReference(); end
            PF = obj.RefPF;
        end
        function loadReference(obj)
            f = fullfile(fileparts(mfilename('fullpath')),'ref_pf_ps','RWMMOP9_WTA66_reference.mat');
            assert(isfile(f), 'RWMMO:ReferenceMissing', 'Run tests/wta66_reference_build.m to build %s.', f);
            S = load(f,'PS_ref','PF_ref','PF_ref_raw');
            assert(size(S.PS_ref,1) == size(S.PF_ref,1) && size(S.PS_ref,1) > 0, ...
                'RWMMO:ReferenceInvalid', 'Malformed WTA66 reference archive.');
            obj.RefPS = S.PS_ref; obj.RefPF = S.PF_ref; obj.RefPFRaw = S.PF_ref_raw;
        end
    end
end
