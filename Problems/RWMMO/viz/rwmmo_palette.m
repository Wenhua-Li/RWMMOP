function c = rwmmo_palette(name)
%RWMMO_PALETTE Okabe-Ito colour-blind-safe palette for RWMMO figures.
%   c = rwmmo_palette() returns a struct with all named colours;
%   c = rwmmo_palette(name) returns one RGB triple. Names: orange,
%   skyblue, bluishgreen, yellow, blue, vermillion, reddishpurple, black,
%   grey, darkgrey. Every domain renderer in this directory takes its
%   colours from here so the gallery and the interactive DrawSolution
%   view share one colour language (paper figure policy).
pal.orange        = [0.902 0.624 0.000];  % E69F00
pal.skyblue       = [0.337 0.706 0.914];  % 56B4E9
pal.bluishgreen   = [0.000 0.620 0.451];  % 009E73
pal.yellow        = [0.941 0.894 0.259];  % F0E442
pal.blue          = [0.000 0.447 0.698];  % 0072B2
pal.vermillion    = [0.835 0.369 0.000];  % D55E00
pal.reddishpurple = [0.800 0.475 0.655];  % CC79A7
pal.black         = [0.000 0.000 0.000];
pal.grey          = [0.700 0.700 0.700];
pal.darkgrey      = [0.350 0.350 0.350];
if nargin < 1
    c = pal;
    return;
end
assert(isfield(pal, name), 'RWMMO:Palette', 'Unknown palette colour "%s".', name);
c = pal.(name);
end
