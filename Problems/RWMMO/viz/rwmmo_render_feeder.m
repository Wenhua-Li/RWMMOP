function rwmmo_render_feeder(PRO, dec, ax, opts)
%RWMMO_RENDER_FEEDER Radial one-line diagram of a distribution feeder.
%   Deterministic tidy-tree layout (the snapshots carry no coordinates):
%   the closed branches form a BFS tree from the slack bus; x is the BFS
%   depth, y a DFS leaf-slot index (leaves get consecutive slots, internal
%   buses sit at the mean of their children), so sibling subtrees occupy
%   contiguous, disjoint vertical bands and edges never cross. Closed
%   branches are solid, open tie switches vermillion dashed, bus markers
%   scale with the load, the slack is a yellow square. RWMMOP13 (DNR33MP)
%   stacks the two period topologies vertically. Buses unreachable from
%   the slack (a non-radial, infeasible input) are parked in a grey
%   island row instead of crashing the figure.
if nargin < 4, opts = struct(); end
cls = class(PRO);
pal = rwmmo_palette;
set(ax, 'FontName','Times New Roman','FontSize',9,'NextPlot','add','Box','off');
hold(ax, 'on');
switch cls
    case 'RWMMOP13_DNR33MP'
        MP = PRO.MP;
        Fsub = MP.F;
        X = PRO.CalDec(dec);
        R = PRO.CalObjRaw(X);
        yShift = 0;
        for per = 1:2
            closed = logical(MP.topos(X(per), :));
            [pos, isl] = layoutTidy(Fsub.branchFrom, Fsub.branchTo, closed, Fsub.slack);
            if per == 2
                yShift = min(pos(:,2)) - (maxSlot + 3);
            end
            pos(:,2) = pos(:,2) + yShift;
            if per == 1
                maxSlot = max(pos(:,2)); %#ok<AGROW>
            end
            drawTopology(ax, Fsub, pos, closed, isl, pal);
            text(ax, min(pos(:,1))-0.6, mean([max(pos(:,2)), min(pos(:,2))]), ...
                sprintf('period %d', per), 'HorizontalAlignment','right', ...
                'VerticalAlignment','middle','FontSize',9,'FontName','Times New Roman');
        end
        finishFeederAxes(ax, pal);
        opts.note = sprintf('period losses %.4g / %.4g kW, switching operations = %.4g', R(1), R(2), R(3));
        if ~isfield(opts,'objRaw') || isempty(opts.objRaw), opts.objRaw = R; end
        if ~isfield(opts,'feasible'), opts.feasible = all(PRO.CalCon(X) <= 0, 2); opts.conValue = PRO.CalCon(X); end
    otherwise
        F = PRO.F;
        X = PRO.CalDec(dec);
        closed = logical(X(:)');
        [pos, isl] = layoutTidy(F.branchFrom, F.branchTo, closed, F.slack);
        R = PRO.CalObjRaw(X);
        drawTopology(ax, F, pos, closed, isl, pal);
        finishFeederAxes(ax, pal);
        if strcmp(cls, 'RWMMOP12_DNR33MS')
            opts.note = sprintf('base loss %.4g kW, peak VDI %.4g, switching operations %.4g', R(1), R(2), R(3));
        else
            opts.note = sprintf('loss %.4g kW, VDI %.4g, switching operations %.4g', R(1), R(2), R(3));
        end
        if any(isl)
            opts.note = [opts.note, {sprintf('%d islanded buses (infeasible input)', sum(isl))}];
        end
        if ~isfield(opts,'objRaw') || isempty(opts.objRaw), opts.objRaw = R; end
        if ~isfield(opts,'feasible'), opts.feasible = all(PRO.CalCon(X) <= 0, 2); opts.conValue = PRO.CalCon(X); end
end
rwmmo_render_header(ax, PRO, opts);
end

function finishFeederAxes(ax, pal)
%FINISHFEEDERAXES Shared axis cosmetics, top info band and glyph legend.
xl = xlim(ax); yl = ylim(ax);
xlim(ax, [xl(1)-1.0, xl(2)+1.5]);
ylim(ax, [yl(1)-0.8, yl(2)+2.4]);   % top band reserved for the info box
axis(ax, 'equal'); axis(ax, 'off');
hC = plot(ax, nan, nan, '-',  'Color', pal.black,      'LineWidth', 1.2);
hT = plot(ax, nan, nan, '--', 'Color', pal.vermillion, 'LineWidth', 1.0);
hS = plot(ax, nan, nan, 's', 'MarkerSize', 9, 'MarkerFaceColor', pal.yellow, 'MarkerEdgeColor', 'k');
hL = plot(ax, nan, nan, 'o', 'MarkerSize', 7, 'MarkerFaceColor', [1 1 1],   'MarkerEdgeColor', 'k');
legend(ax, [hC, hT, hS, hL], {'closed branch','open tie switch','slack bus','load bus'}, ...
    'Location','southoutside','Orientation','horizontal','FontSize',8, ...
    'FontName','Times New Roman','Box','off');
end

function drawTopology(ax, F, pos, closed, isl, pal)
%DRAWTOPOLOGY Edges first (ties under closed lines), then buses and labels.
n = numel(F.branchFrom);
for b = 1:n
    u = F.branchFrom(b); v = F.branchTo(b);
    if ~closed(b) && F.branchIsTie(b)
        plot(ax, [pos(u,1), pos(v,1)], [pos(u,2), pos(v,2)], '--', ...
            'Color', pal.vermillion, 'LineWidth', 1.0);
    end
end
for b = 1:n
    u = F.branchFrom(b); v = F.branchTo(b);
    if closed(b)
        plot(ax, [pos(u,1), pos(v,1)], [pos(u,2), pos(v,2)], '-', ...
            'Color', pal.black, 'LineWidth', 1.2);
    end
end
loadAbs = sqrt(F.busP(:).^2 + F.busQ(:).^2);
ms = 5 + 7 * loadAbs / max(loadAbs);
for k = 1:numel(F.busP)
    if k == F.slack
        plot(ax, pos(k,1), pos(k,2), 's', 'MarkerSize', 10, ...
            'MarkerFaceColor', pal.yellow, 'MarkerEdgeColor', 'k', 'LineWidth', 1.0);
    elseif isl(k)
        plot(ax, pos(k,1), pos(k,2), 's', 'MarkerSize', 6, ...
            'MarkerFaceColor', pal.grey, 'MarkerEdgeColor', 'k', 'LineWidth', 0.6);
    else
        plot(ax, pos(k,1), pos(k,2), 'o', 'MarkerSize', ms(k), ...
            'MarkerFaceColor', [1 1 1], 'MarkerEdgeColor', 'k', 'LineWidth', 0.8);
    end
    text(ax, pos(k,1), pos(k,2)+0.38, sprintf('%d', k), 'HorizontalAlignment','center', ...
        'VerticalAlignment','bottom','FontSize', 7.5, 'FontName','Times New Roman');
end
end

function [pos, isl] = layoutTidy(from, to, closed, slack)
%LAYOUTTIDY Deterministic tidy-tree placement: x = BFS depth from the slack
% bus over closed branches, y = DFS leaf slot (internal buses take the mean
% of their children's slots). Contiguous subtree bands => no edge crossings.
n = max([from(:); to(:)]);
adj = cell(n,1);
for b = 1:numel(from)
    if closed(b)
        adj{from(b)}(end+1) = to(b); %#ok<AGROW>
        adj{to(b)}(end+1) = from(b); %#ok<AGROW>
    end
end
layer = -ones(1,n); parent = zeros(1,n);
layer(slack) = 0; q = slack;
while ~isempty(q)
    v = q(1); q(1) = [];
    kids = sort(adj{v});
    for z = 1:numel(kids)
        u = kids(z);
        if layer(u) < 0
            layer(u) = layer(v) + 1; parent(u) = v; q(end+1) = u; %#ok<AGROW>
        end
    end
end
children = cell(n,1);
for v = 1:n
    if parent(v) > 0
        children{parent(v)}(end+1) = v;
    end
end
for v = 1:n
    if ~isempty(children{v}), children{v} = sort(children{v}); end
end
y = zeros(1,n); slot = 0;
stack = slack;
seen = false(1,n);
% iterative DFS assigning slots in first-visit order
while ~isempty(stack)
    v = stack(end);
    if ~seen(v)
        seen(v) = true;
        ch = children{v};
        if isempty(ch)
            slot = slot + 1; y(v) = slot; stack(end) = [];
        else
            stack = [stack, fliplr(ch)]; %#ok<AGROW>
        end
    else
        ch = children{v};
        y(v) = mean(y(ch)); stack(end) = [];
    end
end
isl = layer < 0;
pos = zeros(n,2);
pos(:,1) = layer;
pos(:,2) = y;
if any(isl)
    pos(isl,1) = max(layer(~isl)) + 1;
    pos(isl,2) = 1:sum(isl);
end
end
