classdef RWMMOP1_SatelliteTTC25 < PROBLEM
% <2026> <multi> <integer> <large> <multimodal> <constrained/none>
% Official problem RWMMOP1 (satellite TT&C scheduling, case_25). Multimodality
% certificate: EM - 35 exact tie groups built on measured neutral dimensions
% and frozen by tests/generate_satellite_full_reference.m. Reference tier:
% high-budget-approx (181 rows, caveat retained: no convergence criterion
% yet), so metric values are comparative, not ground-truth errors. Unexecuted
% requests reduce reward in the legacy decoder and con is identically zero,
% so formal results must also report executedRequests.
    properties(SetAccess = private)
        Case;
        Offsets;
        TaskCount;
        ModelVersion = 'ttc25-legacy-compact-v1';
    end
    properties(Access = private)
        RefPS = [];
        RefPF = [];
        RefPFRaw = [];
    end
    methods
        function Setting(obj)
            obj.M = 2;
            obj.Case = load(fullfile(fileparts(mfilename('fullpath')),'data',obj.dataFile()));
            assert(all(obj.Case.NeedLap <= obj.Case.Nlap));
            assert(isfield(obj.Case,'objLo') && isfield(obj.Case,'objHi'), ...
                'RWMMO:ObjectiveScale','Run tests/rwmmo_freeze_objective_scaling.m first.');
            obj.Offsets = [0 cumsum(obj.Case.NeedLap)];
            obj.TaskCount = obj.Offsets(end);
            obj.D = 2*obj.TaskCount;
            obj.encoding = 2*ones(1,obj.D);
            obj.lower = ones(1,obj.D);
            obj.upper = [repelem(obj.Case.Nlap,obj.Case.NeedLap), ...
                obj.Case.Nequ*ones(1,obj.TaskCount)];
        end
        function X = CalDec(obj,X)
            assert(isnumeric(X) && size(X,2)==obj.D && all(isfinite(X(:))), ...
                'RWMMO:InvalidDecision','Expected finite N-by-D decisions.');
            X = min(obj.upper,max(obj.lower,round(X)));
            for p=1:size(X,1)
                for i=1:obj.Case.Nreq
                    slots = obj.Offsets(i)+1:obj.Offsets(i+1);
                    laps = X(p,slots);
                    used = false(1,obj.Case.Nlap(i));
                    for k=1:numel(slots)
                        if used(laps(k)), laps(k)=find(~used,1); end
                        used(laps(k))=true;
                    end
                    % Canonical chronological order, with equipment carried
                    % alongside the lap. No unused padding dimensions.
                    [laps,order] = sort(laps);
                    equipment = X(p,obj.TaskCount+slots);
                    X(p,slots)=laps;
                    X(p,obj.TaskCount+slots)=equipment(order);
                end
            end
        end
        function Population = Initialization(obj,N)
            if nargin < 2, N = obj.N; end
            X = zeros(N,obj.D); s = obj.Case.Nreq;
            for p=1:N
                for i=1:s
                    k=obj.Case.NeedLap(i); slots=obj.Offsets(i)+1:obj.Offsets(i+1);
                    selected=[];
                    for trial=1:100
                        cand=sort(randperm(obj.Case.Nlap(i),k)); lift=obj.Case.islift(i,cand);
                        if sum(lift)>=obj.Case.nLift(i) && sum(~lift)>=obj.Case.nDesc(i), selected=cand; break; end
                    end
                    if isempty(selected), selected=sort(randperm(obj.Case.Nlap(i),k)); end
                    X(p,slots)=selected;
                    for z=1:k
                        idx=sum(obj.Case.Nlap(1:i-1))+selected(z); visible=find(obj.Case.isVisi(idx,:)>0);
                        if isempty(visible), visible=1:obj.Case.Nequ; end
                        X(p,obj.TaskCount+slots(z))=visible(randi(numel(visible)));
                    end
                end
            end
            Population=obj.Evaluation(X);
        end
        function q = Decode(obj,X)
            X = obj.CalDec(X);
            template = struct('laps',{cell(obj.Case.Nreq,1)}, ...
                'equip',{cell(obj.Case.Nreq,1)});
            q = repmat(template,1,size(X,1));
            for p=1:size(X,1)
                for i=1:obj.Case.Nreq
                    slots=obj.Offsets(i)+1:obj.Offsets(i+1);
                    q(p).laps{i}=X(p,slots);
                    q(p).equip{i}=X(p,obj.TaskCount+slots);
                end
            end
        end
        function PopObj = CalObj(obj,X)
            % Normalised with the constants frozen in the data snapshot.
            PopObj = rwmmo_normalize_objectives(obj.CalObjRaw(X), obj.Case.objLo, obj.Case.objHi);
        end
        function R = GetObjectiveScale(obj)
            R = [obj.Case.objLo(:)'; obj.Case.objHi(:)'];
        end
        function PopObj = CalObjRaw(obj,X)
            q=obj.Decode(X);
            PopObj=zeros(size(X,1),2);
            if isempty(q),return;end
            out=satellite_calobj_legacy(q,obj.Case);
            for p=1:numel(out),PopObj(p,:)=out(p).obj(:)';end
        end
        function R=GetOptimum(obj,~)
            % The frozen archive as-is (uniform convention across RWMMO).
            R=obj.referencePF();
        end
        function R=GetPF(obj)
            R=obj.referencePF();
        end
        function R=GetPS(obj)
            R=obj.referencePS();
        end
        function R=GetPFRaw(obj)
            R=obj.referencePFRaw();
        end
        function score=CalMetric(obj,metName,Population)
            if strcmp(metName,'IGDX')
                score=feval(metName,Population,obj.referencePS());
            elseif strcmp(metName,'Feasible_rate')
                score=feval(metName,Population,[]);
            else
                score=CalMetric@PROBLEM(obj,metName,Population);
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
    methods(Access = protected)
        function s = dataFile(~)
            s = 'SatelliteTTC25_full.mat';
        end
        function s = classFile(~)
            s = 'RWMMOP1_SatelliteTTC25';
        end
    end
    methods(Access = private)
        function loadReference(obj)
            f = fullfile(fileparts(mfilename('fullpath')),'ref_pf_ps',sprintf('%s_full_reference.mat',obj.classFile()));
            assert(isfile(f), 'RWMMO:ReferenceMissing', ...
                'Run tests/generate_satellite_full_reference.m (or generate_satellite50_reference.m) to build %s.', f);
            S = load(f,'PS_ref','PF_ref','PF_ref_raw');
            assert(size(S.PS_ref,1)==size(S.PF_ref,1) && size(S.PS_ref,1)>0, ...
                'RWMMO:ReferenceInvalid','Malformed satellite reference archive.');
            obj.RefPS = S.PS_ref; obj.RefPF = S.PF_ref; obj.RefPFRaw = S.PF_ref_raw;
        end
        function PS = referencePS(obj)
            if isempty(obj.RefPS), obj.loadReference(); end
            PS = obj.RefPS;
        end
        function PF = referencePF(obj)
            if isempty(obj.RefPF), obj.loadReference(); end
            PF = obj.RefPF;
        end
        function PF = referencePFRaw(obj)
            if isempty(obj.RefPFRaw), obj.loadReference(); end
            PF = obj.RefPFRaw;
        end
    end
end
