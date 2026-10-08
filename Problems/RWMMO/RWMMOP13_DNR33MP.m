classdef RWMMOP13_DNR33MP < PROBLEM
% <2026> <multi> <integer> <constrained> <multimodal>
% Two-period distribution network reconfiguration on the frozen IEEE 33-bus feeder.
%
%   Decision    : a pair of candidate-pool indices (i1, i2), i.e. which frozen
%                 radial topology serves period 1 (published load level) and
%                 which serves period 2 (peak level x1.3). D = 2 integer
%                 variables in [1, K]; the design space is exactly K^2.
%   Objectives  : [1] active power loss in period 1 [kW]
%                 [2] voltage deviation index in period 2 [pu^2]
%                 [3] switching operations between the two topologies
%                 The third objective is what makes the problem a reconfiguration
%                 trade-off rather than two independent single-period problems.
%   Constraints : the period-1 topology must satisfy the voltage window at the
%                 base level and the period-2 topology at the peak level; the
%                 constraint value counts violated periods, so 0 means both
%                 periods are served safely.
%   Reference   : exact. All K^2 pairs are enumerated; objectives come from the
%                 frozen per-topology evaluations (the DNR33 旧版（退役） sweep solver, itself
%                 differentially validated against the upstream Newton-Raphson
%                 implementation), so the Pareto set needs no convergence
%                 argument and is cross-checked by a second dominance filter.
%   Modality    : GLPF. An exact local Pareto certificate over the
%                 single-period-reassignment neighbourhood (move i1 or i2 to any
%                 other pool index) is stored next to the global reference.
    properties(SetAccess = private)
        MP;
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
            d = fullfile(fileparts(mfilename('fullpath')),'data');
            S = load(fullfile(d,'DNR33MP_1.mat'));
            obj.MP = S;   % the snapshot is saved with -struct, so its fields are top-level
            obj.M = 3;
            obj.D = 2;
            obj.encoding = 2*ones(1,obj.D);
            obj.lower = ones(1,obj.D);
            obj.upper = repmat(obj.MP.K, 1, obj.D);
        end
        function X = CalDec(obj,X)
            X = min(repmat(obj.upper,size(X,1),1), max(repmat(obj.lower,size(X,1),1), round(X)));
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
            X = obj.CalDec(X);
            if ~isempty(obj.CacheX) && isequal(size(obj.CacheX),size(X)) && all(obj.CacheX(:) == X(:))
                R = obj.CacheR;
                return;
            end
            i1 = X(:,1); i2 = X(:,2);
            MP = obj.MP;
            R.objs = [MP.lossBase(i1), MP.vdiHeavy(i2), MP.SW(sub2ind([MP.K MP.K], i1, i2))];
            R.cons = (~MP.feasBase(i1)) + (~MP.feasHeavy(i2));
            R.feasible = R.cons == 0;
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
            f = fullfile(fileparts(mfilename('fullpath')),'ref_pf_ps','RWMMOP13_DNR33MP_reference.mat');
            assert(isfile(f), 'RWMMO:ReferenceMissing', 'Run tests/dnr_mp_reference_exact.m to build %s.', f);
            S = load(f,'PS_ref','PF_ref','PF_ref_raw','objLo','objHi');
            assert(size(S.PS_ref,1) == size(S.PF_ref,1) && size(S.PS_ref,1) > 0, 'RWMMO:ReferenceInvalid', 'Malformed reference archive.');
            assert(all(S.objHi > S.objLo), 'RWMMO:ReferenceInvalid', 'Degenerate objective scale.');
            obj.RefPS = S.PS_ref; obj.RefPF = S.PF_ref; obj.RefPFRaw = S.PF_ref_raw;
            obj.ObjLo = S.objLo(:)'; obj.ObjHi = S.objHi(:)';
        end
        function loadLocal(obj)
            f = fullfile(fileparts(mfilename('fullpath')),'ref_pf_ps','RWMMOP13_DNR33MP_local_reference.mat');
            assert(isfile(f), 'RWMMO:ReferenceMissing', 'Run tests/dnr_mp_reference_exact.m to build %s.', f);
            S = load(f,'PS_local','PF_local','PF_local_raw');
            assert(size(S.PS_local,1) == size(S.PF_local,1) && size(S.PS_local,1) > 0, 'RWMMO:ReferenceInvalid', 'Malformed local archive.');
            obj.LocPS = S.PS_local; obj.LocPF = S.PF_local; obj.LocPFRaw = S.PF_local_raw;
        end
    end
end