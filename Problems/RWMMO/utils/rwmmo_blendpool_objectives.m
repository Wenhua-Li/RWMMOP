function R = rwmmo_blendpool_objectives(X, G)
%RWMMO_BLENDPOOL_OBJECTIVES Shared evaluator for RWMMOP16_BlendPool (RWMMOP16).
%   X is an N x 3 matrix of raw decisions [uA uB v1] (already inside the box;
%   the class clips in CalDec before calling this). Returns the raw objectives
%   [total feed cost, total sulphur delivered], five signed constraint
%   violations (<= 0 feasible) and the feasibility flag. The v1-column is
%   objective-neutral by construction: both objectives are affine in (uA,uB)
%   only, which is the exact-tie (EM) structure of the problem.
%
%   BATCH DETENTS (DEC-20260930-068): when G carries v1Detent, v1 is snapped
%   to the nearest multiple of it (clamped back into the box) before anything
%   else - the valve has physical detents, contracts ship in batches. The
%   snap is idempotent and identical to the class CalDec repair, so direct
%   callers (builders, audits, the oracle differential) cannot bypass the
%   problem statement. Tie sets are therefore FINITE detent sets: equivalent
%   solutions are isolated and far apart (25 units = 1/3 of the v1 range,
%   above the frozen deltaFar = 0.2), not a connected neutral interval.
%
%   cons(:,1)  P1 sulphur spec : q*v1 + qC*w1 - Q1*D1 <= 0   (bilinear)
%   cons(:,2)  P2 sulphur spec : q*v2 + qC*w2 - Q2*D2 <= 0   (bilinear)
%   cons(:,3)  pool-to-P2 flow : v2 = uA+uB-v1 >= 0
%   cons(:,4)  bypass to P2    : w2 = D2-v2    >= 0
%   cons(:,5)  total demand    : w1+w2 = D1+D2-(uA+uB) >= 0
%   (w1 >= 0 is the v1 <= D1 box bound; q is the pool sulphur, the flow-weighted
%   average of qA and qB, which lies in [min(qA,qB), max(qA,qB)] for any rates.)
X = double(X);
if isfield(G,'v1Detent')
    B = G.v1Detent;
    X(:,3) = min(max(B * round(X(:,3) / B), G.lower(3)), G.upper(3));
end
s = X(:,1) + X(:,2);
q = (G.qA*X(:,1) + G.qB*X(:,2)) ./ max(s, 1e-12);
v2 = s - X(:,3);
w1 = G.D1 - X(:,3);
w2 = G.D2 - v2;
% Objectives are computed from the ALGEBRAICALLY REDUCED form (uA,uB only):
% w1+w2 = D1+D2-s, so the arithmetic never sees v1 and every point of a tie
% interval is bit-identical by construction, not by floating-point luck.
byp = G.D1 + G.D2 - s;             % total bypass flow (v1-free)
f1 = G.cA*min(X(:,1), G.tierA) + G.cA2*max(X(:,1) - G.tierA, 0) + ...
     G.cB*X(:,2) + G.cC*byp;
f2 = G.qA*X(:,1) + G.qB*X(:,2) + G.qC*byp;
R.objs = [f1, f2];
R.cons = [q.*X(:,3) + G.qC*w1 - G.Q1*G.D1, ...
          q.*v2    + G.qC*w2 - G.Q2*G.D2, ...
          X(:,3) - s, ...
          s - X(:,3) - G.D2, ...
          s - (G.D1 + G.D2)];
R.feasible = all(R.cons <= 1e-9, 2);
end
