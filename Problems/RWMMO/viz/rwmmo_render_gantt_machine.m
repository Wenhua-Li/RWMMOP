function rwmmo_render_gantt_machine(PRO, dec, ax, opts)
%RWMMO_RENDER_GANTT_MACHINE Identical parallel machine schedule (P||Cmax).
%   One row per machine, one bar per job coloured by job index (Okabe-Ito
%   cycle, legend below). Jobs run in job-index order within each machine
%   (the objectives depend only on loads, so any consistent order is
%   faithful); eligibility violations draw a vermillion frame. Metrics go
%   to the shared info box in a reserved top band.
if nargin < 4, opts = struct(); end
PM = PRO.PM;
a = PRO.CalDec(dec);
mach = a(:)';
R = PRO.CalObjRaw(a);      % [makespan, total cost] in engineering units
C = PRO.CalCon(a);
pal = rwmmo_palette;
jobCol = [pal.blue; pal.orange; pal.bluishgreen; pal.vermillion; ...
          pal.skyblue; pal.reddishpurple; pal.yellow; pal.darkgrey];
if PM.nJobs > size(jobCol,1)
    % more jobs than palette colours: keep the eight base colours and extend
    % with lighter variants of the first four plus black, so every job owns a
    % distinguishable colour (MATLAB's lines() only cycles seven colours)
    jobCol = [jobCol; 0.35 + 0.65*jobCol(1:4,:); 0 0 0];
    jobCol = jobCol(1:PM.nJobs, :);
end
set(ax, 'FontName','Times New Roman','FontSize',9,'NextPlot','add','Box','on');
hold(ax, 'on');
hJobArr = gobjects(1, PM.nJobs);
hViol = gobjects(0,1);
for m = 1:PM.nMach
    jobs = find(mach == m);
    t = 0;
    for z = 1:numel(jobs)
        j = jobs(z);
        viol = ~PM.eligible(j, m);
        edge = 'k'; lw = 0.5;
        if viol, edge = pal.vermillion; lw = 1.4; end
        h = patch(ax, [t, t+PM.p(j,m), t+PM.p(j,m), t], [m-0.36, m-0.36, m+0.36, m+0.36], ...
            jobCol(1 + mod(j-1, size(jobCol,1)), :), 'EdgeColor', edge, 'LineWidth', lw);
        if ~isgraphics(hJobArr(j)), hJobArr(j) = h; end
        if viol && isempty(hViol)
            hViol = plot(ax, nan, nan, 's', 'MarkerSize', 8, 'MarkerFaceColor', 'none', ...
                'MarkerEdgeColor', pal.vermillion, 'LineWidth', 1.4);
        end
        if PM.p(j,m) > 0.25*max(PM.p(:))
            text(ax, t+PM.p(j,m)/2, m, sprintf('%d', j), 'HorizontalAlignment','center', ...
                'FontSize', 8, 'FontName','Times New Roman', 'Color', 'w');
        end
        t = t + PM.p(j,m);
    end
end
set(ax, 'YTick', 1:PM.nMach, 'YTickLabel', arrayfun(@(m) sprintf('machine %d', m), 1:PM.nMach, 'UniformOutput', false));
ylim(ax, [0.2, PM.nMach + 2.2]);   % top band for the info box
grid(ax, 'on');
xlabel(ax, 'processing time');
have = isgraphics(hJobArr);
hh = [hJobArr(have), hViol];
lb = [arrayfun(@(j) sprintf('job %d', j), find(have), 'UniformOutput', false), {'eligibility violation'}];
keep = isgraphics(hh);
legend(ax, hh(keep), lb(keep), 'Location','southoutside','Orientation','horizontal', ...
    'NumColumns',7, 'FontSize',8,'FontName','Times New Roman','Box','off');
opts.note = sprintf('makespan = %.4g, total cost = %.4g, constraint violation = %.4g', ...
    R(1), R(2), sum(max(C(:), 0)));
if ~isfield(opts,'objRaw') || isempty(opts.objRaw), opts.objRaw = R; end
if ~isfield(opts,'feasible'), opts.feasible = all(C <= 0, 2); opts.conValue = C; end
rwmmo_render_header(ax, PRO, opts);
end
