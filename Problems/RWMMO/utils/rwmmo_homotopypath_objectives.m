function R = rwmmo_homotopypath_objectives(X, F)
%RWMMO_HOMOTOPYPATH_OBJECTIVES Vectorised evaluator of the frozen path instance.
%   X is n x 2K waypoint coordinates in km, F the frozen snapshot struct.
%   Returns raw engineering units:
%     objs(:,1) = polyline length [km] over start-waypoints-goal
%     objs(:,2) = risk exposure [km^2]: per obstacle, sum over segments of
%                 max(0, (r+margin) - point-segment distance)^2
%     cons      = one signed violation per obstacle: max over segments of
%                 (r - point-segment distance); <= 0 keeps the path outside.
n = size(X,1);
K = F.K;
W = zeros(n, K, 2);
W(:,:,1) = X(:,1:2:end);
W(:,:,2) = X(:,2:2:end);
nP = K + 2;
P = zeros(n, nP, 2);
P(:,1,1) = F.start(1); P(:,1,2) = F.start(2);
P(:,2:K+1,:) = W;
P(:,nP,1) = F.goal(1); P(:,nP,2) = F.goal(2);
Dseg = P(:,2:end,:) - P(:,1:end-1,:);          % n x (K+1) x 2
len = sum(sqrt(Dseg(:,:,1).^2 + Dseg(:,:,2).^2), 2);
nS = K + 1;
nO = size(F.obsCenters,1);
risk = zeros(n,1);
cons = zeros(n, nO);
for o = 1:nO
    c = F.obsCenters(o,:);
    AP = P;
    AP(:,:,1) = P(:,:,1) - c(1);
    AP(:,:,2) = P(:,:,2) - c(2);
    A = AP(:,1:end-1,:); B = AP(:,2:end,:);
    AB = Dseg;                                % n x nS x 2
    ab2 = AB(:,:,1).^2 + AB(:,:,2).^2;
    % q = c - a; t = ((c-a).ab)/|ab|^2; closest - c = t*ab - q = t*ab + (a - c)
    t = -(A(:,:,1).*AB(:,:,1) + A(:,:,2).*AB(:,:,2)) ./ ab2;
    t = min(max(t, 0), 1);
    CX = A(:,:,1) + t.*AB(:,:,1);
    CY = A(:,:,2) + t.*AB(:,:,2);
    d = sqrt(CX.^2 + CY.^2);                  % n x nS point-segment distances
    pen = max(0, (F.obsRadii(o) + F.riskMargin) - d);
    risk = risk + sum(pen.^2, 2);
    cons(:,o) = max(F.obsRadii(o) - d, [], 2);
end
R.objs = [len, risk];
R.cons = cons;
R.feasible = all(cons <= 0, 2);
end
