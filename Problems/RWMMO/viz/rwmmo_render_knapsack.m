function rwmmo_render_knapsack(PRO, dec, ax, opts)
%RWMMO_RENDER_KNAPSACK Per-item bar chart plus a knapsack fill gauge.
%   Main panel: one bar per item (height = weight), selected items blue,
%   unselected grey, item value above each bar. Slim lower panel: the
%   cumulative weight of the selected items as a horizontal stacked bar
%   against a vermillion capacity line - the capacity constrains the SUM,
%   so it is drawn on the fill gauge where it has meaning, not on the
%   per-item bars. Totals go to the shared info box.
if nargin < 4, opts = struct(); end
KS = PRO.KS;
X = PRO.CalDec(dec);
sel = logical(X(:)');
pal = rwmmo_palette;
fig = ax.Parent;
set(ax, 'FontName','Times New Roman','FontSize',9,'NextPlot','add','Box','on');
hold(ax, 'on');
ax.Position = [0.09 0.30 0.86 0.60];
n = KS.n;
bSel = bar(ax, find(sel),  KS.w(sel),  0.7, 'FaceColor', pal.blue, 'EdgeColor', 'k', 'LineWidth', 0.5);
bUns = bar(ax, find(~sel), KS.w(~sel), 0.7, 'FaceColor', [0.88 0.88 0.88], 'EdgeColor', [0.5 0.5 0.5], 'LineWidth', 0.5);
for k = 1:n
    text(ax, k, KS.w(k), sprintf('v=%d', KS.v(k)), 'HorizontalAlignment','center', ...
        'VerticalAlignment','bottom','FontSize',7.5,'FontName','Times New Roman');
end
set(ax, 'XTick', 1:n, 'XTickLabel', arrayfun(@(k) sprintf('i%d', k), 1:n, 'UniformOutput', false));
yl = [0, max(KS.w) * 1.45]; ylim(ax, yl);      % headroom for value labels + info box
grid(ax, 'on');
ylabel(ax, 'item weight');
hh = [bSel, bUns]; keep = isgraphics(hh); lbs = {'selected','not selected'};
legend(ax, hh(keep), lbs(keep), 'Location','northwest', ...
    'FontSize',8,'FontName','Times New Roman');
% --- slim fill gauge on a second axes of the same type ---
if isa(ax, 'matlab.ui.control.UIAxes')
    ax2 = uiaxes(fig);
else
    ax2 = axes('Parent', fig);
end
ax2.Position = [0.09 0.085 0.86 0.13];
set(ax2, 'FontName','Times New Roman','FontSize',9,'NextPlot','add','Box','on');
hold(ax2, 'on');
selIdx = find(sel);
c = 0;
for z = 1:numel(selIdx)
    k = selIdx(z);
    patch(ax2, [c, c+KS.w(k), c+KS.w(k), c], [0.15, 0.15, 0.85, 0.85], pal.blue, ...
        'EdgeColor', 'w', 'LineWidth', 0.8);
    if KS.w(k) > 0.045 * KS.capacity
        text(ax2, c + KS.w(k)/2, 0.5, sprintf('%d', k), 'HorizontalAlignment','center', ...
            'VerticalAlignment','middle','FontSize',7.5,'FontName','Times New Roman','Color','w');
    end
    c = c + KS.w(k);
end
plot(ax2, [KS.capacity, KS.capacity], [0.05, 0.95], '--', 'Color', pal.vermillion, 'LineWidth', 1.4);
text(ax2, KS.capacity, 1.0, sprintf('capacity = %.4g ', KS.capacity), ...
    'FontSize',8,'FontName','Times New Roman','Color',pal.vermillion, ...
    'HorizontalAlignment','right','VerticalAlignment','bottom');
ylim(ax2, [0, 1.3]); xlim(ax2, [0, max(KS.capacity, c) * 1.06]);
set(ax2, 'YTick', []);
xlabel(ax2, 'cumulative weight of selected items');
R = PRO.CalObjRaw(X);
C = PRO.CalCon(X);
opts.note = sprintf('total value = %.4g, total weight = %.4g / %.4g (residual %.4g), constraint violation = %.4g', ...
    -R(1), sum(KS.w(sel)), KS.capacity, KS.capacity - sum(KS.w(sel)), sum(max(C(:), 0)));
if ~isfield(opts,'objRaw') || isempty(opts.objRaw), opts.objRaw = R; end
if ~isfield(opts,'feasible'), opts.feasible = all(C <= 0, 2); opts.conValue = C; end
rwmmo_render_header(ax, PRO, opts);
end
