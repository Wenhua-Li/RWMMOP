function C = rwmmo_wta_compositions(n, q)
%RWMMO_WTA_COMPOSITIONS All ways to spend at most q missiles over n targets.
%   C = rwmmo_wta_compositions(n,q) returns every integer vector in [0,q]^n with
%   sum at most q, one per row, in lexicographic order. The feasible set of the
%   weapon-target assignment problem is exactly the Cartesian product of these
%   sets over weapon types, which is what makes an exact reference possible.
assert(n >= 1 && q >= 0, 'RWMMO:WTAComposition', 'Bad arguments.');
C = zeros(0, n);
rec(1, zeros(1,n), q);
    function rec(k, cur, left)
        if k > n
            C(end+1, :) = cur; %#ok<AGROW>
            return;
        end
        for v = 0:min(q, left)
            cur(k) = v;
            rec(k+1, cur, left - v);
        end
        cur(k) = 0;
    end
end