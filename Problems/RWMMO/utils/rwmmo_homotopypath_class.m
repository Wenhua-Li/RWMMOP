function s = rwmmo_homotopypath_class(X, F)
%RWMMO_HOMOTOPYPATH_CLASS Side-sign vector of each path at the class obstacles.
%   s(i,k) = +1 when the polyline of row i crosses x = x_c of class obstacle k
%   above its centre, -1 when below, NaN when the polyline never straddles
%   that x (a looping path has no well-defined side). The first straddling
%   segment in node order decides, so the test is deterministic.
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
cx = F.obsCenters(F.classObstacles, 1);
cy = F.obsCenters(F.classObstacles, 2);
s = nan(n, numel(cx));
for k = 1:numel(cx)
    xs = P(:,:,1) - cx(k);                    % n x nP
    straddle = xs(:,1:end-1) .* xs(:,2:end) <= 0 & ...
        (abs(xs(:,1:end-1)) + abs(xs(:,2:end)) > 0);
    [has, seg] = max(straddle, [], 2);        % first straddling segment
    yy = P(:,seg+1,2);
    y0 = zeros(n,1); x0 = zeros(n,1); x1 = zeros(n,1); y1 = zeros(n,1);
    for i = 1:n
        if ~has(i), continue; end
        a = P(i,seg(i),:); b = P(i,seg(i)+1,:);
        x0(i) = a(1); y0(i) = a(2); x1(i) = b(1); y1(i) = b(2);
    end
    w = (cx(k) - x0) ./ (x1 - x0);
    w(~has | ~isfinite(w)) = 0;
    yc = y0 + w .* (y1 - y0);
    s(has & (yc >= cy(k)), k) = 1;
    s(has & (yc < cy(k)), k) = -1;
end
end
