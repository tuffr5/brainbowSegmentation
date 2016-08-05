function [square_sAff, svMeans, svCells, voxelCounts, origIndex] = newMergeWRTneighborsAndOrientations(square_sAff, svMeans, svCells, voxelCounts, origIndex, normFlag, stackSize, opts)

[orientations, conditionNumbers]                = calculateOrientations(svCells, stackSize, opts);
allTriplets                                     = nchoosek(1:size(svMeans, 2), 3);
allColors                                       = zeros(size(svMeans, 1), 3*size(allTriplets, 1));
if normFlag
  svMeansNorm                                   = svMeans ./ repmat(sqrt(sum(svMeans.^2, 2)), 1, size(svMeans, 2));
  for kk = 1:size(allTriplets, 1)
    allColors(:, 3*kk-2:3*kk)                   = rgb2luv(svMeansNorm(:, allTriplets(kk, :))')';
  end
  [coeff,score,latent]                          = pca(allColors);
  colorData                                     = score(:, 1:size(svMeans, 2));
else
  for kk = 1:size(allTriplets, 1)
    allColors(:, 3*kk-2:3*kk)                   = rgb2luv(svMeans(:, allTriplets(kk, :))')';
  end
  [coeff,score,latent]                          = pca(allColors);
  colorData                                     = score(:, 1:size(svMeans, 2));
end
cc                                              = numel(svCells);
binsaff_6n                                      = (square_sAff>1/(opts.sDist+eps));
smallerSVs                                      = find(voxelCounts<1000);
xx                                              = zeros(nnz(binsaff_6n)/2, 1);
yy                                              = xx;
vv                                              = xx;
idx                                             = 1;
vvo                                             = vv;
for kk = 1:cc
  tmp                                           = kk+find(binsaff_6n(kk,kk+1:end));
  xx(idx:idx+numel(tmp)-1)                      = kk;
  yy(idx:idx+numel(tmp)-1)                      = tmp;
  vv(idx:idx+numel(tmp)-1)                      = pdist2(colorData(kk,:), colorData(tmp,:));
  vvo(idx:idx+numel(tmp)-1)                     = abs(orientations(:,kk)'*orientations(:,tmp));
  idx                                           = idx+numel(tmp);
end
cAff                                            = sparse(xx, yy, vv, cc, cc);
cAff                                            = cAff + cAff';
oAff                                            = sparse(xx, yy, vvo, cc, cc);
oAff                                            = oAff + oAff';
xx                                              = zeros(nnz(binsaff_6n), 1);
yy                                              = xx;
idx                                             = 1;
for mm = 1:numel(smallerSVs)
  kk                                            = smallerSVs(mm);
  n6                                            = find(binsaff_6n(kk, :));
  [tt1, pos6]                                   = min(cAff(kk, n6)); % if tt==0; disp([kk n6]); end;
  bestNeighbor6                                 = n6(pos6);
  if oAff(kk, bestNeighbor6)>opts.minDotProduct & tt1<opts.maxColorDist & ((voxelCounts(kk)>20 & voxelCounts(bestNeighbor6)>20) | binsaff_6n(kk, bestNeighbor6)>1/2)
    xx(idx)                                     = kk;
    yy(idx)                                     = bestNeighbor6;
    idx                                         = idx + 1;
  end
end
xx(idx:end)                                     = [];
yy(idx:end)                                     = [];
[S,C]                                           = graphconncomp(sparse(xx, yy, 1, cc, cc), 'Weak', true);


newsvCells          = cell(1, S);
newsvMeans          = zeros(S, size(svMeans, 2));
voxelCounts         = voxelCounts(:)';
for kk = 1:S
  thisConnComp      = find(C==kk);
  newsvCells{kk}    = cell2mat(svCells(thisConnComp)');
  newsvMeans(kk, :) = voxelCounts(thisConnComp) * svMeans(thisConnComp, :) / sum(voxelCounts(thisConnComp));
end
svCells             = newsvCells;
svMeans             = newsvMeans;
voxelCounts         = cellfun(@numel, newsvCells);

[row, col, val]     = find(square_sAff);
row                 = C(row);
col                 = C(col);
upper               = find(row<=col);
row(upper)          = [];
col(upper)          = [];
val(upper)          = [];

ff                  = max(row)+1;
id                  = row + col*ff;
[uniqueid, ia, ~]   = unique(id);
newRows             = row(ia);
newCols             = col(ia);
newVals             = zeros(size(newRows));
parfor kk = 1:numel(uniqueid)
  newVals(kk)       = max(val(id==uniqueid(kk)));
end
square_sAff         = sparse(newRows, newCols, newVals, S, S);
square_sAff         = square_sAff + transpose(square_sAff);

origIndex           = C(origIndex);

