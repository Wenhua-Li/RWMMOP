function rwmmo_render_map(PRO, dec, ax, opts)
%RWMMO_RENDER_MAP Emergency facility location on the study-area map.
%   Feasible-region raster, forbidden geography (two corridors, five
%   disks, one convex polygon), the three facility sets, and for THIS
%   solution the chosen site with tie lines to the nearest point of each
%   set. Every glyph class owns a legend entry; the site coordinates live
%   in the shared info box, and each distance label sits a fixed step
%   beyond its nearest facility point (never at the tie midpoint) with
%   white backing, so labels cannot collide with the site marker or each
%   other. A 2 km scale bar sits in the bottom-left corner. Distances
%   come from rwmmo_site_objectives, the evaluator the objectives use.
if nargin < 4, opts = struct(); end
G = PRO.G;
X = PRO.CalDec(dec);
site = X(:)';
pal = rwmmo_palette;
set(ax, 'FontName','Times New Roman','FontSize',9,'NextPlot','add','Box','on');
hold(ax, 'on');
xs = linspace(G.domain(1,1), G.domain(2,1), 300);
ys = linspace(G.domain(1,2), G.domain(2,2), 180);
[XX,YY] = meshgrid(xs, ys);
F = rwmmo_site_objectives([XX(:) YY(:)], G).feasible;
ZZ = reshape(double(F), size(XX));
imagesc(ax, xs, ys, ZZ); set(ax, 'YDir', 'normal');
colormap(ax, [0.92 0.92 0.92; 1 1 1]);
th = linspace(0, 2*pi, 200);
hForb = gobjects(0,1);
for k = 1:size(G.disks,1)
    h = plot(ax, G.disks(k,1)+G.disks(k,3)*cos(th), G.disks(k,2)+G.disks(k,3)*sin(th), ...
        '-', 'Color', pal.vermillion, 'LineWidth', 1.0);
    if isempty(hForb), hForb = h; end
end
P = G.polygon;
plot(ax, [P(:,1); P(1,1)], [P(:,2); P(1,2)], '-', 'Color', pal.vermillion, 'LineWidth', 1.0);
hCorr = gobjects(0,1);
for k = 1:2
    Cc = G.(['corridor' num2str(k)]);
    hw = G.corridorHalfWidth(k);
    d = Cc(2,:) - Cc(1,:); d = d / norm(d); nrm = [-d(2) d(1)];
    h1 = plot(ax, [Cc(1,1)+hw*nrm(1) Cc(2,1)+hw*nrm(1)], [Cc(1,2)+hw*nrm(2) Cc(2,2)+hw*nrm(2)], ...
        '-', 'Color', pal.darkgrey, 'LineWidth', 1.0);
    plot(ax, [Cc(1,1)-hw*nrm(1) Cc(2,1)-hw*nrm(1)], [Cc(1,2)-hw*nrm(2) Cc(2,2)-hw*nrm(2)], ...
        '-', 'Color', pal.darkgrey, 'LineWidth', 1.0);
    if isempty(hCorr), hCorr = h1; end
end
S = {G.S1, G.S2, G.S3}; mk = {'o','s','^'}; nm = {'residential','commercial','transport hub'};
hSets = gobjects(1,3);
for k = 1:3
    hSets(k) = plot(ax, S{k}(:,1), S{k}(:,2), mk{k}, 'Color', pal.bluishgreen, ...
        'MarkerFaceColor', pal.bluishgreen, 'MarkerSize', 4, 'LineStyle', 'none');
