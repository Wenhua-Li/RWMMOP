function R = rwmmo_nestinglayout_objectives(X, F)
%RWMMO_NESTINGLAYOUT_OBJECTIVES Vectorised evaluator of the frozen nesting instance.
%   X is n x 3N rows (x, y, theta per part), F the frozen snapshot struct.
%   Returns raw engineering units:
%     objs(:,1) = bounding-box area of all placed part corners
%     objs(:,2) = -sum over part pairs of centre distance (spread)
%     cons      = [pairwise SAT penetration depths (N(N-1)/2 columns, <= 0
%                  when disjoint), per-part worst sheet excess (N columns)]
%   Rectangles are rotated exactly; the SAT depth is the minimum axis
%   overlap over the four edge normals (two per rectangle), which is a
%   continuous penetration measure (negative = separation slack).
n = size(X,1);
N = F.nParts;
cx = X(:,1:3:end); cy = X(:,2:3:end); th = X(:,3:3:end);
% local rectangle list per part: cell of m x 4 (cx cy w h)
nRect = cellfun(@(r) size(r,1), F.partRects);
maxR = max(nRect);
% gather rotated corners per part-rectangle: n x nRect_total x 4 x 2
rectPart = zeros(sum(nRect),1);
q = 0;
rectLocal = cell(sum(nRect),1);
for p = 1:N
    for r = 1:nRect(p)
        q = q + 1;
        rectPart(q) = p;
        rectLocal{q} = F.partRects{p}(r,:);
    end
end
nQ = q;
cornX = zeros(n, nQ, 4); cornY = zeros(n, nQ, 4);
cenX = zeros(n, nQ); cenY = zeros(n, nQ);
for k = 1:nQ
    p = rectPart(k);
    lc = rectLocal{k};
    hx = lc(3)/2; hy = lc(4)/2;
    lx = [lc(1)-hx lc(1)+hx lc(1)+hx lc(1)-hx];
    ly = [lc(2)-hy lc(2)-hy lc(2)+hy lc(2)+hy];
    c = cos(th(:,p)); s = sin(th(:,p));
    for v = 1:4
        cornX(:,k,v) = cx(:,p) + lx(v)*c - ly(v)*s;
        cornY(:,k,v) = cy(:,p) + lx(v)*s + ly(v)*c;
    end
    cenX(:,k) = cx(:,p) + lc(1)*c - lc(2)*s;
    cenY(:,k) = cy(:,p) + lc(1)*s + lc(2)*c;
end
% objectives
allX = reshape(cornX, n, []); allY = reshape(cornY, n, []);
f1 = (max(allX,[],2) - min(allX,[],2)) .* (max(allY,[],2) - min(allY,[],2));
pcx = zeros(n,N); pcy = zeros(n,N);
for p = 1:N
    sel = rectPart == p;
    pcx(:,p) = mean(cenX(:,sel), 2);
    pcy(:,p) = mean(cenY(:,sel), 2);
end
spread = zeros(n,1);
pairs = [];
for i = 1:N
    for j = i+1:N
        pairs(end+1,:) = [i j]; %#ok<AGROW>
        spread = spread + sqrt((pcx(:,i)-pcx(:,j)).^2 + (pcy(:,i)-pcy(:,j)).^2);
    end
end
% constraints: pairwise SAT depth over rectangle unions
nPairs = size(pairs,1);
depth = zeros(n, nPairs);
for z = 1:nPairs
    i = pairs(z,1); j = pairs(z,2);
    d = -inf(n,1);
    for a = find(rectPart == i)'
        for b = find(rectPart == j)'
            d = max(d, satDepth(reshape(cornX(:,a,:),[],4), reshape(cornY(:,a,:),[],4), ...
                reshape(cornX(:,b,:),[],4), reshape(cornY(:,b,:),[],4)));
        end
    end
    depth(:,z) = d;
end
% sheet containment: worst excess over corners
excess = max(max(max(allX - F.sheet(1), -allX), max(allY - F.sheet(2), -allY)), [], 2);
partExcess = zeros(n,N);
for p = 1:N
    sel = reshape(rectPart == p, 1, []);
    ax = reshape(cornX(:,sel,:), n, []); ay = reshape(cornY(:,sel,:), n, []);
    partExcess(:,p) = max(max(max(ax - F.sheet(1), -ax), max(ay - F.sheet(2), -ay)), [], 2);
end
R.objs = [f1, -spread];
R.cons = [depth, partExcess];
R.feasible = all(R.cons <= 0, 2);
end

function d = satDepth(ax, ay, bx, by)
%Minimum axis overlap of two convex quads (n x 4 x 2 corner arrays);
%negative when a separating axis exists (disjoint), positive = penetration.
d = inf(size(ax,1),1);
for shape = 1:2
    if shape == 1, Px = ax; Py = ay; else, Px = bx; Py = by; end
    for e = 1:4
        e2 = mod(e,4)+1;
        nx = Py(:,e2) - Py(:,e); ny = -(Px(:,e2) - Px(:,e));
        nl = sqrt(nx.^2 + ny.^2); nl(nl == 0) = 1;
        nx = nx./nl; ny = ny./nl;
        pa = ax.*nx + ay.*ny; pb = bx.*nx + by.*ny;
        ov = min(max(pa,[],2), max(pb,[],2)) - max(min(pa,[],2), min(pb,[],2));
        d = min(d, ov);
    end
end
end
