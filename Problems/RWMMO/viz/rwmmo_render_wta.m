function rwmmo_render_wta(PRO, dec, ax, opts)
%RWMMO_RENDER_WTA Weapon-target assignment: compact bipartite diagram.
%   Left column: weapon types (blue squares) with role, stock and
%   remaining rounds; right column: targets (orange circles) with value,
%   cumulative kill probability and salvo status. Edge width is
%   proportional to the missiles allocated x(i,j). Rows are spaced one
%   unit apart and the canvas is sized to the larger column, so there is
%   no dead band. Numbers come from rwmmo_wta_objectives, the same
%   evaluator the objectives use, so the picture cannot drift.
if nargin < 4, opts = struct(); end
W = PRO.W;
X = PRO.CalDec(dec);
R = rwmmo_wta_objectives(X, W);
Xij = reshape(round(X), W.nT, W.nW);          % k = (j-1)*nT + i
pal = rwmmo_palette;
set(ax, 'FontName','Times New Roman','FontSize',9,'NextPlot','add','Box','off');
hold(ax, 'on');
nRows = max(W.nW, W.nT);
yW = zeros(1, W.nW); yT = zeros(1, W.nT);
for j = 1:W.nW, yW(j) = nRows + 0.4 - (j-1) + (nRows - W.nW) / 2; end
for i = 1:W.nT, yT(i) = nRows + 0.4 - (i-1) + (nRows - W.nT) / 2; end
maxx = max(1, max(Xij(:)));
hEdge = gobjects(0,1);
for j = 1:W.nW
    for i = 1:W.nT
        if Xij(i,j) == 0, continue; end
        lw = 0.6 + 3.6 * Xij(i,j) / maxx;
        h = plot(ax, [1, 2], [yW(j), yT(i)], '-', 'Color', [pal.blue, 0.75], 'LineWidth', lw);
        if isempty(hEdge), hEdge = h; end
    end
end
hW = gobjects(0,1); hT = gobjects(0,1);
for j = 1:W.nW
    h = plot(ax, 1, yW(j), 's', 'MarkerSize', 12, 'MarkerFaceColor', pal.blue, 'MarkerEdgeColor', 'k');
    if isempty(hW), hW = h; end
    role = '';
    if isfield(W,'weaponRole') && ~isempty(W.weaponRole), role = char(string(W.weaponRole{j})); end
    text(ax, 0.93, yW(j), sprintf('W%d  %s\nstock %d, left %d', j, role, W.q(j), W.q(j)-R.used(j)), ...
        'HorizontalAlignment','right','VerticalAlignment','middle','FontSize',8,'FontName','Times New Roman');
end
salvoMax = W.salvoMax;
if isscalar(salvoMax), salvoMax = repmat(salvoMax, 1, W.nT); end
for i = 1:W.nT
    viol = '';
    if R.perTarget(i) > salvoMax(i), viol = sprintf('  SALVO+%d', R.perTarget(i)-salvoMax(i)); end
    h = plot(ax, 2, yT(i), 'o', 'MarkerSize', 12, 'MarkerFaceColor', pal.orange, 'MarkerEdgeColor', 'k');
    if isempty(hT), hT = h; end
    text(ax, 2.07, yT(i), sprintf('T%d  value %.4g\nP_{kill} = %.3f (%d missiles)%s', ...
        i, W.V(i), R.Pkill(i), R.perTarget(i), viol), ...
        'HorizontalAlignment','left','VerticalAlignment','middle','FontSize',8,'FontName','Times New Roman');
end
xlim(ax, [0.2, 3.3]); ylim(ax, [0, nRows + 2.6]);   % right room for the target labels, top band for the info box
axis(ax, 'off');
hh = [hW, hT, hEdge];
lb = [{'weapon type'}, {'target'}, {'allocation (width = missiles)'}];
keep = isgraphics(hh);
legend(ax, hh(keep), lb(keep), 'Location','southoutside','Orientation','horizontal', ...
    'FontSize',8,'FontName','Times New Roman','Box','off');
opts.note = sprintf('missiles allocated = %d, stock remaining = %d', sum(R.used), sum(W.q) - sum(R.used));
if ~isfield(opts,'objRaw') || isempty(opts.objRaw), opts.objRaw = PRO.CalObjRaw(X); end
if ~isfield(opts,'feasible'), opts.feasible = all(PRO.CalCon(X) <= 0, 2); opts.conValue = PRO.CalCon(X); end
rwmmo_render_header(ax, PRO, opts);
end
