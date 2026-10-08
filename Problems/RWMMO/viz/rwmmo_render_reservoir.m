function rwmmo_render_reservoir(PRO, dec, ax, opts)
%RWMMO_RENDER_RESERVOIR One operation policy drawn as release bars and flows.
%   Grouped bars show the two reservoir releases per period, a line shows the
%   downstream flow (releases plus lateral inflow) with the flood peak
%   marked, and a second line the reservoir-1 storage trajectory; peak flow,
%   generation and both objectives go to the shared info box.
if nargin < 4, opts = struct(); end
G = PRO.F;
X = PRO.CalDec(dec);
R = PRO.CalObjRaw(X);
C = PRO.CalCon(X);
Rl = reshape(X, G.T, G.nRes)';        % nRes x T (reservoir-major columns)
down = sum(Rl,1) + G.lateral;
S = zeros(1, G.nRes, G.T+1);
S(:,:,1) = G.S0;
for t = 1:G.T
    Sin = S(:,:,t) + G.inflow(t) - Rl(:,t)';
    S(:,:,t+1) = Sin - max(0, Sin - G.Smax);
end
pal = rwmmo_palette;
set(ax, 'FontName','Times New Roman','FontSize',9,'NextPlot','add','Box','on');
hold(ax, 'on');
hb1 = bar(ax, 1:G.T, Rl(1,:), 0.38, 'FaceColor', pal.blue, 'EdgeColor','none');
hb1.XData = (1:G.T) - 0.19;
hb2 = bar(ax, 1:G.T, Rl(2,:), 0.38, 'FaceColor', pal.skyblue, 'EdgeColor','none');
hb2.XData = (1:G.T) + 0.19;
hd = plot(ax, 1:G.T, down, '-o', 'Color', pal.vermillion, 'LineWidth',1.3, ...
    'MarkerFaceColor', pal.vermillion, 'MarkerSize',4);
[~, ipk] = max(down);
hpk = plot(ax, ipk, down(ipk), 'p', 'MarkerSize',12, 'MarkerFaceColor', pal.yellow, ...
    'MarkerEdgeColor','k');
hs = plot(ax, 0:G.T, squeeze(S(1,1,:)), '--s', 'Color', pal.bluishgreen, 'LineWidth',1.0, ...
    'MarkerSize',3, 'MarkerFaceColor', pal.bluishgreen);
set(gca,'XTick',0:G.T,'XTickLabel',arrayfun(@(t) sprintf('t%d',t), 0:G.T, 'UniformOutput', false));
xlabel(ax, 'period','FontName','Times New Roman');
ylabel(ax, 'flow / release / storage','FontName','Times New Roman');
legend(ax, [hb1, hb2, hd, hpk, hs], ...
    {'reservoir 1 release','reservoir 2 release','downstream flow','flood peak','reservoir 1 storage'}, ...
    'Location','southoutside', 'Orientation','horizontal', ...
    'FontSize',7.5, 'FontName','Times New Roman');
if ~isfield(opts,'infoLoc') || isempty(opts.infoLoc), opts.infoLoc = 'northwest'; end
opts.note = {sprintf('flood peak = %.2f at t%d', down(ipk), ipk), ...
    sprintf('storage range res1 = [%.1f, %.1f]', min(squeeze(S(1,1,:))), max(squeeze(S(1,1,:)))), ...
    sprintf('constraint violation max = %.3g', max(max(C,0)))};
rwmmo_render_header(ax, PRO, opts);
end
