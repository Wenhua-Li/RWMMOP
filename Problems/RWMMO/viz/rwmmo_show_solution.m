function varargout = rwmmo_show_solution(PRO, dec, opts)
%RWMMO_SHOW_SOLUTION Display ONE solution's domain picture in a new figure.
%   rwmmo_show_solution(PRO, x) renders the concrete engineering shape of a
%   single 1 x D decision row x for an RWMMO problem. PRO is a constructed
%   problem instance or a class-name string (constructed with defaults). The
%   row is repaired through CalDec and evaluated once; the raw and normalised
%   objectives and the feasibility flag annotate the figure. The drawing is
%   done by rwmmo_render_solution - the same domain renderer the offline
%   gallery (tests\rwmmo_render_gallery.m) uses - so this standalone view and
%   the published figures cannot drift apart.
%
%   This is the per-solution display. PROBLEM.DrawDec shows the population
%   distribution in the decision space; RWMMO classes no longer override
%   DrawDec, and the single-solution view lives here instead (each class also
%   exposes it as P.DrawSolution(x)).
%
%   rwmmo_show_solution(PRO, x, opts) merges the struct opts over the
%   auto-computed fields (id, cls, source, objRaw, objNorm, feasible,
%   conValue); see rwmmo_render_solution for the supported fields.
%
%   f = rwmmo_show_solution(...) also returns the figure handle.
%
%   Example:
%       P = RWMMO_DNR33();
%       ps = P.GetPS();
%       f = rwmmo_show_solution(P, ps(1,:));
%       rwmmo_show_solution('RWMMOP15_SiteSelect', [2.9 1.2]);

    if nargin < 3, opts = struct(); end
    if ischar(PRO) || (isstring(PRO) && isscalar(PRO))
        PRO = feval(char(PRO));
    end
    assert(isa(PRO,'PROBLEM'), 'RWMMO:ShowSolution', ...
        'PRO must be a PROBLEM instance or an RWMMO problem class name.');
    dec = double(dec(:).');
    assert(size(dec,2) == PRO.D, 'RWMMO:ShowSolution', ...
        'Expected a 1 x %d decision row, got 1 x %d.', PRO.D, size(dec,2));
    x = PRO.CalDec(dec);
    auto = struct();
    auto.cls = class(PRO);
    auto.source = 'standalone DrawSolution';
    auto.objNorm = PRO.CalObj(x);
    if ismethod(PRO,'CalObjRaw')
        auto.objRaw = PRO.CalObjRaw(x);
    end
    con = PRO.CalCon(x);
    auto.conValue = con;
    auto.feasible = all(con(:) <= 0);
    f = fieldnames(opts);
    for i = 1:numel(f)
        auto.(f{i}) = opts.(f{i});
    end
    fig = uifigure('Visible','off','Color','w');
    fig.Position(3:4) = [980 720];
    ax = uiaxes(fig);
    rwmmo_render_solution(PRO, x, ax, auto);
    if usejava('desktop')
        fig.Visible = 'on';
    end
    if nargout > 0
        varargout = {fig};
    end
end
