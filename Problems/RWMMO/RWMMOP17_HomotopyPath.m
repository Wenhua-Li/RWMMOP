classdef RWMMOP17_HomotopyPath < PROBLEM
% <2026> <multi> <real> <constrained> <multimodal>
% Continuous waypoint path planning through a frozen obstacle field (RWMMOP17).
%
%   Decision    : K = 6 free waypoint coordinates in km, D = 12, inside a
%                 [0,10] x [0,7] box; the polyline start-waypoints-goal is
%                 the realised path (start/goal frozen on the mirror axis).
%   Objectives  : [1] polyline length [km]
%                 [2] risk exposure [km^2]: per obstacle, sum over segments
%                 of max(0, (r+margin) - point-segment distance)^2
%                 CalObj returns these mapped affinely onto the archived
%                 Pareto range (constants frozen in the reference archive);
%                 CalObjRaw returns engineering units.
%   Constraints : one signed violation per obstacle (four): the maximum over
%                 the path segments of (r - point-segment distance).
%   Reference   : homotopy-certified (new level, protocol v0.5): the four
%                 side-sign homotopy classes at the two axis circles are
%                 enumerated explicitly, each class front is grown by a
%                 class-restricted structured search until three consecutive
%                 zero eps-cell-gain seeds, and the archive is the
%                 nondominated union of the class fronts.
%   Modality    : MIX expected. EM: mirroring y -> 7 - y preserves endpoints,
%                 obstacle set and both objectives, so every path owns a
%                 mirror partner with identical objectives (multiplicity 2,
%                 cap 8). GLPF: the homotopy classes are separated by
%                 infeasible crossings, so each class is a local Pareto
%                 region under the 0.25 km single-waypoint relocation lattice
%                 (local certificate archived).
%
%   Point-segment geometry and the risk model are classical public-domain
%   motion planning; the field geometry is original to this project.

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
            S = load(fullfile(fileparts(mfilename('fullpath')),'data','HomotopyPath_1.mat'));
            obj.F = S;
            obj.D = 2 * S.K;
            obj.encoding = ones(1, obj.D);
            obj.lower = repmat(S.boxLower, 1, S.K);
            obj.upper = repmat(S.boxUpper, 1, S.K);
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
            R = rwmmo_homotopypath_objectives(X, obj.F);
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
                'RWMMOP17_HomotopyPath_reference.mat');
            assert(isfile(f), 'RWMMO:ReferenceMissing', ...
                'Run tests/homotopypath_reference_build.m to build %s.', f);
            S = load(f,'PS_ref','PF_ref','PF_ref_raw','objLo','objHi');
            assert(size(S.PS_ref,1) == size(S.PF_ref,1) && size(S.PS_ref,1) > 0, ...
                'RWMMO:ReferenceInvalid', 'Malformed reference archive.');
            assert(all(S.objHi > S.objLo), 'RWMMO:ReferenceInvalid', 'Degenerate objective scale.');
            obj.RefPS = S.PS_ref; obj.RefPF = S.PF_ref; obj.RefPFRaw = S.PF_ref_raw;
            obj.ObjLo = S.objLo(:)'; obj.ObjHi = S.objHi(:)';
        end
        function loadLocal(obj)
            f = fullfile(fileparts(mfilename('fullpath')),'ref_pf_ps', ...
                'RWMMOP17_HomotopyPath_local_reference.mat');
            assert(isfile(f), 'RWMMO:ReferenceMissing', ...
                'Run tests/homotopypath_reference_build.m to build %s.', f);
            S = load(f,'PS_local','PF_local','PF_local_raw');
            assert(size(S.PS_local,1) == size(S.PF_local,1) && size(S.PS_local,1) > 0, ...
                'RWMMO:ReferenceInvalid', 'Malformed local reference archive.');
            obj.LocPS = S.PS_local; obj.LocPF = S.PF_local; obj.LocPFRaw = S.PF_local_raw;
        end
    end
end
