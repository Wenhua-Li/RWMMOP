classdef RWMMOP11_DNR69 < PROBLEM
% <2026> <multi> <binary> <constrained> <multimodal>
% Radial distribution network reconfiguration on the frozen IEEE 69-bus test feeder.
%
%   Decision    : one binary state per branch (73 sectionalising and tie
%                 switches), repaired to a spanning tree so that every evaluated
%                 solution is a valid radial configuration
%   Objectives  : [1] total active power loss [kW]
%                 [2] voltage deviation index sum_i (1-|V_i|)^2
%                 [3] switching operations against the initial configuration
%                 CalObj returns these three mapped affinely onto the exact
%                 Pareto range, because the raw units differ by four orders of
%                 magnitude and degenerate reference-vector algorithms. CalObjRaw
%                 returns engineering units. The map preserves dominance and the
%                 Pareto set exactly; the frozen constants are objLo/objHi.
%   Constraints : bus voltage magnitude inside [0.93, 1.05] pu. Topologies whose
%                 power flow diverges are infeasible and receive a dominated
%                 penalty point. The published line MVA limits are retained in
%                 the snapshot but are not enforceable, see rwmmo_dnr_dataset.m.
%   Reference   : exact. The feasible topology space is precisely the set of
%                 spanning trees of the feeder graph (407924 of them, 28026 feasible),
%                 so the Pareto set comes from exhaustive enumeration
%                 cross-checked against the Kirchhoff matrix-tree count.
%   Modality    : GLPF. An exact local Pareto certificate over the single
%                 branch-exchange neighbourhood is stored next to the global
%                 reference and exposed through GetPSLocal/GetPFLocal.
%
%   Power flow is a constant-PQ backward/forward sweep validated against the
%   upstream Newton-Raphson implementation (tests/dnr_data_audit.m,
%   tests/dnr_differential_powerflow.m).

    methods(Access = private)
        function s = dataFile(~)
            s = 'DNR69_1.mat';
        end
        function s = classFile(~)
            s = 'RWMMOP11_DNR69';
        end
    end

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
            obj.M = 3;
            S = load(fullfile(fileparts(mfilename('fullpath')),'data',obj.dataFile()),'F');
            obj.F = S.F;
            obj.D = obj.F.nBranch;
            obj.encoding = 4*ones(1,obj.D);
            obj.lower = zeros(1,obj.D);
            obj.upper = ones(1,obj.D);
        end
        function X = CalDec(obj,X)
            % Every evaluated solution is a valid radial topology: switch
            % states are repaired to a spanning tree by Kruskal preference.
            X = double(rwmmo_dnr_repair(X, obj.F.branchFrom, obj.F.branchTo, obj.F.nbus));
            obj.CacheX = []; obj.CacheR = [];
        end
        function PopObj = CalObj(obj,X)
            % Normalised objectives; see rwmmo_dnr_normalize for the rationale.
            PopObj = rwmmo_dnr_normalize(obj.evaluate(X).objs, obj.scaleLo(), obj.scaleHi());
        end
        function PopObjRaw = CalObjRaw(obj,X)
            % Raw engineering units: [loss kW, voltage deviation index, switching ops].
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
            if ~isempty(obj.CacheX) && isequal(size(obj.CacheX),size(X)) && all(obj.CacheX(:) == X(:))
                R = obj.CacheR;
                return;
            end
            R = rwmmo_dnr_objectives(X, obj.F, false);
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
                [obj.classFile() '_reference.mat']);
            assert(isfile(f), 'RWMMO:ReferenceMissing', ...
                'Run tests/dnr_reference_exact.m to build %s.', f);
            S = load(f,'PS_ref','PF_ref','PF_ref_raw','objLo','objHi');
            assert(size(S.PS_ref,1) == size(S.PF_ref,1) && size(S.PS_ref,1) > 0, ...
                'RWMMO:ReferenceInvalid', 'Malformed reference archive.');
            assert(all(S.objHi > S.objLo), 'RWMMO:ReferenceInvalid', 'Degenerate objective scale.');
            obj.RefPS = S.PS_ref; obj.RefPF = S.PF_ref; obj.RefPFRaw = S.PF_ref_raw;
            obj.ObjLo = S.objLo(:)'; obj.ObjHi = S.objHi(:)';
        end
        function loadLocal(obj)
            f = fullfile(fileparts(mfilename('fullpath')),'ref_pf_ps', ...
                [obj.classFile() '_local_reference.mat']);
            assert(isfile(f), 'RWMMO:ReferenceMissing', ...
                'Run tests/dnr_local_pareto_audit.m to build %s.', f);
            S = load(f,'PS_local','PF_local','PF_local_raw');
            assert(size(S.PS_local,1) == size(S.PF_local,1) && size(S.PS_local,1) > 0, ...
                'RWMMO:ReferenceInvalid', 'Malformed local reference archive.');
            obj.LocPS = S.PS_local; obj.LocPF = S.PF_local; obj.LocPFRaw = S.PF_local_raw;
        end
    end
end
