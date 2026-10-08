function R = rwmmo_site_objectives(X, G)
%RWMMO_SITE_OBJECTIVES Emergency-facility location model of RWMMOP15_SiteSelect (RWMMOP15).
%   X  n x 2 candidate site coordinates in km
%   G  frozen instance struct written by tests/site_select_build_snapshot.m
%   R.objs   n x 3 raw objectives in km: the distance from the site to the
%            nearest residential node, the nearest commercial/industrial node
%            and the nearest transport-hub node
%   R.clear  n x (3+nDisks) signed clearance in km to every forbidden region
%            inside it), kept so audits and figures can show why a site is out
%   R.cons   n x (3+nDisks) constraint violations in the PlatEMO convention (<= 0
%            feasible), i.e. buffer - clearance
%   R.feasible  n x 1 logical
%
%   Every forbidden region is analytic - two straight keep-out corridors, three
%   circular keep-out zones and one convex polygon - so feasibility is decided
%   by an exact point-location test instead of by sampling. That is what makes
%   the reference archive certifiable rather than merely approximate: the
%   feasible set is a union of exactly characterised chunks, and each objective
%   is 1-Lipschitz in the Euclidean metric, so a grid of step h bounds the
%   objective error of the grid by h/sqrt(2) per axis.
%
%   The instance is mirror symmetric about the domain centre line x = G.axisX:
%   both the facility sets and every forbidden region are. Mirroring a feasible
%   site therefore leaves all three objectives bit-identical while moving the
%   site by up to twice the distance to the axis, which is the structural source
%   of equivalent multimodality in this problem.
X = double(X);
assert(size(X,2) == 2, 'RWMMO:SiteSelect', 'Expected two decision variables.');
n = size(X,1);
sets = {G.S1, G.S2, G.S3};
objs = zeros(n,3);
for k = 1:3
    S = sets{k};
    objs(:,k) = min(sqrt((X(:,1) - S(:,1)').^2 + (X(:,2) - S(:,2)').^2), [], 2);
end
nD = size(G.disks,1);
clr = zeros(n, 3 + nD);
clr(:,1) = rwmmo_point_segment_distance(X, G.corridor1(1,:), G.corridor1(2,:)) - G.corridorHalfWidth(1);
clr(:,2) = rwmmo_point_segment_distance(X, G.corridor2(1,:), G.corridor2(2,:)) - G.corridorHalfWidth(2);
for k = 1:nD
    c = G.disks(k,1:2);
    clr(:,2+k) = sqrt((X(:,1) - c(1)).^2 + (X(:,2) - c(2)).^2) - G.disks(k,3);
end
clr(:,end) = rwmmoPolygonClearance(X, G.polygon);
R.objs = objs;
R.clear = clr;
R.cons = G.buffer - clr;
R.feasible = all(R.cons <= 0, 2);
end

function c = rwmmoPolygonClearance(X, P)
%Signed clearance to a convex polygon: distance to the boundary outside, minus
%the depth inside. Vertices must be counter-clockwise, which the snapshot
%builder asserts from the shoelace area.
m = size(P,1);
n = size(X,1);
dEdge = inf(n,1);
inside = true(n,1);
for e = 1:m
    A = P(e,:); B = P(mod(e,m)+1,:);
    dEdge = min(dEdge, rwmmo_point_segment_distance(X, A, B));
    ex = B(1) - A(1); ey = B(2) - A(2);
    % s = (X-A) x (B-A); the interior of a counter-clockwise polygon is to the
    % left of every directed edge, i.e. (B-A) x (X-A) >= 0, i.e. s <= 0.
    s = (X(:,1) - A(1))*ey - (X(:,2) - A(2))*ex;
    inside = inside & (s <= 0);
end
c = dEdge;
c(inside) = -dEdge(inside);
end