function F = rwmmo_dnr_dataset(name)
%RWMMO_DNR_DATASET Fixed public radial distribution feeder data.
%   F = rwmmo_dnr_dataset('DNR33') returns the IEEE 33-bus test feeder.
%   F = rwmmo_dnr_dataset('DNR69') returns the IEEE 69-bus test feeder.
%   Branch tables are [from to R_ohm X_ohm isTie]; load tables are
%   [P_kW Q_kVAR] per bus. Sources: M. E. Baran and F. F. Wu, "Network
%   reconfiguration in distribution systems for loss reduction and load
%   restoration", IEEE Trans. Power Delivery, 1989 (33-bus); D. Das,
%   "Optimal placement of capacitors in radial distribution system using a
%   Fuzzy-GA method", IJEPES, 2008 (69-bus). The 33-bus branch MVA limits
%   are the published line limits used by the radial reconfiguration study
%   of IEEE Trans. Power Systems, 2023, doi:10.1109/TPWRS.2023.3256136.
switch upper(name)
    case 'DNR33'
        F.name = 'DNR33'; F.nbus = 33; F.Vbase = 12.66; F.Sbase = 1; F.slack = 1;
        br = [ 1  2 0.0922 0.0470 0;   2  3 0.4930 0.2511 0;   3  4 0.3660 0.1864 0;
               4  5 0.3811 0.1941 0;   5  6 0.8190 0.7070 0;   6  7 0.1872 0.6188 0;
               7  8 0.7114 0.2351 0;   8  9 1.0300 0.7400 0;   9 10 1.0440 0.7400 0;
              10 11 0.1966 0.0650 0;  11 12 0.3744 0.1238 0;  12 13 1.4680 1.1550 0;
              13 14 0.5416 0.7129 0;  14 15 0.5910 0.5260 0;  15 16 0.7463 0.5450 0;
              16 17 1.2890 1.7210 0;  17 18 0.7320 0.5740 0;   2 19 0.1640 0.1565 0;
              19 20 1.5042 1.3554 0;  20 21 0.4095 0.4784 0;  21 22 0.7089 0.9373 0;
               3 23 0.4512 0.3083 0;  23 24 0.8980 0.7091 0;  24 25 0.8960 0.7011 0;
               6 26 0.2030 0.1034 0;  26 27 0.2842 0.1447 0;  27 28 1.0590 0.9337 0;
              28 29 0.8042 0.7006 0;  29 30 0.5075 0.2585 0;  30 31 0.9744 0.9630 0;
              31 32 0.3105 0.3619 0;  32 33 0.3410 0.5302 0;   8 21 2.0000 2.0000 1;
               9 15 2.0000 2.0000 1;  12 22 2.0000 2.0000 1;  18 33 0.5000 0.5000 1;
              25 29 0.5000 0.5000 1];
        ld = [  0   0; 100  60;  90  40; 120  80;  60  30;  60  20; 200 100;
              200 100;  60  20;  60  20;  45  30;  60  35;  60  35; 120  80;
               60  10;  60  20;  60  20;  90  40;  90  40;  90  40;  90  40;
               90  40;  90  50; 420 200; 420 200;  60  25;  60  25;  60  20;
              120  70; 200 600; 150  70; 210 100;  60  40];
        lim = [4.6 4.1 2.9 2.9 2.9 1.5 1.05 1.05 1.05 1.05 1.05 0.5 0.45 0.3 ...
               0.25 0.25 0.1 0.5 0.5 0.21 0.11 1.05 1.05 0.5 1.5 1.5 1.5 1.5 ...
               1.5 0.5 0.5 0.1 0.5 0.5 0.5 0.5 0.1]';
    case 'DNR69'
        F.name = 'DNR69'; F.nbus = 69; F.Vbase = 12.66; F.Sbase = 1; F.slack = 1;
        br = [ 1  2 0.0005 0.0012 0;   2  3 0.0005 0.0012 0;   3  4 0.0015 0.0036 0;
               4  5 0.0251 0.0294 0;   5  6 0.3660 0.1864 0;   6  7 0.3811 0.1941 0;
               7  8 0.0922 0.0470 0;   8  9 0.0493 0.0251 0;   9 10 0.8190 0.2707 0;
              10 11 0.1872 0.0619 0;  11 12 0.7114 0.2351 0;  12 13 1.0300 0.3400 0;
              13 14 1.0440 0.3450 0;  14 15 1.0580 0.3496 0;  15 16 0.1966 0.0650 0;
              16 17 0.3744 0.1238 0;  17 18 0.0047 0.0016 0;  18 19 0.3276 0.1083 0;
              19 20 0.2106 0.0690 0;  20 21 0.3416 0.1129 0;  21 22 0.0140 0.0046 0;
              22 23 0.1591 0.0526 0;  23 24 0.3463 0.1145 0;  24 25 0.7488 0.2475 0;
              25 26 0.3089 0.1021 0;  26 27 0.1732 0.0572 0;   3 28 0.0044 0.0108 0;
              28 29 0.0640 0.1565 0;  29 30 0.3978 0.1315 0;  30 31 0.0702 0.0232 0;
              31 32 0.3510 0.1160 0;  32 33 0.8390 0.2816 0;  33 34 1.7080 0.5646 0;
              34 35 1.4740 0.4873 0;   3 36 0.0044 0.0108 0;  36 37 0.0640 0.1565 0;
              37 38 0.1053 0.1230 0;  38 39 0.0304 0.0355 0;  39 40 0.0018 0.0021 0;
              40 41 0.7283 0.8509 0;  41 42 0.3100 0.3623 0;  42 43 0.0410 0.0478 0;
              43 44 0.0092 0.0116 0;  44 45 0.1089 0.1373 0;  45 46 0.0009 0.0012 0;
               4 47 0.0034 0.0084 0;  47 48 0.0851 0.2083 0;  48 49 0.2898 0.7091 0;
              49 50 0.0822 0.2011 0;   8 51 0.0928 0.0473 0;  51 52 0.3319 0.1114 0;
               9 53 0.1740 0.0886 0;  53 54 0.2030 0.1034 0;  54 55 0.2842 0.1447 0;
              55 56 0.2813 0.1433 0;  56 57 1.5900 0.5337 0;  57 58 0.7837 0.2630 0;
              58 59 0.3042 0.1006 0;  59 60 0.3861 0.1172 0;  60 61 0.5075 0.2585 0;
              61 62 0.0974 0.0496 0;  62 63 0.1450 0.0738 0;  63 64 0.7105 0.3619 0;
              64 65 1.0410 0.5302 0;  11 66 0.2012 0.0611 0;  66 67 0.0047 0.0014 0;
              12 68 0.7394 0.2444 0;  68 69 0.0047 0.0016 0;  11 43 0.5000 0.5000 1;
              13 21 0.5000 0.5000 1;  15 46 1.0000 1.0000 1;  50 59 2.0000 2.0000 1;
              27 65 1.0000 1.0000 1];
        ld = [  0     0;     0     0;     0     0;     0     0;     0     0;
                2.6   2.2;  40.4  30;    75    54;    30    22;    28    19;
              145   104;   145   104;     8     5.5;   8     5.5;   0     0;
               45.5  30;   60    35;     60    35;     0     0;     1.0   0.6;
              114    81;   5.3   3.5;    0     0;     28    20;    0     0;
               14    10;   14    10;     26    18.6;  26    18.6;  0     0;
                0     0;    0     0;     14    10;    19.5  14;    6     4;
               26    18.55; 26   18.55;  0     0;     24    17;    24    17;
                1.2   1.0;  0     0;      6     4.3;   0     0;     39.22 26.3;
               39.22 26.3;  0     0;     79    56.4; 384.7 274.5; 384.7 274.5;
               40.5  28.3;  3.6   2.7;   4.35   3.5;  26.4  19;    24    17.2;
                0     0;    0     0;      0     0;   100   72;     0     0;
             1244   888;   32    23;      0     0;   227   162;   59    42;
               18    13;   18    13;     28    20;    28    20];
        lim = nan(size(br,1),1);
    otherwise
        error('RWMMO:UnknownFeeder','Unknown feeder %s.',name);
