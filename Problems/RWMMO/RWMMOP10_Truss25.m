classdef RWMMOP10_Truss25 < PROBLEM
% <2026> <multi> <real> <constrained> <multimodal>
% Twenty-five-bar cantilever truss sizing: weight versus stiffness (RWMMO RWMMOP10).
%
%   Decision    : x = A1..A25, the member cross-section areas of a five-bay
%                 symmetric cantilever truss (frozen geometry in
%                 tests/truss25_instance.m). CalDec clamps to the box, so
%                 every evaluated row is a manufacturable sizing plan. The
%                 five-bay cantilever is classical structural mechanics; the
%                 member table, material constants, load level and box are
%                 frozen by this project. Scale-up replacement of Truss10
%                 under DEC-20260923-061.
%   Objectives  : [1] total structural weight (kg)
%                 [2] largest nodal displacement over the free DOFs (m)
%                 CalObjRaw returns SI units; CalObj is the affine image
%                 under constants frozen into the snapshot by
%                 tests/truss25_reference_build.m from the archive front.
%   Constraints : 25 signed stress violations |sigma_i| - sigmaAllow <= 0
%                 (sigmaAllow = 250 MPa, tension and compression alike).
%   Reference   : high-budget-approx. The archive is grown by independent
%                 seeds of a fixed reference search (NSGA-II and DN-NSGA-II
%                 at maxFE = 50000, N = 100, plus structured fills) and is
%                 declared CONVERGED when further seeds neither add nor drop
%                 an eps representative - the RWMMOP2 criterion. Every archived
%                 row is re-evaluated from its own decision vector before
%                 writing.
%   Modality    : EM. The instance is mirror symmetric about y = 0.5 in BOTH
%                 topology and loads, so swapping the member pairs
%                 (m1..m5 <-> m6..m10) and (m16..m20 <-> m21..m25) - the five
%                 verticals m11..m15 are fixed by the mirror - maps every plan
%                 to a plan with identical objectives. The mirror partner of
%                 every archived row is added with objectives copied from the
%                 representative after numerical agreement has been verified,
%                 which makes the exact ties structural rather than a sampling
%                 coincidence. No local Pareto certificate exists for a 25-D
%                 continuous sizing space, so GLPF is not claimed.
%   Initialis.  : platform default (uniform box). Almost every draw is
%                 stress-infeasible somewhere (measured 0.0000 in
%                 tests/truss25_build_snapshot.m) - sizing a five-bay
%                 cantilever to satisfy all 25 stress limits IS the
%                 constraint-handling difficulty under test (documented
%                 default exception).

    properties(SetAccess = private)
        G;
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
            S = load(fullfile(fileparts(mfilename('fullpath')),'data','Truss25_1.mat'),'G');
            obj.G = S.G;
            assert(isfield(obj.G,'objLo') && isfield(obj.G,'objHi'), ...
                'RWMMO:Truss25', 'Run tests/truss25_reference_build.m to freeze the objective scale.');
            obj.M = 2;
            obj.D = 25;
            obj.lower = obj.G.lower;
            obj.upper = obj.G.upper;
            obj.encoding = ones(1,obj.D);
        end
        function X = CalDec(obj,X)
            X = min(max(double(X), obj.lower), obj.upper);
            obj.CacheX = []; obj.CacheR = [];
        end
        function PopObj = CalObj(obj,X)
            PopObj = rwmmo_normalize_objectives(obj.CalObjRaw(X), obj.G.objLo, obj.G.objHi);
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
            R = [obj.G.objLo(:)'; obj.G.objHi(:)'];
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
        %DrawSolution - Display ONE sizing plan in a new figure.
        %   f = P.DrawSolution(x) renders the truss of the single decision
        %   row x with the same domain renderer as the offline gallery
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
            R = rwmmo_truss_objectives(obj.CalDecLocal(X), obj.G);
            obj.CacheX = X; obj.CacheR = R;
        end
        function X = CalDecLocal(obj,X)
            X = min(max(double(X), obj.lower), obj.upper);
        end
        function PF = referencePF(obj)
            if isempty(obj.RefPF), obj.loadReference(); end
            PF = obj.RefPF;
        end
        function loadReference(obj)
            f = fullfile(fileparts(mfilename('fullpath')),'ref_pf_ps','RWMMOP10_Truss25_reference.mat');
            assert(isfile(f), 'RWMMO:ReferenceMissing', 'Run tests/truss25_reference_build.m to build %s.', f);
            S = load(f,'PS_ref','PF_ref','PF_ref_raw');
            assert(size(S.PS_ref,1) == size(S.PF_ref,1) && size(S.PS_ref,1) > 1, ...
                'RWMMO:ReferenceInvalid', 'Malformed Truss25 reference archive.');
            obj.RefPS = S.PS_ref; obj.RefPF = S.PF_ref; obj.RefPFRaw = S.PF_ref_raw;
        end
    end
end
