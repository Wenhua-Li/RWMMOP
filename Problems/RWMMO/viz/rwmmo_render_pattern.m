function rwmmo_render_pattern(PRO, dec, ax, opts)
%RWMMO_RENDER_PATTERN One excitation as a pattern cut plus amplitude taper.
%   The upper panel shows the normalised pattern in dB over 0..180 deg with
%   the two prescribed null directions marked and the achieved sidelobe
%   level drawn as a reference line; the lower strip shows the amplitude
%   taper as bars with the mirrored element pairs sharing a colour (the
%   excitation reversal partner of this solution has the identical pattern).
if nargin < 4, opts = struct(); end
G = PRO.G;
X = PRO.CalDec(dec);
R = PRO.CalObjRaw(X);
pal = rwmmo_palette;
set(ax, 'FontName','Times New Roman','FontSize',9,'NextPlot','add','Box','on');
hold(ax, 'on');
th = 0:G.gridStep:180;
u = cos(deg2rad(th));
E = exp(1j * pi * (0:G.N-1).' * u);
p = abs(sum(X(:) .* E, 1)) / sum(X);
pDB = 20 * log10(max(p, 1e-12));
topClip = 0;
ax.Position = [0.10 0.34 0.86 0.58];
hPat = plot(ax, th, pDB, '-', 'Color', pal.blue, 'LineWidth', 1.4);
hNull = []; hSLL = [];
for k = 1:numel(G.nullTheta)
    h = xline(ax, G.nullTheta(k), '--', sprintf('%g^\\circ', G.nullTheta(k)), ...
        'Color', pal.vermillion, 'LineWidth', 1.1, 'LabelOrientation','horizontal', ...
        'FontName','Times New Roman', 'FontSize', 8);
    if isempty(hNull), hNull = h; end
end
hSLL = yline(ax, R(1), ':', sprintf('SLL %.1f dB', R(1)), ...
    'Color', pal.darkgrey, 'LineWidth', 1.0, 'LabelOrientation','horizontal', ...
    'FontName','Times New Roman', 'FontSize', 8);
grid(ax, 'on');
xlim(ax, [0 180]);
ylim(ax, [min(-75, min(pDB)-3), topClip]);
xlabel(ax, 'theta (deg)'); ylabel(ax, 'normalised pattern (dB)');
% --- amplitude taper on a second axes of the same type ------------------------
fig = ancestor(ax, 'figure');
if isa(ax, 'matlab.ui.control.UIAxes')
    ax2 = uiaxes(fig);
else
    ax2 = axes('Parent', fig);
end
hold(ax2, 'on');
ax2.Position = [0.10 0.13 0.86 0.14];
set(ax2, 'FontName','Times New Roman','FontSize',9,'Box','on');
cols = [pal.bluishgreen; pal.bluishgreen; pal.blue; pal.blue; pal.blue; pal.blue; pal.bluishgreen; pal.bluishgreen];
hBar = bar(ax2, 1:G.N, X, 0.6, 'FaceColor', 'flat', 'EdgeColor', 'k');
hBar.CData = cols;
ylim(ax2, [0, 1.15]);
xlim(ax2, [0.5, G.N+0.5]);
set(ax2, 'XTick', 1:G.N, 'XTickLabel', arrayfun(@(i) sprintf('a_{%d}', i), 1:G.N, 'UniformOutput', false));
ylabel(ax2, 'amplitude');
hh = [hPat, hNull, hSLL];
lb = {'pattern cut (dB)', 'prescribed null', 'achieved SLL'};
keep = isgraphics(hh);
legend(ax, hh(keep), lb(keep), 'Location','northeast', 'FontSize',8, 'FontName','Times New Roman');
p40 = 20*log10(max(abs(sum(X(:) .* exp(1j*pi*(0:7).'*cos(deg2rad(G.nullTheta(1)))), 1)) / sum(X), 1e-12));
p140 = 20*log10(max(abs(sum(X(:) .* exp(1j*pi*(0:7).'*cos(deg2rad(G.nullTheta(2)))), 1)) / sum(X), 1e-12));
opts.note = sprintf('nulls: %.1f dB at %g deg, %.1f dB at %g deg (target %g dB)', ...
    p40, G.nullTheta(1), p140, G.nullTheta(2), G.nullTargetDB);
if ~isfield(opts,'objRaw') || isempty(opts.objRaw), opts.objRaw = R; end
if ~isfield(opts,'feasible'), opts.feasible = true; end
rwmmo_render_header(ax, PRO, opts);
end
