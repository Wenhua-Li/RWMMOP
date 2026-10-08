function rwmmo_render_microgrid(PRO, dec, ax, opts)
%RWMMO_RENDER_MICROGRID Microgrid network design on true coordinates.
%   Buses at their real positions (MCS.POS); distributed generators carry a
%   generator symbol, load buses scale with LOAD. Selected candidate edges
%   are solid blue, unselected ones grey dotted. Bus labels use a fixed
%   axis-unit offset with an edge-aware flip so they stay attached to
%   their nodes. Metrics go to the shared info box; a glyph legend covers
%   the four symbol classes.
if nargin < 4, opts = struct(); end
MCS = PRO.MCS;
X = PRO.CalDec(dec);
sel = logical(X(:)');
cand = PRO.Cand;
pal = rwmmo_palette;
set(ax, 'FontName','Times New Roman','FontSize',9,'NextPlot','add','Box','on');
hold(ax, 'on');
hBuilt = gobjects(0,1); hCand = gobjects(0,1);
for e = 1:size(cand,1)
    u = cand(e,1); v = cand(e,2);
    if sel(e)
        h = plot(ax, [MCS.POS(u,1), MCS.POS(v,1)], [MCS.POS(u,2), MCS.POS(v,2)], '-', ...
            'Color', pal.blue, 'LineWidth', 2.2);
        if isempty(hBuilt), hBuilt = h; end
    else
        h = plot(ax, [MCS.POS(u,1), MCS.POS(v,1)], [MCS.POS(u,2), MCS.POS(v,2)], ':', ...
            'Color', pal.grey, 'LineWidth', 1.0);
        if isempty(hCand), hCand = h; end
    end
end
n = size(MCS.POS,1);
ymax = max(MCS.POS(:,2)); ymin = min(MCS.POS(:,2));
hh = gobjects(0,1); lb = {};
for k = 1:n
    isDG = ismember(k, MCS.DG(:));
    if isDG
        h = plot(ax, MCS.POS(k,1), MCS.POS(k,2), '^', 'MarkerSize', 11, ...
            'MarkerFaceColor', pal.orange, 'MarkerEdgeColor', 'k');
        if ~any(strcmp(lb, 'distributed generator')), hh(end+1) = h; lb{end+1} = 'distributed generator'; end %#ok<AGROW>
    else
        ms = 5 + 9 * MCS.LOAD(k) / max(MCS.LOAD);
        h = plot(ax, MCS.POS(k,1), MCS.POS(k,2), 'o', 'MarkerSize', ms, ...
            'MarkerFaceColor', [1 1 1], 'MarkerEdgeColor', 'k');
        if ~any(strcmp(lb, 'load bus')), hh(end+1) = h; lb{end+1} = 'load bus'; end %#ok<AGROW>
    end
    dy = 0.16 * max(1, ymax - ymin) / 10; va = 'bottom';
    if MCS.POS(k,2) > ymax - 2*dy, dy = -1.4*dy; va = 'top'; end  % near top: label below
    text(ax, MCS.POS(k,1), MCS.POS(k,2)+dy, sprintf('%d', k), ...
        'HorizontalAlignment','center','VerticalAlignment',va, ...
        'FontSize',8,'FontName','Times New Roman');
end
grid(ax, 'on');
xlabel(ax, 'x (pu distance)'); ylabel(ax, 'y (pu distance)');
yl = ylim(ax); ylim(ax, [yl(1), yl(2)+1.2]);   % top band for the info box
hh = [hBuilt, hCand, hh]; lb = [{'built edge'}, {'candidate edge'}, lb];
keep = isgraphics(hh);
legend(ax, hh(keep), lb(keep), ...
    'Location','southeast','FontSize',8,'FontName','Times New Roman');
R = PRO.CalObjRaw(X);
C = PRO.CalCon(X);
totalLen = 0;
for e = 1:numel(sel)
    if sel(e), totalLen = totalLen + MCS.DIST(cand(e,1), cand(e,2)); end
end
% second-objective label is class-specific: NetworkDesign8Sparse（退役） measures three-edge-failure
% resilience, RWMMOP14 (Net12Sparse) measures single-edge bridge exposure.
if isa(PRO, 'RWMMOP14_Net12Sparse')
    lab2 = 'bridge exposure';
else
    lab2 = 'unreachable pairs';
end
opts.note = sprintf('built length = %.4g, %s = %.4g, constraint violation = %.4g', ...
    totalLen, lab2, R(2), sum(max(C(:), 0)));
if ~isfield(opts,'objRaw') || isempty(opts.objRaw), opts.objRaw = R; end
if ~isfield(opts,'feasible'), opts.feasible = all(C <= 0, 2); opts.conValue = C; end
rwmmo_render_header(ax, PRO, opts);
end
