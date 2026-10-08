function R = rwmmo_truss_objectives(X, G)
%RWMMO_TRUSS_OBJECTIVES Shared finite-element evaluator for the planar truss
%sizing problems (RWMMO_Truss10 Truss10（退役） and RWMMOP10_Truss25 RWMMOP10).
%   X is an N x nM matrix of member areas (already inside the box; the classes
%   clip in CalDec before calling this), G the frozen instance struct carrying
%   nodes, members, fixed, loadNodes, loadPerNode, E, rho, sigmaAllow. Linear-
%   elastic displacement method: assemble the global stiffness of the 2-D
%   truss, solve the free-DOF system, then recover member forces as
%   sigma_i = E/L_i * (u_j - u_i) . e_i per member. Returns the raw objectives
%   [total weight, largest free-DOF displacement] and the nM signed stress
%   violations (<= 0 feasible). Statically indeterminate frames are fine: the
%   displacement method needs no determinacy.
X = double(X);
n = size(X,1);
nN = size(G.nodes,1);
nM = size(G.members,1);
free = setdiff(1:nN, G.fixed);
nF = 2 * numel(free);                   % two DOFs per free node
L = zeros(nM,1);
c = zeros(nM,1); s = zeros(nM,1);
for m = 1:nM
    dx = G.nodes(G.members(m,2),1) - G.nodes(G.members(m,1),1);
    dy = G.nodes(G.members(m,2),2) - G.nodes(G.members(m,1),2);
    L(m) = hypot(dx, dy);
    c(m) = dx / L(m); s(m) = dy / L(m);
end
Ffull = zeros(2*nN,1);
for k = 1:numel(G.loadNodes)
    Ffull(2*G.loadNodes(k)) = -G.loadPerNode;
end
fdof = sort([2*free-1, 2*free]);
Kff = Ffull(fdof);                       % reduced load vector
R.objs = zeros(n,2);
R.cons = zeros(n,nM);
R.stress = zeros(n,nM);
R.disp = zeros(n,nF);
for i = 1:n
    Kfull = zeros(2*nN);
    for m = 1:nM
        k = G.E * X(i,m) / L(m);
        b = [c(m); s(m); -c(m); -s(m)];
        dof = [2*G.members(m,1)-1, 2*G.members(m,1), 2*G.members(m,2)-1, 2*G.members(m,2)];
        Kfull(dof,dof) = Kfull(dof,dof) + k * (b*b');
    end
    u = zeros(2*nN,1);
    u(fdof) = Kfull(fdof,fdof) \ Kff;
    R.disp(i,:) = u(fdof)';
    R.objs(i,2) = max(abs(u(fdof)));
    for m = 1:nM
        dof = [2*G.members(m,1)-1, 2*G.members(m,1), 2*G.members(m,2)-1, 2*G.members(m,2)];
        ue = u(dof([3 4])) - u(dof([1 2]));
        R.stress(i,m) = G.E / L(m) * dot([c(m) s(m)], ue);
    end
    R.objs(i,1) = G.rho * (L' * X(i,:)');
    R.cons(i,:) = abs(R.stress(i,:)) - G.sigmaAllow;
end
R.feasible = all(R.cons <= 1e-6, 2);
end
