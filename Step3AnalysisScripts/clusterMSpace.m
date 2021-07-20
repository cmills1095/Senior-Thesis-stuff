
function outputPartition = clusterMSpace(lRPlot,maxNum,distMetric)

idxs = zeros(size(lRPlot,2),maxNum);
cents = zeros(sum(1:maxNum),size(lRPlot,1));
sumds = zeros(sum(1:maxNum),1);

stream = RandStream('mlfg6331_64');  % Random number stream
options = statset('UseParallel',1,'UseSubstreams',1,'Streams',stream);
j = 1;
for i = 1:maxNum
    fprintf('Calculating for %d clusters\n',i)
    index = j:(j+i-1);
    [idxs(:,i),cents(index,:),sumds(index)] = kmeans(lRPlot',i,...
        'Options',options,'Replicates',5,'MaxIter',1000,'Distance',distMetric);
    j = j+i;
end

eva = evalclusters(lRPlot',idxs,'CalinskiHarabasz');
numClusters = eva.OptimalK;

index = 1+sum(1:numClusters-1);
outputPartition.numClusters = numClusters;
outputPartition.indices = idxs(:,numClusters);
outputPartition.centroids = cents(index:index+numClusters-1,:);
outputPartition.sumd = sumds(index:index+numClusters-1);
end