function [objs, unreach] = rwmmo_net12_objectives(B, cand, candLen, N)
%RWMMO_NET12_OBJECTIVES Batch evaluator for the RWMMOP14 sparse microgrid design.
%   B        nT x K binary matrix (one column per candidate corridor, repaired
%            to {0,1} by the caller). K = size(cand,1).
%   cand     K x 2 node-index pairs (u,v) of each candidate corridor.
%   candLen  K x 1 line length of each candidate corridor [km].
%   N        number of buses (nodes).
%
%   objs     nT x 2 raw objectives, BOTH minimised:
%            [1] total_line_length_km  = sum of built corridor lengths
%            [2] bridge_exposure       = sum over built edges e of the number
%                of unordered node pairs left unreachable after removing e from
%                the intact design, i.e. sum_e unreach(G - e). For a connected
%                design only bridges contribute (removing a non-bridge keeps the
%                graph connected), so this rewards redundancy: spanning trees
%                score worst, cycle-rich networks score best. This replaces NetworkDesign8Sparse（退役）'s
%                exact three-edge-failure resilience, whose C(K,3) triple sum is
%                not enumerable at 2^21; single-edge exposure is exact per design
%                and keeps the same redundancy incentive.
%   unreach  nT x 1 constraint value: number of unreachable unordered node pairs
%            in the intact design (0 means connected / feasible).
%
%   Reachability uses a boolean transitive closure (Warshall). N is tiny (12) so
%   the per-design loop is fast; the reference builder enumerates all 2^21
%   designs through this same routine in about a minute.
candLen = candLen(:);
nT = size(B,1);
objs = zeros(nT,2);
unreach = zeros(nT,1);
I = logical(eye(N));
for p = 1:nT
    e = find(B(p,:) ~= 0);
    objs(p,1) = sum(candLen(e));
    A = false(N,N);
    if ~isempty(e)
        A(sub2ind([N N], cand(e,1), cand(e,2))) = true;
        A = A | A';
    end
    R = closureW(A | I, N);
    u0 = nnz(triu(~R,1));
    unreach(p) = u0;
    % bridge exposure: sum over built edges of unreach(G - e)
    s = 0;
    for q = 1:numel(e)
        u = cand(e(q),1); v = cand(e(q),2);
        A2 = A; A2(u,v) = false; A2(v,u) = false;
        R2 = closureW(A2 | I, N);
        s = s + nnz(triu(~R2,1));
    end
    objs(p,2) = s;
end
end

function R = closureW(R, N)
%Warshall transitive closure of a boolean reachability seed (reflexive or not).
for k = 1:N
    R = R | (R(:,k) & R(k,:));
end
end
