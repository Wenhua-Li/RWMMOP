function rwmmo_render_nesting(PRO, dec, ax, opts)
%RWMMO_RENDER_NESTING One nesting layout drawn on the frozen sheet.
%   The sheet is a light patch, each part an Okabe-Ito coloured polygon
%   outline (L-parts drawn as their rectangle union), the layout bounding
%   box a dashed rectangle; part centres carry dots. Bounding-box area,
%   spread and the worst constraint violation go to the shared info box.
if nargin < 4, opts = struct(); end
G = PRO.F;
X = PRO.CalDec(dec);
R = PRO.CalObjRaw(X);
C = PRO.CalCon(X);
pal = rwmmo_palette;
base = [pal.orange; pal.skyblue; pal.bluishgreen; pal.yellow; pal.blue; ...
    pal.vermillion; pal.reddishpurple; pal.black];
set(ax, 'FontName','Times New Roman','FontSize',9,'NextPlot','add','Box','on');
hold(ax, 'on');
hSheet = patch(ax, [0 G.sheet(1) G.sheet(1) 0], [0 0 G.sheet(2) G.sheet(2)], ...
    [0.93 0.93 0.93], 'EdgeColor',[0.3 0.3 0.3], 'LineWidth',1.0);
allX = []; allY = [];
hPart = gobjects(G.nParts,1);
for p = 1:G.nParts
    px = X(3*p-2); py = X(3*p-1); pt = X(3*p);
    Rt = [cos(pt) -sin(pt); sin(pt) cos(pt)];
    r = G.partRects{p};
    col = base(mod(p-1, size(base,1))+1, :);
    for k = 1:size(r,1)
        hx = r(k,3)/2; hy = r(k,4)/2;
        lc = [r(k,1)-hx r(k,2)-hy; r(k,1)+hx r(k,2)-hy; r(k,1)+hx r(k,2)+hy; r(k,1)-hx r(k,2)+hy];
        gc = lc*Rt' + [px py];
        hPart(p) = patch(ax, gc(:,1), gc(:,2), col, 'EdgeColor','k', 'LineWidth',0.8, ...
            'FaceAlpha',0.75);
        allX = [allX; gc(:,1)]; %#ok<AGROW>
        allY = [allY; gc(:,2)]; %#ok<AGROW>
    end
end
hBox = plot(ax, [min(allX) max(allX) max(allX) min(allX) min(allX)], ...
    [min(allY) min(allY) max(allY) max(allY) min(allY)], '--', ...
    'Color', pal.vermillion, 'LineWidth',1.0);
axis(ax, 'equal');
xlim(ax, [-0.5, G.sheet(1)+0.5]);
ylim(ax, [-0.5, G.sheet(2)+0.5]);
xlabel(ax, 'x','FontName','Times New Roman');
ylabel(ax, 'y','FontName','Times New Roman');
legend(ax, [hSheet, hPart(1), hBox], {'sheet','part (colour = index)','layout bounding box'}, ...
    'Location','southoutside', 'Orientation','horizontal', ...
    'FontSize',7.5, 'FontName','Times New Roman');
if ~isfield(opts,'infoLoc') || isempty(opts.infoLoc), opts.infoLoc = 'northwest'; end
opts.note = {sprintf('bbox = %.2f x %.2f', max(allX)-min(allX), max(allY)-min(allY)), ...
    sprintf('constraint violation max = %.3g', max(max(C,0)))};
rwmmo_render_header(ax, PRO, opts);
end
