classdef RWMMOP20_BiTree12 < PROBLEM
% <2026> <multi> <binary> <constrained> <multimodal>
% Bi-criterion degree-bounded spanning tree on a frozen 12-node 24-edge graph.
%
%   Decision    : one binary variable per edge of the frozen 12-node,
%                 24-edge graph (cycle plus twelve chords); D = 24. A design
%                 is feasible when the selected edges form a spanning tree
%                 (exactly 11 edges, connected) and no node exceeds the
%                 degree bound 3. Scale-up of BiTree8（退役） under DEC-20260923-061:
%                 the size-11 subset space is C(24,11) = 2496144, still
%                 exactly enumerable but far beyond a few thousand
%                 evaluations.
%   Objectives  : [1] total cost under weight set A (construction cost)
%                 [2] total cost under weight set B (maintenance cost)
%                 (both minimise; CalObj maps affinely onto the exact
%                 Pareto range, constants frozen in the reference archive)
%   Constraints : one signed violation: (1 - isTree) + degreeViol, so 0 is
%                 feasible; non-tree selections are infeasible by constraint
%                 (edge count and connectivity are checked), which keeps the
%                 feasible set exactly the bounded-degree spanning trees.
%   Multimodality: two chord pairs carry identical (wA,wB) weights, so a
%                 tree containing one member can often exchange it for the
%                 other with both objectives bit-identical while the
%                 decision vector differs: exact equivalent-multimodality by
%                 construction (same position as BiTree8（退役）).
%   Reference   : exact. All C(24,11) size-11 subsets are enumerated with
%                 vectorised degree and connectivity filters and the Pareto
%                 set is cross-checked by a second dominance filter; the
%                 local certificate uses the single edge-exchange
%                 neighbourhood over every feasible tree.
%   Licence     : the bi-criterion spanning tree model is classical
%                 public-domain combinatorial optimisation and the instance
%                 is frozen by this project (same position as WTA44（退役）/RWMMOP13/BiTree8（退役）).
    properties(SetAccess = private)
        BT;
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
            S = load(fullfile(d,'BiTree12_1.mat'));
            obj.BT = S;
            obj.M = 2;
            obj.D = S.nEdges;
            obj.encoding = 4*ones(1,obj.D);
            obj.lower = zeros(1,obj.D);
            obj.upper = ones(1,obj.D);
        end
        function X = CalDec(obj,X)
            X = min(1, max(0, round(X)));
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
            BT = obj.BT;
            nT = size(X,1);
            fA = X * BT.wA(:);
            fB = X * BT.wB(:);
            isTree = zeros(nT,1);
            degViol = zeros(nT,1);
            for t = 1:nT
                e = find(X(t,:) ~= 0);
                [isTree(t), degViol(t)] = treeCheck12(e, BT);
            end
            R.objs = [fA, fB];
            R.cons = (1 - isTree) + degViol;
            R.feasible = R.cons == 0;
            R.isTree = isTree;
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
            f = fullfile(fileparts(mfilename('fullpath')),'ref_pf_ps','RWMMOP20_BiTree12_reference.mat');
            assert(isfile(f), 'RWMMO:ReferenceMissing', 'Run tests/bitree12_reference_exact.m to build %s.', f);
            S = load(f,'PS_ref','PF_ref','PF_ref_raw','objLo','objHi');
            assert(size(S.PS_ref,1) == size(S.PF_ref,1) && size(S.PS_ref,1) > 0, 'RWMMO:ReferenceInvalid', 'Malformed reference archive.');
            assert(all(S.objHi > S.objLo), 'RWMMO:ReferenceInvalid', 'Degenerate objective scale.');
            obj.RefPS = S.PS_ref; obj.RefPF = S.PF_ref; obj.RefPFRaw = S.PF_ref_raw;
            obj.ObjLo = S.objLo(:)'; obj.ObjHi = S.objHi(:)';
        end
        function loadLocal(obj)
            f = fullfile(fileparts(mfilename('fullpath')),'ref_pf_ps','RWMMOP20_BiTree12_local_reference.mat');
            assert(isfile(f), 'RWMMO:ReferenceMissing', 'Run tests/bitree12_reference_exact.m to build %s.', f);
            S = load(f,'PS_local','PF_local','PF_local_raw');
            assert(size(S.PS_local,1) == size(S.PF_local,1) && size(S.PS_local,1) > 0, 'RWMMO:ReferenceInvalid', 'Malformed local archive.');
            obj.LocPS = S.PS_local; obj.LocPF = S.PF_local; obj.LocPFRaw = S.PF_local_raw;
        end
    end
end
function [isTree, degViol] = treeCheck12(e, BT)
% A selection is a spanning tree iff it has n-1 edges and connects all nodes.
n = BT.nNodes;
isTree = 0;
deg = zeros(1,n);
for k = 1:numel(e)
    deg(BT.from(e(k))) = deg(BT.from(e(k))) + 1;
    deg(BT.to(e(k))) = deg(BT.to(e(k))) + 1;
end
degViol = sum(max(0, deg - BT.maxDeg));
if numel(e) ~= n-1
    return;
end
comp = zeros(1,n); g = 0;
for s = 1:n
    if comp(s), continue; end
    g = g + 1; comp(s) = g; stack = s;
    while ~isempty(stack)
        u = stack(end); stack(end) = [];
        for k = 1:numel(e)
            v = 0;
            if BT.from(e(k)) == u, v = BT.to(e(k)); end
            if BT.to(e(k)) == u, v = BT.from(e(k)); end
            if v && ~comp(v)
                comp(v) = g; stack(end+1) = v; %#ok<AGROW>
            end
        end
    end
end
isTree = (g == 1);
end
