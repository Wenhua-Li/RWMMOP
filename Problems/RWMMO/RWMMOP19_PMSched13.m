classdef RWMMOP19_PMSched13 < PROBLEM
% <2026> <multi> <integer> <constrained> <multimodal>
% Identical parallel machine scheduling, 13 jobs (P||Cmax, total processing cost).
%
%   Decision    : the machine index of each of 13 jobs, in {1,2,3}; D = 13, so
%                 the design space is exactly 3^13 = 1594323 and fully
%                 enumerable (scale-up of PMSched8（退役） under DEC-20260923-061: the
%                 front is no longer reachable by a few thousand evaluations).
%   Objectives  : [1] makespan, the maximum machine load            (minimise)
%                 [2] total processing cost, machine 1 being the expensive
%                     fast option and machines 2/3 the cheap slow ones (minimise)
%                 The two conflict: balancing loads reduces the makespan but
%                 can increase the total processing cost, and vice versa.
%   Constraints : machine eligibility - job 13 cannot run on machine 1;
%                 the constraint counts violated assignments, so 0 is feasible.
%   Multimodality: machines 2 and 3 have identical processing-time and cost
%                 columns, so exchanging any subset of jobs between them
%                 leaves every machine load and the total cost unchanged,
%                 hence both objectives bit-identical while the decision
%                 vector differs: exact equivalent-multimodality by
%                 construction. Duplicate processing-time values add further
%                 exact ties across machine 1.
%   Reference   : exact over all 1594323 assignments (chunked vectorised
%                 enumeration), cross-checked by a second dominance filter;
%                 the local certificate moves a single job to another
%                 eligible machine.
%   Licence     : P||Cmax is classical public-domain scheduling theory and
%                 the instance is frozen by this project (same position as
%                 WTA44（退役）/RWMMOP13/PMSched8（退役）).
    properties(SetAccess = private)
        PM;
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
            S = load(fullfile(d,'PMSched13_1.mat'));
            obj.PM = S;
            obj.M = 2;
            obj.D = S.nJobs;
            obj.encoding = 2*ones(1,obj.D);
            obj.lower = ones(1,obj.D);
            obj.upper = repmat(S.nMach, 1, obj.D);
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
            X = obj.CalDec(X);
            if ~isempty(obj.CacheX) && isequal(size(obj.CacheX),size(X)) && all(obj.CacheX(:) == X(:))
                R = obj.CacheR;
                return;
            end
            PM = obj.PM;
            nT = size(X,1); nJ = PM.nJobs; nM = PM.nMach;
            % vectorised over rows: machine loads and costs by mask matvecs
            loads = zeros(nT, nM);
            sumC = zeros(nT, 1);
            for m = 1:nM
                mask = double(X == m);                 % nT x nJ
                loads(:,m) = mask * PM.p(:,m);
                sumC = sumC + mask * PM.c(:,m);
            end
            makespan = max(loads, [], 2);
            % eligibility: linear index (m-1)*nJ + j into eligible(nJ x nM)
            idx = (X - 1) * nJ + repmat(1:nJ, nT, 1);
            viol = sum(~PM.eligible(idx), 2);
            R.objs = [makespan, sumC];
            R.cons = viol;
            R.feasible = viol == 0;
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
            f = fullfile(fileparts(mfilename('fullpath')),'ref_pf_ps','RWMMOP19_PMSched13_reference.mat');
            assert(isfile(f), 'RWMMO:ReferenceMissing', 'Run tests/pmsched13_reference_exact.m to build %s.', f);
            S = load(f,'PS_ref','PF_ref','PF_ref_raw','objLo','objHi');
            assert(size(S.PS_ref,1) == size(S.PF_ref,1) && size(S.PS_ref,1) > 0, 'RWMMO:ReferenceInvalid', 'Malformed reference archive.');
            assert(all(S.objHi > S.objLo), 'RWMMO:ReferenceInvalid', 'Degenerate objective scale.');
            obj.RefPS = S.PS_ref; obj.RefPF = S.PF_ref; obj.RefPFRaw = S.PF_ref_raw;
            obj.ObjLo = S.objLo(:)'; obj.ObjHi = S.objHi(:)';
        end
        function loadLocal(obj)
            f = fullfile(fileparts(mfilename('fullpath')),'ref_pf_ps','RWMMOP19_PMSched13_local_reference.mat');
            assert(isfile(f), 'RWMMO:ReferenceMissing', 'Run tests/pmsched13_reference_exact.m to build %s.', f);
            S = load(f,'PS_local','PF_local','PF_local_raw');
            assert(size(S.PS_local,1) == size(S.PF_local,1) && size(S.PS_local,1) > 0, 'RWMMO:ReferenceInvalid', 'Malformed local archive.');
            obj.LocPS = S.PS_local; obj.LocPF = S.PF_local; obj.LocPFRaw = S.PF_local_raw;
        end
    end
end
