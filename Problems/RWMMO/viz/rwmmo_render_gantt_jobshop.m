function rwmmo_render_gantt_jobshop(PRO, dec, ax, opts)
%RWMMO_RENDER_GANTT_JOBSHOP Energy-aware flexible job-shop gantt chart.
%   One row per machine, one bar per operation coloured by its job
%   (Okabe-Ito cycle, legend below). The timeline is decoded by
%   PRO.schedule - the exact structure RWMMOP2_Jobshop5.evaluateOne
%   consumes - so the drawn schedule is the evaluated schedule by
%   construction. Metrics go to the shared info box in a reserved top
%   band.
if nargin < 4, opts = struct(); end
X = PRO.CalDec(dec);
nOp = PRO.D / 2;
S = PRO.schedule(X(1:nOp), X(nOp+1:end));
J = PRO.J;
pal = rwmmo_palette;
jobCol = [pal.blue; pal.orange; pal.bluishgreen; pal.vermillion; ...
          pal.skyblue; pal.reddishpurple; pal.yellow; pal.darkgrey];
set(ax, 'FontName','Times New Roman','FontSize',9,'NextPlot','add','Box','on');
hold(ax, 'on');
hJobArr = gobjects(1, J.I);
for j = 1:J.I
    for op = 1:PRO.OpCount(j)
        m = S.machineCode(j, op);
        if m == 0, continue; end
        h = patch(ax, [S.tStart(j,op), S.tEnd(j,op), S.tEnd(j,op), S.tStart(j,op)], ...
            [m-0.36, m-0.36, m+0.36, m+0.36], jobCol(1 + mod(j-1, size(jobCol,1)), :), ...
            'EdgeColor', 'k', 'LineWidth', 0.5);
        if ~isgraphics(hJobArr(j)), hJobArr(j) = h; end
        if S.tEnd(j,op) - S.tStart(j,op) > 0.03 * max([S.tEnd(:); 1])
            text(ax, (S.tStart(j,op)+S.tEnd(j,op))/2, m, sprintf('J%d.%d', j, op), ...
                'HorizontalAlignment','center','FontSize',7,'FontName','Times New Roman','Color','w');
        end
    end
end
set(ax, 'YTick', 1:J.M, 'YTickLabel', arrayfun(@(m) sprintf('M%d', m), 1:J.M, 'UniformOutput', false));
ylim(ax, [0.2, J.M + 2.2]);   % top band for the info box
grid(ax, 'on');
xlabel(ax, 'time');
have = isgraphics(hJobArr);
legend(ax, hJobArr(have), arrayfun(@(j) sprintf('job %d', j), find(have), 'UniformOutput', false), ...
    'Location','southoutside','Orientation','horizontal', ...
    'FontSize',8,'FontName','Times New Roman','Box','off');
opts.note = sprintf('makespan = %.4g, power intensity = %.4g, unused machines = %d', ...
    S.makespan, S.totalPower / max(S.makespan, eps), S.unusedMachines);
if ~isfield(opts,'objRaw') || isempty(opts.objRaw), opts.objRaw = PRO.CalObjRaw(X); end
if ~isfield(opts,'feasible'), opts.feasible = true; end
rwmmo_render_header(ax, PRO, opts);
end
