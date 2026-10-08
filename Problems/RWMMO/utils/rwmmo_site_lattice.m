function [XL, nlx, nly, stp] = rwmmo_site_lattice(G)
%RWMMO_SITE_LATTICE The relocation lattice behind the GLPF certificate.
%   Derived from the certification grid instead of being built independently, so
%   the lattice coordinates are bit-identical wherever they are used. A point
%   written as 0:0.025:10 and the same point picked out of 0:0.005:10 can differ
%   by one ulp, and on a keep-out boundary that single ulp decides feasibility:
%   it is exactly how the builder and the audit once disagreed about 272 sites
%   that sit on a corridor edge with zero clearance.
%   XL is nL x 2 with the y index varying fastest (meshgrid flattened
%   column-major), which is the convention every padded neighbourhood array in
%   tests/site_select_reference_exact.m uses.
h = G.gridStepKm;
xs = G.domain(1,1):h:G.domain(2,1);
ys = G.domain(1,2):h:G.domain(2,2);
stp = round(G.localLatticeStepKm / h);
assert(abs(stp*h - G.localLatticeStepKm) < 1e-12, 'RWMMO:SiteSelect', ...
    'The relocation lattice step must be a multiple of the certification grid step.');
li = 1:stp:numel(xs);
lj = 1:stp:numel(ys);
nlx = numel(li); nly = numel(lj);
[LX,LY] = meshgrid(xs(li), ys(lj));
XL = [LX(:) LY(:)];
end