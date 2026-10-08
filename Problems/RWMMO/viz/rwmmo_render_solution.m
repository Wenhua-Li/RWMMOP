function rwmmo_render_solution(PRO, dec, ax, opts)
%RWMMO_RENDER_SOLUTION Draw one solution's domain picture (one solution one figure).
%   The single dispatch shared by the offline gallery
%   (tests/rwmmo_render_gallery.m) and the standalone per-solution entry
%   rwmmo_show_solution (also exposed as P.DrawSolution(x) on every class) -
%   there is exactly one implementation per domain family, so the interactive
%   view and the paper figures cannot drift apart. PRO is a
%   constructed RWMMO problem instance, dec a raw 1 x D decision row (each
%   renderer repairs it through PRO.CalDec before drawing), ax the target
%   axes (a uiaxes in rwmmo_show_solution and in the gallery). opts is a struct, all fields
%   optional: .id .cls .title .solutionIndex .source .objRaw(1xM)
%   .objNorm(1xM) .feasible .executedRequests .conValue.
if nargin < 4, opts = struct(); end
switch class(PRO)
    case 'RWMMOP9_WTA66'
        rwmmo_render_wta(PRO, dec, ax, opts);
    case 'RWMMOP19_PMSched13'
        rwmmo_render_gantt_machine(PRO, dec, ax, opts);
    case 'RWMMOP2_Jobshop5'
        rwmmo_render_gantt_jobshop(PRO, dec, ax, opts);
    case {'RWMMOP1_SatelliteTTC25','RWMMOP3_SatelliteTTC50'}
        rwmmo_render_gantt_satellite(PRO, dec, ax, opts);
    case {'RWMMOP11_DNR69','RWMMOP12_DNR33MS','RWMMOP13_DNR33MP'}
        rwmmo_render_feeder(PRO, dec, ax, opts);
    case 'RWMMOP14_Net12Sparse'
        rwmmo_render_microgrid(PRO, dec, ax, opts);
    case 'RWMMOP20_BiTree12'
        rwmmo_render_tree(PRO, dec, ax, opts);
    case 'RWMMOP8_Knapsack24'
        rwmmo_render_knapsack(PRO, dec, ax, opts);
    case 'RWMMOP15_SiteSelect'
        rwmmo_render_map(PRO, dec, ax, opts);
    case 'RWMMOP16_BlendPool'
        rwmmo_render_blendpool(PRO, dec, ax, opts);
    case 'RWMMOP10_Truss25'
        rwmmo_render_truss(PRO, dec, ax, opts);
    case 'RWMMOP4_ArrayNull'
        rwmmo_render_pattern(PRO, dec, ax, opts);
    case 'RWMMOP5_WindFarm'
        rwmmo_render_windfarm(PRO, dec, ax, opts);
    case 'RWMMOP17_HomotopyPath'
        rwmmo_render_path(PRO, dec, ax, opts);
    case 'RWMMOP6_NestingLayout'
        rwmmo_render_nesting(PRO, dec, ax, opts);
    case 'RWMMOP18_ReservoirOps'
        rwmmo_render_reservoir(PRO, dec, ax, opts);
    case 'RWMMOP7_EcoDispatch15MF'
        rwmmo_render_dispatch15(PRO, dec, ax, opts);
    otherwise
        error('RWMMO:RenderDispatch', 'No domain renderer registered for %s.', class(PRO));
end
end
