classdef RWMMOP16_BlendPool < PROBLEM
% <2026> <multi> <real> <constrained> <multimodal>
% Feed-stock pooling and blending under product quality contracts (RWMMO RWMMOP16).
%
%   Decision    : x = (uA, uB, v1) - the two pool feed rates and the pool-to-P1
%                 flow. v2 = uA+uB-v1, w1 = D1-v1 and w2 = D2-v2 close the
%                 balances, so the made-to-order demands are met exactly.
%                 CalDec clamps to the box and snaps v1 to the nearest BATCH
%                 DETENT (multiples of G.v1Detent = 25: the contracts ship in
%                 25-unit railcar batches and the pool-to-P1 valve has the
%                 four physical detents {0, 25, 50, 75}; revision 2026-09-30,
%                 DEC-20260930-068). Every evaluated row is a complete
%                 operating plan. The pooling NETWORK SHAPE is the classical
%                 process-engineering pooling problem; the instance constants
%                 are frozen by this project (tests/blendpool_instance.m).
%   Objectives  : [1] total feed cost       (currency units, tiered in uA:
%                 6 for the first 45 units of A, 8 beyond - a capacity
%                 surcharge tier that puts a knee in the image front)
%                 [2] total sulphur delivered (sulphur units)
%                 Both are computed from the reduced form in (uA,uB) ONLY -
%                 the map is injective and neither objective sees v1.
%                 CalObjRaw returns raw units; CalObj is the affine image
%                 under constants frozen into the snapshot by
%                 tests/blendpool_reference_exact.m from the certified front.
%   Constraints : five signed violations (<= 0 feasible): the two BILINEAR
%                 product-quality limits (pool sulphur times pool flow plus
%                 bypass sulphur times bypass flow against the twin contract
%                 specs) and three flow limits (v2, w2, w1+w2 non-negative).
%                 Feeds: A tiered (6/8, sulphur 3), B (13, sulphur 1) through
%                 the pool; C (11, sulphur 1.4) bypasses it; twin products
%                 (demand 75, spec 2.2) each.
%   Reference   : certified-dense. Because domination never depends on v1, the
%                 problem reduces exactly to the 2-D footprint F = {(uA,uB) :
%                 the v1 interval contains at least one detent}; a 0.25 raster
%                 decides F exactly at every node through the closed-form
%                 interval test plus the detent test, the archive is the
%                 eps-front at (1.0, 0.2) per axis, and with Lipschitz
%                 constants sqrt(29), sqrt(2) the archive is within
%                 eps + L*h*sqrt(2)/2 per axis of the true front. The
%                 eps-dominance of every feasible raster node is verified by
%                 the builder, and the bound numbers live in the archive
%                 metadata.
%   Modality    : EM. The objectives are computed from the algebraically
%                 reduced form (uA,uB only), so every archived point owns an
%                 exact tie set in v1 - the finite detent set inside its
%                 feasible interval - and the arithmetic never sees v1: all
%                 detents of one tie set are bit-identical by construction
%                 and pairwise 25 units apart (1/3 of the v1 range, above
%                 the frozen far threshold deltaFar = 0.2), i.e. isolated FAR
%                 equivalents in the strict sense of DEC-20260929-067. The
%                 continuous pre-revision problem statement chained the same
%                 equivalents along a neutral interval (verdict near_only) and
%                 was redesigned on 2026-09-30 by user ruling
%                 (DEC-20260930-068); the v1 <-> v2 mirror remains an exact
%                 symmetry of the continuous relaxation. A 0.125 relocation
%                 lattice with a 0.5 Euclidean neighbourhood finds NO
%                 locally-Pareto-but-not-global point (the recorded
%                 localOnly = 0 is itself a certificate), and the A-price
%                 tier shows up as a knee in the image front.
%   Initialis.  : platform default (uniform box). About 19% of the draws are
%                 feasible (measured, results\initial_distribution\summary.csv)
%                 - the five quality and flow constraints ARE the difficulty
%                 under test, so the start keeps it (documented exception,
%                 same position as NetworkDesign8Sparse（退役）/Knapsack12（退役）: a uniform-feasible start exists
%                 and is cheap, but it would hide the constraint-handling
%                 difficulty the benchmark measures).

    properties(SetAccess = private)
        G;
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
    end
    methods
        function obj = Setting(obj)
            S = load(fullfile(fileparts(mfilename('fullpath')),'data','BlendPool_1.mat'),'G');
            obj.G = S.G;
            assert(isfield(obj.G,'objLo') && isfield(obj.G,'objHi'), ...
                'RWMMO:BlendPool', 'Run tests/blendpool_reference_exact.m to freeze the objective scale.');
            obj.M = 2;
            obj.D = 3;
            obj.lower = obj.G.lower;
            obj.upper = obj.G.upper;
            obj.encoding = ones(1,obj.D);
        end
        function X = CalDec(obj,X)
            X = min(max(double(X), obj.lower), obj.upper);
            % batch detents of the pool-to-P1 valve (DEC-20260930-068): the
            % snap is idempotent, keeps the box, and matches the defensive
            % snap inside rwmmo_blendpool_objectives bit for bit
            B = obj.G.v1Detent;
            X(:,3) = min(max(B * round(X(:,3) / B), obj.lower(3)), obj.upper(3));
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
        function R = GetPSLocal(obj)
            obj.loadLocal();
            R = obj.LocPS;
        end
        function R = GetPFLocal(obj)
            obj.loadLocal();
            R = obj.LocPF;
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
        %DrawSolution - Display ONE solution's blending plan in a new figure.
        %   f = P.DrawSolution(x) renders the concrete flow-sheet of the
        %   single decision row x with the same domain renderer as the
        %   offline gallery (viz\rwmmo_render_solution) and returns the
        %   figure handle.
            [varargout{1:nargout}] = rwmmo_show_solution(obj, dec);
        end
    end
    methods(Access = private)
        function R = evaluate(obj,X)
            if ~isempty(obj.CacheX) && isequal(size(obj.CacheX),size(X)) && all(obj.CacheX(:) == X(:))
                R = obj.CacheR;
                return;
            end
            R = rwmmo_blendpool_objectives(obj.CalDecLocal(X), obj.G);
            obj.CacheX = X; obj.CacheR = R;
        end
        function X = CalDecLocal(obj,X)
            X = min(max(double(X), obj.lower), obj.upper);
        end
        function PF = referencePF(obj)
            if isempty(obj.RefPF), obj.loadReference(); end
            PF = obj.RefPF;
        end
        function loadReference(obj)
            f = fullfile(fileparts(mfilename('fullpath')),'ref_pf_ps','RWMMOP16_BlendPool_reference.mat');
            assert(isfile(f), 'RWMMO:ReferenceMissing', 'Run tests/blendpool_reference_exact.m to build %s.', f);
            S = load(f,'PS_ref','PF_ref','PF_ref_raw');
            assert(size(S.PS_ref,1) == size(S.PF_ref,1) && size(S.PS_ref,1) > 1, ...
                'RWMMO:ReferenceInvalid', 'Malformed BlendPool reference archive.');
            obj.RefPS = S.PS_ref; obj.RefPF = S.PF_ref; obj.RefPFRaw = S.PF_ref_raw;
        end
        function loadLocal(obj)
            f = fullfile(fileparts(mfilename('fullpath')),'ref_pf_ps','RWMMOP16_BlendPool_local_reference.mat');
            assert(isfile(f), 'RWMMO:ReferenceMissing', 'Run tests/blendpool_reference_exact.m to build %s.', f);
            S = load(f,'PS_local','PF_local','PF_local_raw');
            assert(size(S.PS_local,1) == size(S.PF_local,1) && size(S.PS_local,1) > 1, ...
                'RWMMO:ReferenceInvalid', 'Malformed BlendPool local archive.');
            obj.LocPS = S.PS_local; obj.LocPF = S.PF_local; obj.LocPFRaw = S.PF_local_raw;
        end
    end
end
