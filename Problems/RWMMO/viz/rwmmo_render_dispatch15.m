function rwmmo_render_dispatch15(PRO, dec, ax, opts)
%RWMMO_RENDER_DISPATCH15 One 15-unit dispatch as a unit-loading bar chart.
%   Generalised sibling of rwmmo_render_dispatch: one bar per unit on its
%   operating band (Pmin..Pmax), twin pairs share a colour, the distinct
%   units cycle the Okabe-Ito palette, valve-point units carry a triangle
%   marker and fuel-switch points a tick on the bar; the dispatch total and
%   the valve contribution go to the shared info box.
if nargin < 4, opts = struct(); end
G = PRO.G;
X = PRO.CalDec(dec);
R = PRO.CalObjRaw(X);
pal = rwmmo_palette;
set(ax, 'FontName','Times New Roman','FontSize',9,'NextPlot','add','Box','on');
hold(ax, 'on');
nU = numel(X);
base = [pal.blue; pal.bluishgreen; pal.vermillion; pal.orange; pal.yellow; ...
    pal.skyblue; pal.reddishpurple; pal.black; pal.blue; pal.bluishgreen; ...
    pal.vermillion; pal.orange];
% deterministic colour assignment without containers.Map (its numeric
% ValueType only accepts scalars): twin pair k owns base row k, distinct
% units cycle the remaining rows
cols = zeros(nU,3);
twinOf = zeros(1,nU);
for k = 1:size(G.twinPairs,1)
    twinOf(G.twinPairs(k,1)) = k;
    twinOf(G.twinPairs(k,2)) = k;
end
used = size(G.twinPairs,1);
for i = 1:nU
    if twinOf(i) > 0
        cols(i,:) = base(mod(twinOf(i)-1, size(base,1))+1, :);
    else
        used = used + 1;
        cols(i,:) = base(mod(used-1, size(base,1))+1, :);
    end
end
for i = 1:nU
    patch(ax, i+[-0.38, 0.38, 0.38, -0.38], [G.lower(i), G.lower(i), G.Pmax(i), G.Pmax(i)], ...
        [0.93 0.93 0.93], 'EdgeColor','none', 'HandleVisibility','off');
end
hBar = bar(ax, 1:nU, X, 0.62, 'FaceColor', 'flat', 'EdgeColor', 'k');
hBar.CData = cols;
hValve = [];
for i = find(G.e > 0)
    h = plot(ax, i, G.Pmax(i) + 26, '^', 'MarkerSize', 6, ...
        'MarkerFaceColor', pal.yellow, 'MarkerEdgeColor','k');
    if isempty(hValve), hValve = h; end
end
hSwitch = [];
for i = 1:nU
    h = plot(ax, i, G.Ps(i), '_', 'Color','k', 'LineWidth',1.4);
    if isempty(hSwitch), hSwitch = h; end
end
xlabel(ax, 'unit'); ylabel(ax, 'unit output (MW)');
xlim(ax, [0.5, nU+0.5]);
ylim(ax, [0, max(G.Pmax) + 60]);
set(ax, 'XTick', 1:nU, 'XTickLabel', arrayfun(@(i) sprintf('U%d', i), 1:nU, 'UniformOutput', false));
grid(ax, 'on');
valveTxt = sprintf('valve units: %s', strjoin(arrayfun(@(i) sprintf('U%d', i), find(G.e > 0), 'UniformOutput', false), ','));
if ~isfield(opts,'infoLoc') || isempty(opts.infoLoc), opts.infoLoc = 'northwest'; end
opts.note = {sprintf('total dispatch = %.1f MW (demand %g)', sum(X), G.D), ...
    sprintf('valve-point cost share = %.2f%%', 100*sum(G.e .* abs(sin(G.fv .* (X - G.lower)))) / max(R(1),1)), ...
    valveTxt, ...
    'bar tick = fuel-switch point Ps_u'};
rwmmo_render_header(ax, PRO, opts);
end
