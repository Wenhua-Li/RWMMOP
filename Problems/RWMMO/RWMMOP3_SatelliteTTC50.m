classdef RWMMOP3_SatelliteTTC50 < RWMMOP1_SatelliteTTC25
% <2026> <multi> <integer> <large> <multimodal> <constrained/none>
% The 50-requirement TT&C scheduling instance (case_50) of the same validated
% mechanism as RWMMOP1_SatelliteTTC25: 50 requirements, 10 ground equipments,
% 463 candidate laps, 176 scheduled tasks and therefore D = 352 integer
% variables (lap choice plus equipment choice per task), M = 2 (negative
% weighted executed priority plus profit, and the makespan of the equipment
% timelines). Everything except the frozen snapshot is inherited, so the two
% instances cannot drift apart: the repair, the feasible initialiser, the
% legacy-compatible decoder, the objective wrapper and the reference-set
% wiring (GetOptimum/GetPF/GetPS/CalMetric) are one implementation.
%
%   Decision    : per task, the chosen lap of its requirement and the chosen
%                 equipment, repaired to a canonical chronological form with
%                 duplicate laps reassigned to the first free lap.
%   Objectives  : [1] -(priority-weighted executed requirements + equipment
%                 profit), [2] makespan of the equipment timelines; CalObj is
%                 the frozen affine image of CalObjRaw.
%   Constraints : the legacy decoder marks a requirement unexecuted when its
%                 lift/descend lap counts are not met or when its equipment
%                 timelines overlap; unexecuted requirements reduce objective 1
%                 rather than violating an explicit constraint, exactly as in
%                 RWMMOP1, so formal results must also report executedRequests.
%   Reference   : high-budget-approx, built by tests/generate_satellite50_reference.m
%                 from fixed-seed sampling and frozen by rwmmo_freeze_objective_scaling
%                 (48 rows, caveat retained: no convergence criterion yet).
%   Multimodality: EM - 3 exact tie groups via the inherited neutral-dimension
%                 mechanism, certificate frozen in modality_certificates.json.
%   Licence     : verified 2026-09-17 - the instance lives in the workspace
%                 owner's research archive, who confirmed the right to publish
%                 and redistribute it with the benchmark (license_audit.json).
    methods(Access = protected)
        function s = dataFile(~)
            s = 'SatelliteTTC50_full.mat';
        end
        function s = classFile(~)
            s = 'RWMMOP3_SatelliteTTC50';
        end
    end
end