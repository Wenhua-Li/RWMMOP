function rwmmo_render_dispatch(PRO, dec, ax, opts)
%RWMMO_RENDER_DISPATCH One dispatch as a unit-loading bar chart.
%   One bar per unit at its output, drawn on a per-unit operating band
%   (Pmin..Pmax as a light background band) so the head-room is visible at
%   a glance; the twin pairs share a colour (units 1-2 coal twins, 3-4 gas
%   twins), the distinct units carry their own colours, and valve-point
%   units are marked with a triangle above the bar. The dispatch totals and
%   the valve contribution go to the shared info box; every glyph class
%   owns a legend entry.
if nargin < 4, opts = struct(); end
G = PRO.G;
X = PRO.CalDec(dec);
R = PRO.CalObjRaw(X);
pal = rwmmo_palette;
set(ax, 'FontName','Times New Roman','FontSize',9,'NextPlot','add','Box','on');
hold(ax, 'on');
nU = numel(X);
cols = [pal.blue; pal.blue; pal.bluishgreen; pal.bluishgreen; pal.vermillion; pal.orange];
% operating bands
for i = 1:nU
    patch(ax, i+[-0.38, 0.38, 0.38, -0.38], [G.lower(i), G.lower(i), G.Pmax(i), G.Pmax(i)], ...
        [0.93 0.93 0.93], 'EdgeColor','none', 'HandleVisibility','off');
end
hBar = bar(ax, 1:nU, X, 0.62, 'FaceColor', 'flat', 'EdgeColor', 'k');
hBar.CData = cols;
for i = 1:nU
    text(ax, i, X(i) + 8, sprintf('%.1f', X(i)), 'FontSize', 8, 'FontName','Times New Roman', ...
        'HorizontalAlignment','center','VerticalAlignment','bottom');
end
% valve-point markers
hValve = [];
for i = find(G.e > 0)
    h = plot(ax, i, G.Pmax(i) + 26, '^', 'MarkerSize', 6, ...
        'MarkerFaceColor', pal.yellow, 'MarkerEdgeColor','k');
    if isempty(hValve), hValve = h; end
end
xlabel(ax, 'unit'); ylabel(ax, 'unit output (MW)');
xlim(ax, [0.5, nU+0.5]);
ylim(ax, [0, max(G.Pmax) + 60]);
set(ax, 'XTick', 1:nU, 'XTickLabel', arrayfun(@(i) sprintf('U%d', i), 1:nU, 'UniformOutput', false));
grid(ax, 'on');
% per-group legend proxies (one bar object colours all units)
gp = [1, 3, 5, 6];
gl = {'coal twins (U1, U2)', 'gas twins (U3, U4)', 'oil unit (U5, valve)', 'small gas (U6)'};
hh = gobjects(1,4);
for i = 1:4
    hh(i) = plot(ax, NaN, NaN, 's', 'MarkerSize', 9, ...
        'MarkerFaceColor', cols(gp(i),:), 'MarkerEdgeColor', 'k', 'LineStyle', 'none');
end
lb = gl;
if ~isempty(hValve)
    hh = [hh, hValve];
    lb = [lb, {'valve-point unit'}]; %#ok<AGROW>
end
keep = isgraphics(hh);
legend(ax, hh(keep), lb(keep), 'Location','southoutside','Orientation','horizontal', ...
    'NumColumns',3,'FontSize',8,'FontName','Times New Roman');
valveContribution = sum(G.e .* abs(sin(G.fv .* (X - G.lower))));
opts.note = sprintf('total = %.4g MW, valve contribution = %.4g per hour', sum(X), valveContribution);
if ~isfield(opts,'objRaw') || isempty(opts.objRaw), opts.objRaw = R; end
if ~isfield(opts,'feasible'), opts.feasible = all(PRO.CalCon(X) <= 0); end
rwmmo_render_header(ax, PRO, opts);
end
