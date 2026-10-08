classdef RWMMOP2_Jobshop5 < PROBLEM
% <2026> <multi> <integer> <multimodal> <constrained/none>
% Energy-aware flexible job-shop scheduling prototype (5 jobs, 11 machines).
%
%   Decision    : 18 job-label variables repaired to a legal operation
%                 sequence (each job appears exactly its operation count) plus
%                 18 machine-choice variables; D = 36.
%   Objectives  : [1] idle-machine-penalised makespan
%                 [2] idle-machine-penalised average power (total power over
%                 makespan); both are multiplied by (unused machines + 1), so
%                 a schedule that leaves machines idle pays on both axes
%                 (minimise). CalObj is the frozen affine image of CalObjRaw.
%   Constraints : none explicit; the repair in CalDec makes every evaluated
%                 solution a legal schedule.
%   Reference   : high-budget-approx; the archive was grown 106->163 rows by
%                 six independent seeds and declared converged after six
%                 further zero-gain seeds (results/jobshop/stability_curve.csv).
%   Modality    : EM - 163 exact tie groups, equivalence verified by
%                 single-dimension perturbations (4111 candidates, 878
%                 bit-identical); see metadata/modality_certificates.json.
%   Licence     : BSD-style Yarpiz licence (license_audit.json).

    properties(SetAccess = private)
        J;
        OpCount;
        ObjLo;
        ObjHi;
    end
    methods
        function Setting(obj)
            obj.M = 2;
            dataFile = fullfile(fileparts(mfilename('fullpath')),'data','Jobshop5_1.mat');
            S = load(dataFile,'J','objLo','objHi');
            obj.J = S.J;
            obj.ObjLo = S.objLo; obj.ObjHi = S.objHi;
            obj.OpCount = arrayfun(@(s)s.num_gongxu,obj.J.info);
            obj.D = 2*sum(obj.OpCount);
            obj.encoding = [3*ones(1,obj.D/2),2*ones(1,obj.D/2)];
            obj.lower = [ones(1,obj.D/2),ones(1,obj.D/2)];
            obj.upper = [obj.J.I*ones(1,obj.D/2),4*ones(1,obj.D/2)];
        end
        function X = CalDec(obj,X)
            nOp = obj.D/2;
            X(:,1:nOp) = min(obj.J.I,max(1,round(X(:,1:nOp))));
            X(:,nOp+1:end) = max(1,round(X(:,nOp+1:end)));
            for p = 1:size(X,1)
                jobs = X(p,1:nOp);
                % Repair the operation sequence to contain each job's exact
                % number of operations while preserving the sampled order.
                keep = false(1,nOp);
                seen = zeros(1,obj.J.I);
                for k = 1:nOp
                    j = jobs(k);
                    if seen(j) < obj.OpCount(j)
                        seen(j) = seen(j)+1;
                        keep(k) = true;
                    end
                end
                missing = repelem(1:obj.J.I,obj.OpCount-seen);
                jobs(~keep) = missing;
                X(p,1:nOp) = jobs;
                curs = zeros(1,obj.J.I);
                for k = 1:nOp
                    j = jobs(k); curs(j) = curs(j)+1;
                    nMach = obj.J.info(j).gongxu(curs(j)).num_jichuang;
                    X(p,nOp+k) = min(nMach,max(1,X(p,nOp+k)));
                end
            end
        end
        function PopObj = CalObj(obj,X)
            % Normalised with the constants frozen in the data snapshot.
            PopObj = rwmmo_normalize_objectives(obj.CalObjRaw(X), obj.ObjLo, obj.ObjHi);
        end
        function PopObjRaw = CalObjRaw(obj,X)
            X = obj.CalDec(X);
            nOp = obj.D/2;
            PopObjRaw = zeros(size(X,1),obj.M);
            for p = 1:size(X,1)
                PopObjRaw(p,:) = obj.evaluateOne(X(p,1:nOp),X(p,nOp+1:end));
            end
        end
        function R = GetObjectiveScale(obj)
            R = [obj.ObjLo(:)'; obj.ObjHi(:)'];
        end
        function R = GetOptimum(obj,~)
            % The frozen archive as-is (uniform convention across RWMMO).
            S = load(fullfile(fileparts(mfilename('fullpath')),'ref_pf_ps','RWMMOP2_Jobshop5_reference.mat'),'PF_ref');
            R = S.PF_ref;
        end
        function R = GetPF(obj)
            S = load(fullfile(fileparts(mfilename('fullpath')),'ref_pf_ps','RWMMOP2_Jobshop5_reference.mat'),'PF_ref');
            R = S.PF_ref;
        end
        function R = GetPS(obj)
            S = load(fullfile(fileparts(mfilename('fullpath')),'ref_pf_ps','RWMMOP2_Jobshop5_reference.mat'),'PS_ref');
            R = S.PS_ref;
        end
        function R = GetPFRaw(obj)
            S = load(fullfile(fileparts(mfilename('fullpath')),'ref_pf_ps','RWMMOP2_Jobshop5_reference.mat'),'PF_ref_raw');
            R = S.PF_ref_raw;
        end
        function score = CalMetric(obj,metName,Population)
            if strcmp(metName,'IGDX')
                S = load(fullfile(fileparts(mfilename('fullpath')),'ref_pf_ps','RWMMOP2_Jobshop5_reference.mat'),'PS_ref');
                score = feval(metName,Population,S.PS_ref);
            else
                score = CalMetric@PROBLEM(obj,metName,Population);
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
        function S = schedule(obj,jobs,machines)
        %SCHEDULE Decode one repaired sequence into a machine timeline.
        %   Single source of truth shared by the objectives and the gantt
        %   renderer (viz\rwmmo_render_gantt_jobshop): evaluateOne consumes
        %   exactly this structure, so the drawn schedule can never drift
        %   from the evaluated objectives. jobs is the 1 x nOp job sequence
        %   (each job appearing exactly its OpCount times), machines the
        %   1 x nOp machine choices.
            nOp = numel(jobs);
            release = zeros(1,obj.J.M);
            tStart = zeros(obj.J.I,max(obj.OpCount));
            tEnd = zeros(obj.J.I,max(obj.OpCount));
            machineCode = zeros(obj.J.I,max(obj.OpCount));
            opJobs = zeros(1,nOp);
            opIdx = zeros(1,nOp);
            countOp = ones(1,obj.J.I);
            countMachine = zeros(1,obj.J.M);
            pProcess = 0; pTool = 0; pIdle = 0;
            for k = 1:nOp
                j = jobs(k); op = countOp(j); countOp(j) = op+1;
                opJobs(k) = j; opIdx(k) = op;
                machChoice = machines(k);
                opData = obj.J.info(j).gongxu(op);
                mCode = opData.bianhao(machChoice);
                machineCode(j,op) = mCode;
                countMachine(mCode) = countMachine(mCode)+1;
                if op == 1
                    start = max(release(mCode),obj.J.Ai(j));
                else
                    start = max(release(mCode),tEnd(j,op-1));
                end
                if release(mCode) < start
                    idle = start-release(mCode);
                    pIdle = pIdle+idle*obj.J.m_power(mCode,1);
                end
                if op == 1
                    need = obj.J.Ni(j)*sum(opData.data(machChoice,2:3));
                else
                    need = obj.J.Ni(j)*opData.data(machChoice,2);
                end
                tStart(j,op) = start; tEnd(j,op) = start+need;
                release(mCode) = tEnd(j,op);
                pProcess = pProcess+opData.data(machChoice,1)*obj.J.Ni(j);
                pTool = pTool+opData.data(machChoice,3)*obj.J.m_power(mCode,2)*obj.J.Ni(j);
            end
            S.tStart = tStart;
            S.tEnd = tEnd;
            S.machineCode = machineCode;
            S.jobs = jobs;
            S.machines = machines;
            S.opJobs = opJobs;
            S.opIdx = opIdx;
            S.makespan = max(release);
            S.totalProcessPower = pProcess;
            S.totalToolPower = pTool;
            S.totalIdlePower = pIdle;
            S.totalPower = pProcess+pTool+pIdle;
            S.unusedMachines = obj.J.M-sum(countMachine>0);
            S.machineLoad = countMachine;
        end
    end
    methods(Access = private)
        function y = evaluateOne(obj,jobs,machines)
            S = obj.schedule(jobs,machines);
            factor = S.unusedMachines+1;
            y = factor*[S.makespan, S.totalPower/max(S.makespan,eps)];
        end
    end
end
