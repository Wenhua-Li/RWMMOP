function rwmmo_render_path(PRO, dec, ax, opts)
%RWMMO_RENDER_PATH One waypoint path drawn on the frozen obstacle field.
%   Obstacle circles are hatched patches, the mirror axis a dashed line, the
%   endpoints squares, the realised polyline a blue line through the waypoint
%   dots; the homotopy class (side signs at the class obstacles) and both
%   objectives go to the shared info box. Every glyph class owns a legend
%   entry.
if nargin < 4, opts = struct(); end
G = PRO.F;
X = PRO.CalDec(dec);
R = PRO.CalObjRaw(X);
C = PRO.CalCon(X);
W = [X(1:2:end)', X(2:2:end)'];
pts = [G.start; W; G.goal];
pal = rwmmo_palette;
set(ax, 'FontName','Times New Roman','FontSize',9,'NextPlot','add','Box','on');
hold(ax, 'on');
hObs = gobjects(size(G.obsCenters,1),1);
th = linspace(0, 2*pi, 48);
for k = 1:size(G.obsCenters,1)
    hObs(k) = patch(ax, G.obsCenters(k,1) + G.obsRadii(k)*cos(th), ...
        G.obsCenters(k,2) + G.obsRadii(k)*sin(th), [0.95 0.80 0.80], ...
        'EdgeColor', pal.vermillion, 'LineWidth',0.8, 'FaceAlpha',0.55, 'LineStyle','--');
end
hAxis = plot(ax, [G.boxLower(1), G.boxUpper(1)], [G.mirrorAxis, G.mirrorAxis], ...
    '--', 'Color',[0.5 0.5 0.5], 'LineWidth',0.7);
hPath = plot(ax, pts(:,1), pts(:,2), '-', 'Color', pal.blue, 'LineWidth',1.4);
hWay = plot(ax, W(:,1), W(:,2), 'o', 'MarkerSize',5, 'MarkerFaceColor', pal.yellow, ...
    'MarkerEdgeColor','k', 'LineStyle','none');
hEnd = plot(ax, [G.start(1), G.goal(1)], [G.start(2), G.goal(2)], 's', 'MarkerSize',8, ...
    'MarkerFaceColor', pal.bluishgreen, 'MarkerEdgeColor','k', 'LineStyle','none');
axis(ax, 'equal');
xlim(ax, [G.boxLower(1)-0.3, G.boxUpper(1)+0.3]);
ylim(ax, [G.boxLower(2)-0.3, G.boxUpper(2)+0.3]);
xlabel(ax, 'x [km]','FontName','Times New Roman');
ylabel(ax, 'y [km]','FontName','Times New Roman');
legend(ax, [hObs(1), hAxis, hPath, hWay, hEnd], ...
    {'obstacle','mirror axis','path','waypoint','start/goal'}, ...
    'Location','southoutside', 'Orientation','horizontal', ...
    'FontSize',7.5, 'FontName','Times New Roman');
cl = rwmmo_homotopypath_class(X, G);
if ~isfield(opts,'infoLoc') || isempty(opts.infoLoc), opts.infoLoc = 'northwest'; end
opts.note = {sprintf('homotopy class (s1,s2) = (%d,%d)', cl(1), cl(2)), ...
    sprintf('constraint violation max = %.3g', max(max(C,0)))};
rwmmo_render_header(ax, PRO, opts);
end
