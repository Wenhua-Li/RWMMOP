classdef RWMMOP7_EcoDispatch15MF < PROBLEM
% <2026> <multi> <real> <constrained> <multimodal>
% Combined economic-emission dispatch with multi-fuel piecewise cost curves
% and valve-point loading, fifteen units (RWMMO RWMMOP7).
%
%   Decision    : x = P1..P15, the unit outputs in MW. CalDec clips to the
%                 unit box and then repairs the demand equality
%                 deterministically (largest head-room first), so every
%                 evaluated row is a balanced 2600 MW dispatch; the single
%                 reported constraint is the post-repair balance residual.
%                 Units (1,2), (3,4) and (5,6) are three identical twin
%                 pairs; units 7-15 are distinct. The instance coefficients
%                 are frozen by this project (tests/ecodispatch15_instance.m);
%                 the economic-emission dispatch model with valve-point and
%                 multi-fuel cost curves is classical power-systems
%                 engineering.
%   Objectives  : [1] total fuel cost per hour: piecewise quadratic per unit
%                     (fuel switch at Ps_u, continuous by construction) plus
%                     the sinusoidal valve-point terms of the valve units
%                 [2] total emission per hour
%                 CalObjRaw returns currency/h and tonnes/h; CalObj is the
%                 affine image under constants frozen into the snapshot by
%                 tests/ecodispatch15_reference_build.m.
%   Constraints : one signed violation, the post-repair balance residual
%                 |sum(P) - D| (<= 0 feasible; the repair keeps it at float
%                 noise by construction).
%   Reference   : high-budget-approx. The archive is grown by an adaptive
%                 multi-seed reference search (NSGA-II and DN-NSGA-II at
%                 maxFE = 20000, N = 100, plus structured fills), reduced to
%                 the eps-front (0.5% of the front span per objective axis),
%                 with the convergence criterion and - when the endpoints
%                 keep refining - the honest budget caveat of Truss10（退役）.
%   Modality    : EM. Swapping the outputs inside any twin pair is an exact
%                 objective-preserving map (identical coefficients and
%                 limits); the three pairs generate a swap group of eight,
%                 and each representative is archived together with its
%                 group partners carrying the representative's copied
%                 objectives (multiplicity capped at 8). The piecewise kinks
%                 and valve-point sinusoids make the cost surface nonconvex,
%                 which shows up as sampled local structure but is NOT
%                 claimed as a certified GLPF statement.
%   Initialis.  : platform default (uniform box, then the balance repair).
%                 The repair makes every draw a valid dispatch, so the start
%                 is feasible by construction.

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
            S = load(fullfile(fileparts(mfilename('fullpath')),'data','EcoDispatch15_1.mat'),'G');
            obj.G = S.G;
            assert(isfield(obj.G,'objLo') && isfield(obj.G,'objHi'), ...
                'RWMMO:EcoDispatch15MF', 'Run tests/ecodispatch15_reference_build.m to freeze the objective scale.');
            obj.M = 2;
            obj.D = 15;
            obj.lower = obj.G.lower;
            obj.upper = obj.G.upper;
            obj.encoding = ones(1,obj.D);
        end
        function X = CalDec(obj,X)
            X = rwmmo_ecodispatch15_repair(X, obj.G);
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
            [~, R] = rwmmo_ecodispatch15_repair(X, obj.G);
            obj.CacheX = X; obj.CacheR = struct('objs',R.objs,'cons',R.cons,'feasible',R.feasible);
        end
        function PF = referencePF(obj)
            if isempty(obj.RefPF), obj.loadReference(); end
            PF = obj.RefPF;
        end
        function loadReference(obj)
            f = fullfile(fileparts(mfilename('fullpath')),'ref_pf_ps','RWMMOP7_EcoDispatch15MF_reference.mat');
            assert(isfile(f), 'RWMMO:ReferenceMissing', 'Run tests/ecodispatch15_reference_build.m to build %s.', f);
            S = load(f,'PS_ref','PF_ref','PF_ref_raw');
            assert(size(S.PS_ref,1) == size(S.PF_ref,1) && size(S.PS_ref,1) > 1, ...
                'RWMMO:ReferenceInvalid', 'Malformed EcoDispatch15MF reference archive.');
            obj.RefPS = S.PS_ref; obj.RefPF = S.PF_ref; obj.RefPFRaw = S.PF_ref_raw;
        end
    end
end
