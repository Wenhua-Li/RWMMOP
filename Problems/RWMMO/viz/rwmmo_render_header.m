function rwmmo_render_header(ax, PRO, opts)
%RWMMO_RENDER_HEADER Uniform title + boxed info block on every domain figure.
%   Title: at most two lines (id + class, then solution provenance). All
%   numbers live in a single boxed text block placed in a corner the
%   renderer has reserved space for (opts.infoLoc, default 'northeast';
%   also 'northwest' | 'southeast' | 'southwest'), so annotation text can
%   never float loose over the drawing. opts.note (char or cellstr) adds
%   domain-specific lines to the same box. Figure text is English Times
%   New Roman, >= 8 pt, per the paper figure policy.
if nargin < 3, opts = struct(); end
% --- title, max two lines ---
lines = {sprintf('%s  %s', headerField(opts,'id','RWMMO'), headerField(opts,'cls',class(PRO)))};
if isfield(opts,'solutionIndex') && ~isempty(opts.solutionIndex)
    src = headerField(opts,'source','');
    if isempty(src)
        lines{end+1} = sprintf('solution #%d', opts.solutionIndex);
    else
        lines{end+1} = sprintf('solution #%d  (%s)', opts.solutionIndex, src);
    end
elseif isfield(opts,'source') && ~isempty(opts.source)
    lines{end+1} = sprintf('(%s)', opts.source);
end
set(ax,'FontName','Times New Roman','FontSize',9);
title(ax, lines, 'FontName','Times New Roman','FontSize',10,'Interpreter','none');
% --- boxed info block ---
info = {};
if isfield(opts,'objRaw') && ~isempty(opts.objRaw)
    info{end+1} = sprintf('f (raw) = [%s]', numlist(opts.objRaw));
end
if isfield(opts,'objNorm') && ~isempty(opts.objNorm)
    info{end+1} = sprintf('f (norm) = [%s]', numlist(opts.objNorm));
end
if isfield(opts,'executedRequests') && ~isempty(opts.executedRequests)
    info{end+1} = sprintf('executed requests = %d', opts.executedRequests);
elseif isfield(opts,'feasible') && ~isempty(opts.feasible)
    if opts.feasible
        info{end+1} = 'feasible';
    else
        cv = [];
        if isfield(opts,'conValue'), cv = opts.conValue; end
        info{end+1} = sprintf('INFEASIBLE, constraint value = [%s]', numlist(cv));
    end
end
if isfield(opts,'note') && ~isempty(opts.note)
    if iscellstr(opts.note) || (iscell(opts.note) && ~isempty(opts.note))
        info = [info, opts.note(:)']; %#ok<AGROW>
    else
        info{end+1} = char(opts.note);
    end
end
if isempty(info), return; end
switch headerField(opts,'infoLoc','northeast')
    case 'northwest', x = 0.005; y = 0.99; hA = 'left';  vA = 'top';
    case 'southeast', x = 0.995; y = 0.01; hA = 'right'; vA = 'bottom';
    case 'southwest', x = 0.005; y = 0.01; hA = 'left';  vA = 'bottom';
    otherwise,        x = 0.995; y = 0.99; hA = 'right'; vA = 'top';
end
text(ax, x, y, info, 'Units','normalized','HorizontalAlignment',hA, ...
    'VerticalAlignment',vA,'FontName','Times New Roman','FontSize',8, ...
    'Interpreter','none','BackgroundColor',[1 1 1], ...
    'EdgeColor',[0.55 0.55 0.55],'Margin',4);
end

function s = headerField(opts, name, default)
if isfield(opts,name) && ~isempty(opts.(name)), s = char(opts.(name)); else, s = default; end
end

function s = numlist(v)
v = v(:)';
v(v == 0) = 0;          % turn -0 into +0 so '%.4g' never prints '-0'
s = strtrim(sprintf('%.4g ', v));
end
