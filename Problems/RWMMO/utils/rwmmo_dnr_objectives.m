function R = rwmmo_dnr_objectives(X, F, repaired)
%RWMMO_DNR_OBJECTIVES Objectives and constraints for feeder switch states.
%   R = rwmmo_dnr_objectives(X,F) evaluates each row of X. Decisions are
%   binarised and repaired to a radial topology first, so every evaluation
%   is a physically solvable configuration. Set repaired=true when X is
%   already a canonical spanning-tree incidence vector.
%
%   Objectives (all minimised):
%     f1 = total active power loss [kW]
%     f2 = voltage deviation index, sum_i (1 - |V_i|)^2 [pu^2]
%     f3 = switching operations relative to the initial radial configuration
%   Constraints (positive value means violated):
%     c1 = sum of bus voltage limit violations, limits [0.93, 1.05] pu
%     Topologies whose power flow diverges (voltage collapse) are flagged in
%     R.collapsed and receive F.lossPenalty / F.vdiPenalty with a positive
%     constraint violation, so they can never enter the Pareto set.
%     c2 = sum of branch thermal overload violations (only when the feeder
%          snapshot carries published line MVA limits)
if nargin < 3, repaired = false; end
if repaired
    closed = logical(X ~= 0);
else
    closed = rwmmo_dnr_repair(X, F.branchFrom, F.branchTo, F.nbus);
end
S = rwmmo_dnr_powerflow(F, closed);
nT = size(closed, 1);
collapsed = ~S.converged;
S.lossKW(collapsed) = F.lossPenalty;
S.VDI(collapsed) = F.vdiPenalty;
S.Vmin(collapsed) = NaN;
NSO = sum(closed ~= repmat(F.initialClosed', nT, 1), 2);
violV = sum(max(0, F.VminLim - S.Vmag) + max(0, S.Vmag - F.VmaxLim), 2);
violV(collapsed) = F.collapseViolation;
if ~isfield(F,'enforceThermal') || ~F.enforceThermal || all(isnan(F.branchLimit))
    violT = zeros(nT, 1);
else
    over = max(0, S.branchMVA - repmat(F.branchLimit', nT, 1));
    violT = sum(over, 2);
    violT(collapsed) = F.collapseViolation;
end
R.closed = closed;
R.lossKW = S.lossKW;
R.VDI = S.VDI;
R.Vmin = S.Vmin;
R.NSO = NSO;
R.Vmag = S.Vmag;
R.branchMVA = S.branchMVA;
R.collapsed = collapsed;
R.objs = [S.lossKW, S.VDI, NSO];
R.cons = [violV, violT];
end
