classdef RWMMOP15_SiteSelect < PROBLEM
% <2026> <multi> <real> <constrained> <multimodal>
% Emergency service facility location with forbidden geography (RWMMO RWMMOP15).
%
%   Decision    : x = (x1, x2), the site coordinates in km inside a frozen
%                 10 km x 6 km study area. CalDec clamps to the box, so every
%                 evaluated solution is a physically meaningful site.
%   Objectives  : [1] distance to the nearest residential node
%                 [2] distance to the nearest commercial/industrial node
%                 [3] distance to the nearest transport-hub node
%                 all in km; CalObjRaw returns km, CalObj returns the affine
%                 image under constants that are frozen in the data snapshot by
%                 tests/site_select_reference_exact.m from the certified front,
%                 never recomputed at run time.
%   Constraints : eight analytic keep-out regions, each reported as its own
%                 violation in the PlatEMO convention (<= 0 feasible): a river /
%                 high-voltage corridor, a trunk-road red line, three circular
%                 exclusion zones (existing plant service circles, a pair of
%                 geological hazards) and one convex wetland reserve. The two
%                 corridors cross the whole study area, so the feasible set is
%                 disconnected into four chunks.
%   Reference   : certified-dense. A 0.005 km grid covers the box, feasibility
%                 is decided analytically at every grid node, and the archive is
%                 the eps-front of the grid at 0.01 km per objective axis plus
%                 the exact mirror partner of every archived site. Every
%                 feasible grid node is eps-dominated by an archived site and
%                 each objective is 1-Lipschitz, so the archive is within
%                 eps + h/sqrt(2) km per axis of the true Pareto front; the
%                 numbers are recorded in the archive metadata.
%   Modality    : MIX. The instance is mirror symmetric about x = 5 km in both
%                 its facility sets and its forbidden geography, so a feasible
%                 site and its mirror have bit-identical objectives while being
%                 up to 9 km apart in decision space (EM, exact ties by
%                 construction rather than by sampling luck). A relocation
%                 lattice certificate at 0.25 km - one city block, the smallest
%                 move a planner can actually make - additionally lists the
%                 sites that are locally but not globally Pareto optimal (GLPF).
%   Initialis.  : rejection sampling with the exact analytic feasibility test,
%                 which is uniform over the feasible region by construction. The
%                 platform default (uniform over the box) puts about 30% of the
%                 population inside a keep-out region, so the class initialiser
%                 is measurably better and the wrapper smoke test asserts it.

    properties(SetAccess = private)
        G;
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
    end
    methods
        function obj = Setting(obj)
            S = load(fullfile(fileparts(mfilename('fullpath')),'data','SiteSelect_1.mat'),'G');
            obj.G = S.G;
            assert(isfield(obj.G,'objLo') && isfield(obj.G,'objHi'), ...
                'RWMMO:SiteSelect', 'Run tests/site_select_reference_exact.m to freeze the objective scale.');
            obj.M = 3;
            obj.D = 2;
            obj.lower = obj.G.domain(1,:);
            obj.upper = obj.G.domain(2,:);
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
        function Population = Initialization(obj,N)
        %Uniform draw over the feasible region by analytic rejection sampling.
        %   Feasibility is an exact point-location test, so accepting only the
        %   feasible draws of a uniform box sample is exactly uniform over the
        %   feasible set. The draw is reproducible under rng and is a fixed
        %   point of CalDec.
            if nargin < 2 || isempty(N), N = obj.N; end
            span = obj.upper - obj.lower;
            PopDec = zeros(N,obj.D);
            got = 0; tries = 0;
            while got < N
                batch = max(64, ceil((N - got) * 2));
                C = obj.lower + rand(batch,obj.D) .* span;
                ok = rwmmo_site_objectives(C, obj.G).feasible;
                C = C(ok,:);
                take = min(size(C,1), N - got);
                PopDec(got + (1:take), :) = C(1:take,:);
                got = got + take;
                tries = tries + batch;
                assert(tries < 200 * max(N,1), 'RWMMO:SiteSelect', ...
                    'Rejection sampling did not converge; is the feasible set empty?');
            end
            assert(all(rwmmo_site_objectives(PopDec, obj.G).feasible, 'all'), ...
                'RWMMO:SiteSelect', 'Initialiser produced an infeasible site.');
            Population = obj.Evaluation(PopDec);
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
        function R = GetPSLocal(obj)
            obj.loadLocal();
            R = obj.LocPS;
        end
        function R = GetPFLocal(obj)
            obj.loadLocal();
            R = obj.LocPF;
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
            R = rwmmo_site_objectives(obj.CalDecLocal(X), obj.G);
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
            f = fullfile(fileparts(mfilename('fullpath')),'ref_pf_ps','RWMMOP15_SiteSelect_reference.mat');
            assert(isfile(f), 'RWMMO:ReferenceMissing', 'Run tests/site_select_reference_exact.m to build %s.', f);
            S = load(f,'PS_ref','PF_ref','PF_ref_raw');
            assert(size(S.PS_ref,1) == size(S.PF_ref,1) && size(S.PS_ref,1) > 1, ...
                'RWMMO:ReferenceInvalid', 'Malformed SiteSelect reference archive.');
            obj.RefPS = S.PS_ref; obj.RefPF = S.PF_ref; obj.RefPFRaw = S.PF_ref_raw;
        end
        function loadLocal(obj)
            f = fullfile(fileparts(mfilename('fullpath')),'ref_pf_ps','RWMMOP15_SiteSelect_local_reference.mat');
            assert(isfile(f), 'RWMMO:ReferenceMissing', 'Run tests/site_select_reference_exact.m to build %s.', f);
            S = load(f,'PS_local','PF_local','PF_local_raw');
            assert(size(S.PS_local,1) == size(S.PF_local,1) && size(S.PS_local,1) > 1, ...
                'RWMMO:ReferenceInvalid', 'Malformed SiteSelect local archive.');
            obj.LocPS = S.PS_local; obj.LocPF = S.PF_local; obj.LocPFRaw = S.PF_local_raw;
        end
    end
end