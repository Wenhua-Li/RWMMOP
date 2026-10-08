classdef RWMMOP4_ArrayNull < PROBLEM
% <2026> <multi> <real> <multimodal>
% Linear antenna array synthesis with prescribed nulls (RWMMO RWMMOP4).
%
%   Decision    : x = a_1..a_8, the element amplitudes of an 8-element
%                 half-wavelength linear array steered to broadside,
%                 clipped to [0.2, 1] by CalDec. Amplitude-only synthesis
%                 with prescribed nulls is classical antenna engineering;
%                 the instance constants are frozen by this project
%                 (tests/arraynull_instance.m).
%   Objectives  : [1] peak sidelobe level in dB outside the fixed mainlobe
%                     window |theta - 90| <= 15 deg (a 0.25 deg sampling
%                     grid; smaller is better)
%                 [2] worst null-depth error in dB: the maximum absolute
%                     deviation of the pattern level at the prescribed nulls
%                     40 deg and 140 deg from the -60 dB target
%                 CalObjRaw returns dB; CalObj is the affine image under
%                 constants frozen into the snapshot by
%                 tests/arraynull_reference_build.m from the archive front.
%   Constraints : none - the amplitude box is the only limit and every
%                 decision is a realisable excitation.
%   Reference   : high-budget-approx. Adaptive multi-seed reference search
%                 (NSGA-II and DN-NSGA-II at maxFE = 20000, N = 100, plus
%                 structured fills), reduced to the eps-front (0.5% of the
%                 front span per objective axis), with the convergence
%                 criterion and - when the endpoints keep refining - the
%                 honest budget caveat of Truss10（退役）/EcoDispatch6（退役）.
%   Modality    : EM. Reversing the excitation (a_n -> a_{9-n}) conjugates
%                 the array factor, so the magnitude pattern - and with it
%                 both objectives - is IDENTICAL; the reversal partner of
%                 every archived representative is added with the
%                 representative's copied objectives (multiplicity 2), and
%                 the two prescribed null directions map into each other
%                 under the same reversal. The sidelobe/null landscape has
%                 sampled local structure but no certified GLPF statement
%                 is claimed.
%   Initialis.  : platform default (uniform box). Every draw is feasible.

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
            S = load(fullfile(fileparts(mfilename('fullpath')),'data','ArrayNull_1.mat'),'G');
            obj.G = S.G;
            assert(isfield(obj.G,'objLo') && isfield(obj.G,'objHi'), ...
                'RWMMO:ArrayNull', 'Run tests/arraynull_reference_build.m to freeze the objective scale.');
            obj.M = 2;
            obj.D = 8;
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
        %DrawSolution - Display ONE excitation and its pattern in a new figure.
        %   f = P.DrawSolution(x) renders the pattern cut and the amplitude
        %   taper of the single decision row x with the same domain renderer
        %   as the offline gallery (viz\rwmmo_render_solution) and returns
        %   the figure handle.
            [varargout{1:nargout}] = rwmmo_show_solution(obj, dec);
        end
    end
    methods(Access = private)
        function R = evaluate(obj,X)
            if ~isempty(obj.CacheX) && isequal(size(obj.CacheX),size(X)) && all(obj.CacheX(:) == X(:))
                R = obj.CacheR;
                return;
            end
            R = rwmmo_arraynull_objectives(obj.CalDecLocal(X), obj.G);
            obj.CacheX = X; obj.CacheR = struct('objs',R.objs,'cons',R.cons,'feasible',R.feasible);
        end
        function X = CalDecLocal(obj,X)
            X = min(max(double(X), obj.lower), obj.upper);
        end
        function PF = referencePF(obj)
            if isempty(obj.RefPF), obj.loadReference(); end
            PF = obj.RefPF;
        end
        function loadReference(obj)
            f = fullfile(fileparts(mfilename('fullpath')),'ref_pf_ps','RWMMOP4_ArrayNull_reference.mat');
            assert(isfile(f), 'RWMMO:ReferenceMissing', 'Run tests/arraynull_reference_build.m to build %s.', f);
            S = load(f,'PS_ref','PF_ref','PF_ref_raw');
            assert(size(S.PS_ref,1) == size(S.PF_ref,1) && size(S.PS_ref,1) > 1, ...
                'RWMMO:ReferenceInvalid', 'Malformed ArrayNull reference archive.');
            obj.RefPS = S.PS_ref; obj.RefPF = S.PF_ref; obj.RefPFRaw = S.PF_ref_raw;
        end
    end
end
