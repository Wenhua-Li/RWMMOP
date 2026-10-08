function trees = rwmmo_dnr_enumerate_trees(from, to, n, expected)
%RWMMO_DNR_ENUMERATE_TREES Exhaustively enumerate every spanning tree.
%   trees = rwmmo_dnr_enumerate_trees(from,to,n,expected) returns a logical
%   matrix whose rows are branch incidence vectors of all spanning trees of
%   the feeder graph. `expected` is the Kirchhoff count from
%   rwmmo_dnr_dataset; it is used for preallocation and as an independent
%   cross-check, so the two methods must agree exactly.
m = numel(from);
assert(numel(to) == m, 'RWMMO:TreeEnum', 'from/to length mismatch.');
if nargin < 4 || isempty(expected)
    cap = 1024;
else
    cap = expected;
end
trees = false(cap, m);
chosen = false(1, m);
pf = 1:n;
count = 0;
rec(1, 0);
assert(count > 0, 'RWMMO:TreeEnum', 'No spanning tree found; graph disconnected.');
if nargin >= 4 && ~isempty(expected)
    assert(count == expected, 'RWMMO:TreeCount', ...
        'Enumerator found %d spanning trees but Kirchhoff says %d.', count, expected);
end
trees = trees(1:count, :);
    function rec(e, cnt)
        if cnt + (m - e + 1) < n - 1, return; end
        if cnt == n - 1
            count = count + 1;
            if count > size(trees,1)
                trees(2*size(trees,1), m) = false; %#ok<AGROW>
            end
            trees(count, :) = chosen;
            return;
        end
        if e > m, return; end
        a = ufFind(from(e)); b = ufFind(to(e));
        if a ~= b
            pf(a) = b;
            chosen(e) = true;
            rec(e + 1, cnt + 1);
            chosen(e) = false;
            pf(a) = a;
        end
        rec(e + 1, cnt);
    end
    function r = ufFind(x)
        r = x;
        while pf(r) ~= r, r = pf(r); end
    end
end

