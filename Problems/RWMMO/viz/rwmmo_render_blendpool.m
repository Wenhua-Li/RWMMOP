function rwmmo_render_blendpool(PRO, dec, ax, opts)
%RWMMO_RENDER_BLENDPOOL One blending plan as a process flow sheet.
%   The three feed boxes on the left (A with its tiered contract, B, and the
%   bypass C), the pool in the middle and the twin product contracts on the
%   right; every stream is drawn with a width proportional to its flow rate,
%   solid blue when the stream is active and grey dotted when it is idle, and
%   carries its flow value with white backing. The pool quality is annotated
%   under the pool; the bypass share and the pool quality go to the shared
%   info box through opts.note. Every glyph class owns a legend entry.
if nargin < 4, opts = struct(); end
G = PRO.G;
X = PRO.CalDec(dec);
[uA, uB, v1] = deal(X(1), X(2), X(3));
s = uA + uB;
v2 = s - v1;
w1 = G.D1 - v1;
w2 = G.D2 - v2;
q = (G.qA*uA + G.qB*uB) / max(s, 1e-12);
byp = w1 + w2;
pal = rwmmo_palette;
set(ax, 'FontName','Times New Roman','FontSize',9,'NextPlot','add','Box','on');
hold(ax, 'on');
% --- fixed geometry -----------------------------------------------------------
feedY.A = 4.15; feedY.B = 2.75; feedY.C = 1.15;
pool = [3.1, 3.45]; poolR = 0.5;
prodX = 5.9; prodY = [4.15, 2.75];
bw = 0.62; bh = 0.34;   % feed/product box size
% --- streams (width by flow; grey dotted when idle) ---------------------------
streams = struct('xy',{},'f',{});
streams(1).xy = [1.55, feedY.A; pool(1)-poolR*0.62, pool(2)+poolR*0.62]; streams(1).f = uA;
streams(2).xy = [1.55, feedY.B; pool(1)-poolR*0.62, pool(2)-poolR*0.62]; streams(2).f = uB;
streams(3).xy = [pool(1)+poolR*0.62, pool(2)+poolR*0.45; prodX-bw/2, prodY(1)];   streams(3).f = v1;
streams(4).xy = [pool(1)+poolR*0.62, pool(2)-poolR*0.45; prodX-bw/2, prodY(2)];   streams(4).f = v2;
streams(5).xy = [1.55, feedY.C; 2.45, feedY.C; 2.45, prodY(1)+0.42; prodX-bw/2, prodY(1)+0.42]; streams(5).f = w1;
streams(6).xy = [1.55, feedY.C; 2.45, feedY.C; 2.45, prodY(2)-0.42; prodX-bw/2, prodY(2)-0.42]; streams(6).f = w2;
lbl = {'u_A', 'u_B', 'v_1', 'v_2', 'w_1', 'w_2'};
hActive = gobjects(0,1); hIdle = gobjects(0,1);
for k = 1:6
    f = streams(k).f;
    if f > 1e-6
        h = plot(ax, streams(k).xy(:,1), streams(k).xy(:,2), '-', ...
            'Color', pal.blue, 'LineWidth', 0.8 + 3.2*min(f,150)/150);
        hActive(end+1) = h; %#ok<AGROW>
        mx = mean(streams(k).xy(:,1)); my = mean(streams(k).xy(:,2));
        text(ax, mx, my + 0.14, sprintf('%s = %.4g', lbl{k}, f), ...
            'FontSize', 8, 'FontName','Times New Roman', 'Color', pal.blue, ...
            'HorizontalAlignment','center','VerticalAlignment','bottom', ...
            'BackgroundColor',[1 1 1],'EdgeColor','none','Margin',1);
    else
        h = plot(ax, streams(k).xy(:,1), streams(k).xy(:,2), ':', ...
            'Color', pal.grey, 'LineWidth', 0.8);
        hIdle(end+1) = h; %#ok<AGROW>
    end
end
% --- feed, pool and product glyphs (patches: legend-safe) ---------------------
hBox = gobjects(3,1);
boxSpec = {sprintf('feed A  6/8, S = %g', G.qA), sprintf('feed B  13, S = %g', G.qB), ...
           sprintf('bypass C  11, S = %g', G.qC)};
for k = 1:3
    y = [feedY.A, feedY.B, feedY.C];
    hBox(k) = patch(ax, [0.9, 2.2, 2.2, 0.9], y(k)+bh/2*[1 1 1 1] - [0 0 bh bh], ...
        [1 1 1], 'EdgeColor','k', 'LineWidth',1.0);
    text(ax, 0.9+0.65, y(k), boxSpec{k}, 'FontSize',8, 'FontName','Times New Roman', ...
        'HorizontalAlignment','center','VerticalAlignment','middle');
end
th = linspace(0, 2*pi, 64);
hPool = patch(ax, pool(1)+poolR*cos(th), pool(2)+poolR*sin(th), ...
    pal.skyblue, 'EdgeColor','k', 'LineWidth',1.2);
text(ax, pool(1), pool(2), 'pool', 'FontSize',9, 'FontName','Times New Roman', ...
    'HorizontalAlignment','center','VerticalAlignment','middle','FontWeight','bold');
hProd = gobjects(2,1);
for k = 1:2
    hProd(k) = patch(ax, prodX-bw/2+[0 1.6 1.6 0], ...
        prodY(k)+bh/2*[1 1 1 1] - [0 0 bh bh], [0.96 0.96 0.96], 'EdgeColor','k', 'LineWidth',1.0);
    text(ax, prodX-bw/2+0.8, prodY(k), sprintf('P_%d  75, spec %.1f', k, G.Q1), ...
        'FontSize',8, 'FontName','Times New Roman', ...
        'HorizontalAlignment','center','VerticalAlignment','middle');
end
% --- legend and frame ---------------------------------------------------------
% a fully-active plan (every stream flowing - reachable since the detent
% statement archives interior plans) leaves hIdle empty, and an all-idle
% plan leaves hActive empty: assemble the legend pairs dynamically
% NB: grow by explicit vertcat - linear-index growth (hh(end+1) = ...) turns
% the 0x1 seed into a ROW vector and the vertcat below then fails
hh = gobjects(0,1); lb = {};
if ~isempty(hActive), hh = [hh; hActive(1)]; lb{end+1} = 'active stream (width % flow)'; end
if ~isempty(hIdle),   hh = [hh; hIdle(1)];   lb{end+1} = 'idle stream'; end
hh = [hh; hBox(1); hPool; hProd(1)];
lb = [lb, {'feed / product unit', 'pool', 'product contract'}];
keep = isgraphics(hh);
legend(ax, hh(keep), lb(keep), 'Location','southoutside','Orientation','horizontal', ...
    'NumColumns',3,'FontSize',8,'FontName','Times New Roman');
axis(ax, 'off');
xlim(ax, [0.4, 6.9]); ylim(ax, [0.3, 5.1]);
R = PRO.CalObjRaw(X);
opts.note = sprintf('pool throughput = %.4g, bypass = %.4g, pool sulphur = %.4g', s, byp, q);
if ~isfield(opts,'objRaw') || isempty(opts.objRaw), opts.objRaw = R; end
if ~isfield(opts,'feasible'), opts.feasible = all(PRO.CalCon(X) <= 1e-9); end
rwmmo_render_header(ax, PRO, opts);
end
