function rwmmo_render_tree(PRO, dec, ax, opts)
%RWMMO_RENDER_TREE Bi-criterion spanning tree on a circular layout.
%   All candidate edges are drawn: selected ones solid blue with width
%   proportional to weight set A, unselected ones grey dotted. Nodes that
%   exceed the degree bound get a vermillion ring. Labels sit on a fixed
%   radius with generous limits so nothing clips; costs go to the shared
%   info box; a glyph legend covers the three symbol classes.
if nargin < 4, opts = struct(); end
BT = PRO.BT;
X = PRO.CalDec(dec);
sel = logical(X(:)');
pal = rwmmo_palette;
set(ax, 'FontName','Times New Roman','FontSize',9,'NextPlot','add','Box','off');
hold(ax, 'on');
th = linspace(0, 2*pi, BT.nNodes+1); th = th(1:end-1);
px = cos(th); py = sin(th);
maxA = max(BT.wA);
hSel = gobjects(0,1); hUns = gobjects(0,1); hViol = gobjects(0,1);
for e = 1:BT.nEdges
    u = BT.from(e); v = BT.to(e);
    if sel(e)
        h = plot(ax, [px(u), px(v)], [py(u), py(v)], '-', 'Color', pal.blue, ...
            'LineWidth', 1 + 3.5 * BT.wA(e) / maxA);
        if isempty(hSel), hSel = h; end
    else
        h = plot(ax, [px(u), px(v)], [py(u), py(v)], ':', 'Color', pal.grey, 'LineWidth', 0.9);
        if isempty(hUns), hUns = h; end
    end
end
deg = zeros(1, BT.nNodes);
for e = 1:BT.nEdges
    if sel(e), deg(BT.from(e)) = deg(BT.from(e)) + 1; deg(BT.to(e)) = deg(BT.to(e)) + 1; end
end
for k = 1:BT.nNodes
    if deg(k) > BT.maxDeg
        h = plot(ax, px(k), py(k), 'o', 'MarkerSize', 17, 'MarkerFaceColor', 'none', ...
            'MarkerEdgeColor', pal.vermillion, 'LineWidth', 1.8);
        if isempty(hViol), hViol = h; end
    end
    plot(ax, px(k), py(k), 'o', 'MarkerSize', 10, 'MarkerFaceColor', [1 1 1], 'MarkerEdgeColor', 'k');
    text(ax, 1.16*px(k), 1.16*py(k), sprintf('%d', k), 'HorizontalAlignment','center', ...
        'FontSize', 8, 'FontName','Times New Roman');
end
axis(ax, 'equal'); axis(ax, [-1.6, 1.6, -1.6, 1.75]); axis(ax, 'off'); grid(ax, 'off');
hh = [hSel, hUns, hViol];
lb = [{'selected tree edge'}, {'unselected candidate'}, {'degree-bound violation'}];
keep = isgraphics(hh);
legend(ax, hh(keep), lb(keep), 'Location','southoutside','Orientation','horizontal', ...
    'FontSize',8,'FontName','Times New Roman','Box','off');
R = PRO.CalObjRaw(X);
C = PRO.CalCon(X);
opts.note = sprintf('cost A = %.4g, cost B = %.4g, max degree %d / bound %d', ...
    R(1), R(2), max(deg), BT.maxDeg);
if ~isfield(opts,'objRaw') || isempty(opts.objRaw), opts.objRaw = R; end
if ~isfield(opts,'feasible'), opts.feasible = all(C <= 0, 2); opts.conValue = C; end
rwmmo_render_header(ax, PRO, opts);
end
