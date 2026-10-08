function rwmmo_render_gantt_satellite(PRO, dec, ax, opts)
%RWMMO_RENDER_GANTT_SATELLITE TT&C equipment timelines for one schedule.
%   One row per ground equipment; bars are the executed lap windows
%   coloured by request PRIORITY (turbo colormap + colorbar, the
%   domain-meaningful attribute), with the request id on wide bars. The
%   timeline comes from satellite_calobj_legacy, the exact evaluator
%   behind both objectives, so executed/unexecuted status is the
%   evaluated one. Unexecuted requirements are listed in the shared info
%   box (wrapped), never floating over the bars.
if nargin < 4, opts = struct(); end
C = PRO.Case;
q = PRO.Decode(dec);
out = satellite_calobj_legacy(q, C);
o = out(1);
set(ax, 'FontName','Times New Roman','FontSize',9,'NextPlot','add','Box','on');
hold(ax, 'on');
pAll = C.Preq(:);
pLo = min(pAll); pHi = max(pAll);
cmap = turbo(256);
tMax = 1;
for e = 1:C.Nequ
    arcs = o.equip_info{e};
    for k = 1:size(arcs,1)
        s = arcs(k,1); t = arcs(k,2); sat = arcs(k,3);
        if pHi > pLo
            ci = 1 + round(255 * (C.Preq(sat) - pLo) / (pHi - pLo));
        else
            ci = 128;
        end
        patch(ax, [s, t, t, s], [e-0.38, e-0.38, e+0.38, e+0.38], cmap(ci,:), ...
            'EdgeColor', 'k', 'LineWidth', 0.4);
        if t - s > 0.03 * max(tMax, max(arcs(:,2)))
            text(ax, (s+t)/2, e, sprintf('R%d', sat), 'HorizontalAlignment','center', ...
                'VerticalAlignment','middle','FontSize',7,'FontName','Times New Roman','Color','w');
        end
    end
    if ~isempty(arcs), tMax = max(tMax, max(arcs(:,2))); end
end
unexec = find(o.f == 0);
set(ax, 'YTick', 1:C.Nequ, 'YTickLabel', arrayfun(@(e) sprintf('EQ%d', e), 1:C.Nequ, 'UniformOutput', false));
ylim(ax, [0.2, C.Nequ + 2.6]);   % top band for the info box
grid(ax, 'on');
xlabel(ax, 'mission time (s)');
xlim(ax, [0, 1.05 * max(tMax, 1)]);
colormap(ax, cmap);
caxis(ax, [pLo, pHi]);
cb = colorbar(ax, 'southoutside');
cb.Label.String = 'request priority';
cb.Label.FontName = 'Times New Roman';
cb.Label.FontSize = 8;
cb.FontName = 'Times New Roman'; cb.FontSize = 8;
if pHi > pLo, cb.Ticks = pLo:pHi; end
note = {sprintf('makespan = %.4g s', max([o.task_info(:,5); 0]))};
if isempty(unexec)
    note{end+1} = 'unexecuted: none';
else
    parts = arrayfun(@(i) sprintf('R%d(p=%d)', i, C.Preq(i)), unexec, 'UniformOutput', false);
    cur = sprintf('unexecuted (%d): ', numel(unexec));
    for z = 1:numel(parts)
        add = parts{z};
        if z < numel(parts), add = [add, ',']; end
        if strlength(cur) + strlength(add) > 95
            note{end+1} = cur; %#ok<AGROW>
            cur = '    ';
        end
        cur = [cur, add, ' ']; %#ok<AGROW>
    end
    note{end+1} = strtrim(cur);
end
opts.note = note;
if ~isfield(opts,'objRaw') || isempty(opts.objRaw), opts.objRaw = PRO.CalObjRaw(dec); end
if ~isfield(opts,'executedRequests') || isempty(opts.executedRequests)
    opts.executedRequests = sum(o.f);
end
if ~isfield(opts,'feasible'), opts.feasible = true; end
rwmmo_render_header(ax, PRO, opts);
end
