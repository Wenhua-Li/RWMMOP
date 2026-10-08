function rwmmo_render_truss(PRO, dec, ax, opts)
%RWMMO_RENDER_TRUSS One sizing plan drawn on the truss geometry.
%   Generic over the frozen instance (RWMMO_Truss10 and RWMMOP10_Truss25): the
%   member count comes from G.members. Members are drawn at their true
%   positions with a line width proportional to the area and a colour by
%   stress utilisation |sigma|/sigmaAllow (bluishgreen slack, vermillion at
%   the limit); nodes, the loads and the fixed edge carry their own glyphs.
%   Utilisation and both objective values go to the shared info box; every
%   glyph class owns a legend entry.
if nargin < 4, opts = struct(); end
G = PRO.G;
X = PRO.CalDec(dec);
R = PRO.CalObjRaw(X);
C = PRO.CalCon(X);
uti = min(abs(C) + 1, 1);                       % |sigma|/sigmaAllow, capped at 1
uti = abs(C + PRO.G.sigmaAllow) / PRO.G.sigmaAllow;
uti = min(uti, 1.2);
pal = rwmmo_palette;
set(ax, 'FontName','Times New Roman','FontSize',9,'NextPlot','add','Box','on');
hold(ax, 'on');
nM = size(G.members,1);
hMem = gobjects(1,nM);
for m = 1:nM
    p = G.nodes(G.members(m,1),:); q = G.nodes(G.members(m,2),:);
    col = utilColor(uti(m));
    hMem(m) = plot(ax, [p(1),q(1)], [p(2),q(2)], '-', 'Color', col, ...
        'LineWidth', 1.0 + 5.0 * X(m)/G.upper(1));
    mid = (p + q)/2;
    if uti(m) > 0.999
        text(ax, mid(1), mid(2), sprintf('m%d', m), 'FontSize', 7.5, ...
            'FontName','Times New Roman', 'HorizontalAlignment','center', ...
            'VerticalAlignment','bottom', 'BackgroundColor',[1 1 1], ...
            'EdgeColor','none','Margin',0.5);
    end
end
hNode = plot(ax, G.nodes(:,1), G.nodes(:,2), 'o', 'MarkerSize', 6, ...
    'MarkerFaceColor', pal.yellow, 'MarkerEdgeColor', 'k', 'LineStyle','none');
% loads: downward arrows at both loaded nodes
hLoad = gobjects(1,1);
for k = 1:numel(G.loadNodes)
    nx = G.nodes(G.loadNodes(k),1); ny = G.nodes(G.loadNodes(k),2);
    hL = annotationQuiver(ax, nx, ny + 0.22, nx, ny + 0.06, pal.blue);
    if k == 1, hLoad = hL; end
    text(ax, nx, ny + 0.30, sprintf('%g kN', G.loadPerNode/1e3), 'FontSize', 8, ...
        'FontName','Times New Roman', 'HorizontalAlignment','center', ...
        'VerticalAlignment','bottom', 'BackgroundColor',[1 1 1],'EdgeColor','none','Margin',0.5);
end
% fixed edge hatch at both right nodes
hFix = [];
for k = 1:numel(G.fixed)
    nx = G.nodes(G.fixed(k),1); ny = G.nodes(G.fixed(k),2);
    h = plot(ax, nx + [0, 0.12, 0.24], ny + [0.14, -0.02, 0.14], 'k-', 'LineWidth', 1.0);
    if isempty(hFix), hFix = h; end
end
% legend and frame
hh = [hMem(1), hNode, hLoad, hFix];
lb = {'member (width % area, colour = utilisation)', 'free node', ...
    sprintf('load %g kN', G.loadPerNode/1e3), 'fixed support'};
keep = isgraphics(hh);
legend(ax, hh(keep), lb(keep), 'Location','southoutside','Orientation','horizontal', ...
    'NumColumns',2,'FontSize',8,'FontName','Times New Roman');
grid(ax, 'on');
xlabel(ax, 'x (m)'); ylabel(ax, 'y (m)');
xl = [min(G.nodes(:,1)), max(G.nodes(:,1))]; yl = [min(G.nodes(:,2)), max(G.nodes(:,2))];
padx = 0.12*range(xl); pady = 0.18*range(yl);
xlim(ax, [xl(1)-padx, xl(2)+2.2*padx]); ylim(ax, [yl(1)-pady, yl(2)+pady]);
axis(ax, 'equal');
opts.note = sprintf('max utilisation = %.3f (member %d), A in [%.2f, %.2f] cm^2', ...
    max(uti), find(uti == max(uti),1), min(X)*1e4, max(X)*1e4);
if ~isfield(opts,'objRaw') || isempty(opts.objRaw), opts.objRaw = R; end
if ~isfield(opts,'feasible'), opts.feasible = all(C <= 0); end
rwmmo_render_header(ax, PRO, opts);
end

function c = utilColor(u)
%Bluishgreen (slack) to vermillion (at the limit), Okabe-Ito endpoints.
lo = [0.000 0.620 0.451]; hi = [0.835 0.369 0.000];
t = min(max(u, 0), 1);
c = lo + t * (hi - lo);
end

function h = annotationQuiver(ax, x0, y0, x1, y1, col)
%Small arrow drawn as a line plus a triangular head (quiver-style).
h = plot(ax, [x0, x1], [y0, y1], '-', 'Color', col, 'LineWidth', 1.6);
dx = x1 - x0; dy = y1 - y0; L = hypot(dx, dy);
ux = dx / L; uy = dy / L;
hx = x1 - 0.05*ux; hy = y1 - 0.05*uy;
patch(ax, [x1, hx - 0.03*uy, hx + 0.03*uy], [y1, hy + 0.03*ux, hy - 0.03*ux], ...
    col, 'EdgeColor', 'none');
end