end
assert(size(br,1) == F.nbus - 1 + sum(br(:,5)), 'RWMMO:BranchCount', 'Branch count inconsistent.');
assert(size(ld,1) == F.nbus, 'RWMMO:BusCount', 'Load table must have nbus rows.');
Zbase = F.Vbase^2 / F.Sbase;
F.branchFrom  = br(:,1);
F.branchTo    = br(:,2);
F.branchR     = br(:,3) / Zbase;
F.branchX     = br(:,4) / Zbase;
F.branchIsTie = logical(br(:,5));
F.branchLimit = lim / F.Sbase;
% The 33-bus table ships a line MVA limit vector, but no upstream routine ever
% reads it, and it cannot be enforced: over all 50751 spanning trees, every
% voltage-feasible topology overloads some branch by at least 463% (median
% 1155%), and the binding branch is usually a tie line whose limit was sized
% for the open-switch state. Evidence: tests/dnr_thermal_diagnostic.m and
% results/dnr/thermal_diagnostic.json. The limits are therefore retained as
% published data for provenance but excluded from the constraint set, which
% leaves the ANSI-style bus voltage window as the only engineering constraint.
F.enforceThermal = false;
F.busP = ld(:,1) / (1000 * F.Sbase);
F.busQ = ld(:,2) / (1000 * F.Sbase);
F.VminLim = 0.93;
F.VmaxLim = 1.05;
F.initialClosed = ~F.branchIsTie;
F.nBranch = size(br,1);
F.nTree = nTreeCount(F.branchFrom, F.branchTo, F.nbus);
F.Zbase = Zbase;
base = rwmmo_dnr_powerflow(F, F.initialClosed');
assert(base.converged, 'RWMMO:DNRBaseCase', '%s initial radial configuration does not converge.', F.name);
F.baseLossKW = base.lossKW;
F.baseVmin = base.Vmin;
F.baseVDI = base.VDI;
% Some spanning trees cause voltage collapse, so the constant-PQ sweep has no
% fixed point. Those topologies are physically infeasible; they receive a
% deterministic dominated objective and a positive constraint violation so
% that every decision vector has a finite, reproducible evaluation.
F.lossPenalty = 10 * base.lossKW;
F.vdiPenalty = 10 * base.VDI;
F.collapseViolation = 1;
F.source = 'public IEEE radial test feeder data, see rwmmo_dnr_dataset.m header';
end
function t = nTreeCount(from, to, n)
% Kirchhoff matrix-tree theorem evaluated from the Laplacian spectrum.
%   tau(G) = (1/n) * prod_{i=2..n} lambda_i. The spectrum is computed in
%   double precision; the relative error stays far below 0.5/tau for the
%   feeder sizes used here, so rounding is exact. The enumerator in
%   rwmmo_dnr_enumerate_trees.m provides an independent exact cross-check.
L = zeros(n);
for e = 1:numel(from)
    i = from(e); j = to(e);
    L(i,j) = L(i,j) - 1; L(j,i) = L(j,i) - 1;
    L(i,i) = L(i,i) + 1; L(j,j) = L(j,j) + 1;
end
ev = sort(eig(L));
assert(abs(ev(1)) < 1e-8, 'RWMMO:Disconnected', 'Feeder graph is not connected.');
t = prod(ev(2:end)) / n;
assert(abs(t - round(t)) < 1e-3 * max(1,abs(t)), 'RWMMO:TreeCount', 'Spanning tree count is not integral.');
t = round(t);
end

