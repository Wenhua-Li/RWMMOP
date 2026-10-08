function Y = rwmmo_normalize_objectives(R, objLo, objHi)
%RWMMO_NORMALIZE_OBJECTIVES Affine map of raw objectives onto a comparable scale.
%   Engineering objectives routinely differ by orders of magnitude (satellite
%   benefit versus finish time in seconds, job-shop makespan versus average
%   power, feeder loss in kW versus a voltage index). Reference-vector based
%   algorithms degenerate on such data and HV/IGD end up dominated by the
%   widest axis. A positive affine map fixes this without changing the problem:
%   dominance, the Pareto set and every modality conclusion are preserved.
%   objLo/objHi are frozen problem constants, stored either in the data
%   snapshot or in the reference archive, and hashed by the data manifest.
assert(all(objHi > objLo), 'RWMMO:ObjectiveScale', 'Degenerate objective range.');
assert(size(R,2) == numel(objLo) && numel(objLo) == numel(objHi), ...
    'RWMMO:ObjectiveScale', 'Scale constants do not match the objective count.');
Y = (R - repmat(objLo(:)', size(R,1), 1)) ./ repmat(objHi(:)' - objLo(:)', size(R,1), 1);
end