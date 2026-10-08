classdef RWMMOP14_Net12Sparse < PROBLEM
    % <2026> <multi> <binary> <constrained> <multimodal>
    % Twelve-node microgrid network design over a frozen sparse candidate set.
    %
    %   Decision    : one binary variable per candidate corridor (K=21 of them),
    %                 i.e. which of the K shortest candidate edges are built. The
    %                 candidate set is a frozen planning restriction (right-of-way
    %                 availability), recorded in data/Net12Sparse_1.mat; over it
    %                 the design space is exactly 2^21 = 2097152 and therefore
    %                 fully enumerable, which is what makes an exact reference
    %                 possible. Scale-up replacement of NetworkDesign8Sparse（退役） (RWMMO_NetworkDesign8
    %                 Sparse, 2^15) under DEC-20260923-061: the feasible connected
    %                 set and the resilience objective are far beyond a few
    %                 thousand evaluations, so the front is no longer reachable by
    %                 a small budget while the reference stays exact.
    %   Objectives  : [1] total line length sum of built corridor lengths [km],
    %                     the investment cost
    %                 [2] bridge exposure sum_e unreach(G - e): over every built
    %                     edge, the number of unordered node pairs left
    %                     unreachable after removing that single edge, summed.
    %                     Only bridges of a connected design contribute, so the
    %                     metric rewards redundancy (trees worst, cycle-rich
    %                     networks best). Both objectives are minimised. Computed
    %                     by rwmmo_net12_objectives.
    %   Constraints : the intact network must connect all twelve nodes; the
    %                 constraint value is the number of unreachable unordered
    %                 pairs before any failure, so 0 means connected/feasible.
    %   Reference   : exact. All 2^K candidate subsets are enumerated; the Pareto
    %                 set of the connected ones is cross-checked by an independent
    %                 2-D sort-and-sweep filter before anything is written.
    %   Modality    : GLPF. An exact local Pareto certificate over the single-edge
    %                 flip neighbourhood (build or remove one candidate edge) is
    %                 stored next to the global reference.
    properties(SetAccess = private)
        MCS;
        Cand;
        CandLen;
        K;
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
            S = load(fullfile(d,'Net12Sparse_1.mat'));
            obj.MCS = S.MCS;
            obj.Cand = S.candEdges;
            obj.CandLen = S.candidateLengths(:);
            obj.K = size(obj.Cand,1);
            assert(obj.K == S.K, 'RWMMO:Net12Sparse', 'Candidate count disagrees with the snapshot.');
            obj.M = 2;
            obj.D = obj.K;
            obj.encoding = 4*ones(1,obj.D);
            obj.lower = zeros(1,obj.D);
            obj.upper = ones(1,obj.D);
        end
        function X = CalDec(obj,X)
            X = double(logical(min(1,max(0,round(X)))));
            obj.CacheX = []; obj.CacheR = [];
        end
        function A = ToAdjacency(obj,X)
            X = obj.CalDec(X);
            N = obj.MCS.N;
            A = false(size(X,1), N, N);
            for p = 1:size(X,1)
                Ap = false(N,N);
                e = find(X(p,:) ~= 0);
                Ap(sub2ind([N N], obj.Cand(e,1), obj.Cand(e,2))) = true;
                Ap(sub2ind([N N], obj.Cand(e,2), obj.Cand(e,1))) = true;
                A(p,:,:) = Ap;
            end
        end
        function PopObj = CalObj(obj,X)
            PopObj = rwmmo_normalize_objectives(obj.CalObjRaw(X), obj.scaleLo(), obj.scaleHi());
        end
        function PopObjRaw = CalObjRaw(obj,X)
            R = obj.evaluate(X);
            PopObjRaw = R.objs;
        end
        function PopCon = CalCon(obj,X)
            R = obj.evaluate(X);
            PopCon = R.cons;
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
            N = obj.MCS.N;
            [Y, unreach] = rwmmo_net12_objectives(X, obj.Cand, obj.CandLen, N);
            R.objs = Y;
            R.cons = unreach;
            R.unreach = unreach;
            R.connected = unreach == 0;
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
            f = fullfile(fileparts(mfilename('fullpath')),'ref_pf_ps','RWMMOP14_Net12Sparse_reference.mat');
            assert(isfile(f), 'RWMMO:ReferenceMissing', 'Run tests/net12sparse_reference_exact.m to build %s.', f);
            S = load(f,'PS_ref','PF_ref','PF_ref_raw','objLo','objHi');
            assert(size(S.PS_ref,1) == size(S.PF_ref,1) && size(S.PS_ref,1) > 0, 'RWMMO:ReferenceInvalid', 'Malformed reference archive.');
            assert(all(S.objHi > S.objLo), 'RWMMO:ReferenceInvalid', 'Degenerate objective scale.');
            obj.RefPS = S.PS_ref; obj.RefPF = S.PF_ref; obj.RefPFRaw = S.PF_ref_raw;
            obj.ObjLo = S.objLo(:)'; obj.ObjHi = S.objHi(:)';
        end
        function loadLocal(obj)
            f = fullfile(fileparts(mfilename('fullpath')),'ref_pf_ps','RWMMOP14_Net12Sparse_local_reference.mat');
            assert(isfile(f), 'RWMMO:ReferenceMissing', 'Run tests/net12sparse_reference_exact.m to build %s.', f);
            S = load(f,'PS_local','PF_local','PF_local_raw');
            assert(size(S.PS_local,1) == size(S.PF_local,1) && size(S.PS_local,1) > 0, 'RWMMO:ReferenceInvalid', 'Malformed local archive.');
            obj.LocPS = S.PS_local; obj.LocPF = S.PF_local; obj.LocPFRaw = S.PF_local_raw;
        end
    end
end
