function d = rwmmo_point_segment_distance(X, A, B)
%RWMMO_POINT_SEGMENT_DISTANCE Euclidean distance from points to a line segment.
%   X is n x 2, A and B are 1 x 2 endpoints. The parameter is clamped to [0,1],
%   so the result is the distance to the segment rather than to its supporting
%   line, which is what the keep-out corridors of RWMMOP15_SiteSelect need: a
%   corridor must not keep bending around the domain outside its endpoints.
%   The primitive is differentially validated against a widely used third-party
%   implementation in tests/site_select_geometry_oracle.m (one-off evidence,
%   results/site_select/geometry_oracle.csv) and against an independently
%   written Node.js implementation inside the regression suite.
assert(size(X,2) == 2 && numel(A) == 2 && numel(B) == 2, 'RWMMO:Geometry', 'Expected 2-D points.');
AB = double(B) - double(A);
L2 = AB(1)^2 + AB(2)^2;
assert(L2 > 0, 'RWMMO:Geometry', 'Degenerate segment.');
t = ((X(:,1) - A(1))*AB(1) + (X(:,2) - A(2))*AB(2)) / L2;
t = min(max(t, 0), 1);
px = A(1) + t*AB(1);
py = A(2) + t*AB(2);
d = sqrt((X(:,1) - px).^2 + (X(:,2) - py).^2);
end