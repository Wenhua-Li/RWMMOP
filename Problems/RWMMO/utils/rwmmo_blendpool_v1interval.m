function [vlo, vhi] = rwmmo_blendpool_v1interval(Ua, Ub, G)
%RWMMO_BLENDPOOL_V1INTERVAL Exact feasible v1 interval at fixed pool feeds.
%   Given the pool feed rates (uA,uB) the five signed constraints of
%   rwmmo_blendpool_objectives are all LINEAR in v1, so the feasible v1 set is
%   a closed interval computed in closed form. This is the raster feasibility
%   test of the certified-dense reference builder: a (uA,uB) grid node is
%   feasible exactly when vlo <= vhi. The interval width is also the exact tie
%   (EM) extent, because neither objective depends on v1.
%
%   Flow bounds   : v1 in [max(0, s-D2), min(D1, s)]      from w2, w1, v2 >= 0
%   P1 spec       : (q - qC) v1 <= (Q1 - qC) D1
%   P2 spec       : (qC - q) v1 <= (qC - q) s + (Q2 - qC) D2
%   where s = uA+uB and q is the pool sulphur. A zero-coefficient constraint
%   with a negative right-hand side (q = qC exactly, i.e. the uA = uB
%   diagonal, where every blend has sulphur qC) empties the interval.
Ua = double(Ua); Ub = double(Ub);
s = Ua + Ub;
q = (G.qA*Ua + G.qB*Ub) ./ max(s, 1e-12);
lo = max(0, s - G.D2);
hi = min(G.D1, s);
[lo, hi] = composeIneq(q - G.qC, (G.Q1 - G.qC) * G.D1, lo, hi);
[lo, hi] = composeIneq(G.qC - q, (G.qC - q) .* s + (G.Q2 - G.qC) * G.D2, lo, hi);
vlo = lo; vhi = hi;
end

function [lo, hi] = composeIneq(a, b, lo, hi)
%Compose a*v <= b into the running interval [lo, hi].
%   a > 0 gives an upper bound, a < 0 a lower bound, and a == 0 with b < 0 is
%   unsatisfiable for every v1, which empties the interval via hi = -inf.
b = b .* ones(size(a));   % a constant right-hand side expands to the mask shape
pos = a > 0;
hi(pos) = min(hi(pos), b(pos) ./ a(pos));
neg = a < 0;
lo(neg) = max(lo(neg), b(neg) ./ a(neg));
bad = (a == 0) & (b < 0);
hi(bad) = -inf;
end
