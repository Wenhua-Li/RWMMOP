function rwmmo_render_windfarm(PRO, dec, ax, opts)
%RWMMO_RENDER_WINDFARM One turbine layout drawn on the frozen site.
%   The site polygon is a light patch, the exclusion zones are hatched
%   circles, the substation a square; collection-cable edges of the layout's
%   own minimum spanning tree are drawn in blue, turbines as rotor circles
%   coloured by their share of the farm energy under the dominant wind
%   sector, and the wake cone of every turbine under that sector as a thin
%   grey wedge. Energy share, cable length and both objectives go to the
%   shared info box; every glyph class owns a legend entry.
if nargin < 4, opts = struct(); end
G = PRO.F;
X = PRO.CalDec(dec);
R = PRO.CalObjRaw(X);
C = PRO.CalCon(X);
Px = X(1:2:end); Py = X(2:2:end);
N = G.N;
pal = rwmmo_palette;
set(ax, 'FontName','Times New Roman','FontSize',9,'NextPlot','add','Box','on');
hold(ax, 'on');
% site and exclusion zones
hSite = patch(ax, G.sitePolygon(:,1), G.sitePolygon(:,2), [0.92 0.95 0.92], ...
    'EdgeColor',[0.3 0.3 0.3], 'LineWidth',1.0);
hZone = gobjects(size(G.exclCenters,1),1);
th = linspace(0, 2*pi, 48);
for k = 1:size(G.exclCenters,1)
    hZone(k) = patch(ax, G.exclCenters(k,1) + G.exclRadii(k)*cos(th), ...
        G.exclCenters(k,2) + G.exclRadii(k)*sin(th), [0.95 0.80 0.80], ...
        'EdgeColor', pal.vermillion, 'LineWidth',0.8, 'FaceAlpha',0.55, ...
        'LineStyle','--');
end
hSub = plot(ax, G.substation(1), G.substation(2), 's', 'MarkerSize',9, ...
    'MarkerFaceColor', pal.yellow, 'MarkerEdgeColor','k');
% cable MST (Prim, deterministic)
nodes = [Px(:) Py(:); G.substation];
Dm = sqrt((nodes(:,1)-nodes(:,1)').^2 + (nodes(:,2)-nodes(:,2)').^2);
V = size(nodes,1);
inTree = false(V,1); inTree(1) = true;
best = Dm(1,:);
hCable = gobjects(V-1,1);
e = 0;
for k = 2:V
    cand = best; cand(inTree) = inf;
    [~, bi] = min(cand);
    e = e + 1;
    prev = find(inTree' & abs(Dm(bi,:) - best(bi)) < 1e-12, 1);
    if isempty(prev), prev = 1; end
    hCable(e) = plot(ax, [nodes(bi,1), nodes(prev,1)], [nodes(bi,2), nodes(prev,2)], ...
        '-', 'Color', pal.blue, 'LineWidth',1.2);
    inTree(bi) = true;
    best = min(best, Dm(bi,:));
end
% per-turbine energy under the dominant sector + wake cones
[~, sDom] = max(G.windFreq);
t = [cosd(G.windDirDeg(sDom)+180), sind(G.windDirDeg(sDom)+180)];
ct = 1 - sqrt(1 - G.thrustCt);
DX = Px(:) - Px(:)'; DY = Py(:) - Py(:)';
along = DX*t(1) + DY*t(2);
lat = sqrt(max(DX.^2 + DY.^2 - along.^2, 0));
rw = G.rotorRadius + G.wakeDecay*max(along,0);
infl = (along > 0) & (lat < rw);
delta = ct * (G.rotorRadius./rw).^2 .* infl;
v = G.windSpeed(sDom) * (1 - sqrt(sum(delta.^2, 2)'));
v = max(v, 0);
p = windPower(v, G);
share = p / max(sum(p), eps);
hWake = gobjects(N,1);
for i = 1:N
    Lc = 2.0;                                   % cone length, km (visual only)
    side = [-t(2), t(1)];
    wEnd = G.rotorRadius + G.wakeDecay*Lc;
    hWake(i) = patch(ax, [Px(i)+G.rotorRadius*t(1), Px(i)+Lc*t(1)+wEnd*side(1), Px(i)+Lc*t(1)-wEnd*side(1)], ...
        [Py(i)+G.rotorRadius*t(2), Py(i)+Lc*t(2)+wEnd*side(2), Py(i)+Lc*t(2)-wEnd*side(2)], ...
        [0.7 0.7 0.7], 'EdgeColor','none', 'FaceAlpha',0.25);
end
hTurb = gobjects(N,1);
for i = 1:N
    col = shareColor(share(i));
    hTurb(i) = plot(ax, Px(i), Py(i), 'o', 'MarkerSize',11, ...
        'MarkerFaceColor',col, 'MarkerEdgeColor','k');
end
axis(ax, 'equal');
xlim(ax, [G.boxLower(1)-0.3, G.boxUpper(1)+0.3]);
ylim(ax, [G.boxLower(2)-0.3, G.boxUpper(2)+0.3]);
xlabel(ax, 'x [km]','FontName','Times New Roman');
ylabel(ax, 'y [km]','FontName','Times New Roman');
hh = [hSite, hZone(1), hSub, hCable(1), hWake(1), hTurb(1)];
lb = {'site polygon','exclusion zone','substation','collection cable (MST)', ...
    sprintf('wake cone (sector %d deg)', G.windDirDeg(sDom)), 'turbine (colour = energy share)'};
legend(ax, hh, lb, 'Location','southoutside', 'Orientation','horizontal', ...
    'FontSize',7.5, 'FontName','Times New Roman');
if ~isfield(opts,'infoLoc') || isempty(opts.infoLoc), opts.infoLoc = 'northwest'; end
note = {sprintf('dominant sector %d deg, freq %.2f, U %.1f m/s', G.windDirDeg(sDom), G.windFreq(sDom), G.windSpeed(sDom)), ...
    sprintf('energy share min/med/max = %.2f/%.2f/%.2f', min(share), median(share), max(share)), ...
    sprintf('constraint violation max = %.3g', max(max(C,0)))};
opts.note = note;
rwmmo_render_header(ax, PRO, opts);
end

function p = windPower(v, G)
p = zeros(size(v));
mR = v >= G.rated & v <= G.cutOut;
p(mR) = G.ratedMW;
mC = v >= G.cutIn & v < G.rated;
p(mC) = G.ratedMW * (v(mC).^3 - G.cutIn^3) / (G.rated^3 - G.cutIn^3);
end

function c = shareColor(s)
%bluishgreen (low share) to vermillion (high share), Okabe-Ito endpoints
pal = rwmmo_palette;
s = min(max(s/0.35, 0), 1);
c = (1-s)*pal.bluishgreen + s*pal.vermillion;
end