end
hTie = gobjects(0,1);
placed = zeros(0,2);
for k = 1:3
    [dmin, j] = min(sum((S{k} - site).^2, 2));
    h = plot(ax, [site(1), S{k}(j,1)], [site(2), S{k}(j,2)], '-', 'Color', pal.blue, 'LineWidth', 1.3);
    if isempty(hTie), hTie = h; end
    d = S{k}(j,:) - site; L = norm(d);
    if L > 0, u = d / L; else, u = [0, 1]; end
    % Fixed step beyond the nearest facility point (never the tie
    % midpoint), so the label cannot sit under the site marker. A
    % near-zero distance has no meaningful direction away from the facility
    % point (site and facility coincide), so its label moves to a fixed
    % offset above the star. Stepping continues while another label, the
    % star, or a forbidden-disk outline sits under the white label box.
    if sqrt(dmin) < 0.45
        mx = site(1); my = site(2) + 0.55; u = [0, 1];
    else
        mx = S{k}(j,1) + 0.28*u(1);
        my = S{k}(j,2) + 0.28*u(2);
    end
    nudge = 0;
    while nudge < 12 && (any(abs(placed(:,1)-mx) < 0.55 & abs(placed(:,2)-my) < 0.30) || ...
            norm([mx, my] - site) < 0.45 || diskHit(G, mx, my))
        mx = mx + 0.30*u(1);
        my = my + 0.30*u(2);
        nudge = nudge + 1;
    end
    mx = min(max(mx, G.domain(1,1)+0.35), G.domain(2,1)-0.35);
    my = min(max(my, G.domain(1,2)+0.15), G.domain(2,2)-0.15);
    placed(end+1,:) = [mx, my]; %#ok<AGROW>
    text(ax, mx, my, sprintf('%.2f km', sqrt(dmin)), ...
        'FontSize', 7.5, 'FontName','Times New Roman', 'Color', pal.blue, ...
        'HorizontalAlignment','center','VerticalAlignment','middle', ...
        'BackgroundColor',[1 1 1],'EdgeColor','none','Margin',1);
end
hSite = plot(ax, site(1), site(2), 'p', 'MarkerSize', 14, 'MarkerFaceColor', pal.yellow, ...
    'MarkerEdgeColor', 'k', 'LineWidth', 1.0);
% 2 km scale bar, bottom-left inside the domain
bx0 = G.domain(1,1) + 0.3; by0 = G.domain(1,2) + 0.25;
plot(ax, [bx0, bx0+2], [by0, by0], 'k-', 'LineWidth', 2.5);
plot(ax, [bx0, bx0], [by0-0.05, by0+0.05], 'k-', 'LineWidth', 1.5);
plot(ax, [bx0+2, bx0+2], [by0-0.05, by0+0.05], 'k-', 'LineWidth', 1.5);
text(ax, bx0+1, by0+0.12, '2 km', 'HorizontalAlignment','center','VerticalAlignment','bottom', ...
    'FontSize', 8, 'FontName','Times New Roman');
grid(ax, 'on');
xlabel(ax, 'x_1 (km)'); ylabel(ax, 'x_2 (km)');
xlim(ax, [G.domain(1,1), G.domain(2,1)]);
ylim(ax, [G.domain(1,2), G.domain(2,2) + 1.4]);   % top band for the info box (tall enough to clear the corridors)
axis(ax, 'equal');
hh = [hSite, hTie, hSets, hForb, hCorr];
lb = [{'chosen site'}, {'nearest-set distance'}, nm, {'forbidden zones'}, {'transport corridors'}];
keep = isgraphics(hh);
legend(ax, hh(keep), lb(keep), 'Location','southoutside','Orientation','horizontal', ...
    'NumColumns',4,'FontSize',8,'FontName','Times New Roman');
R = PRO.CalObjRaw(X);
opts.note = sprintf('site = (%.3f, %.3f) km', site(1), site(2));
if ~isfield(opts,'objRaw') || isempty(opts.objRaw), opts.objRaw = R; end
if ~isfield(opts,'feasible'), opts.feasible = rwmmo_site_objectives(site, G).feasible; end
rwmmo_render_header(ax, PRO, opts);
end

function hit = diskHit(G, x, y)
% true when the white label box at (x, y) would overlap a forbidden-disk
% outline. The box is wider than tall (~0.85 x 0.3 data units), so the test
% uses the box half-diagonal as slack around the circle.
hit = false;
for k = 1:size(G.disks,1)
    if norm([x, y] - G.disks(k,1:2)) < G.disks(k,3) + 0.95
        hit = true; return;
    end
end
end
