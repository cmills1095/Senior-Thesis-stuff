clear
close all
rng(1) %seed to get same outcomes every time
%{
Inverse modeling 1D DC resistivity measurements. Based on tdmcmc_teaching
example. This script is for doing an inverion to get an ensemble solution,
use ensembleAnalysis to analyze an already existing ensemble.
Requires other scripts: createSyntheticData, mcmcAlgorithm,
ensembleAnalysis, calculateRho1D.
Chris Mills 10/2020
%}

forwardModel = @(a,b,c) calculateRho1D(a,b,c);

%% Step 1: Load data or create model/generate synthetic measurements
ifLoadData = false;%input('Load data? true/false\n');

if ifLoadData
    % ...Not setup yet to take real data...
else
    %Artifical model setup:
    measure.modelChoice = '3LayerA'; %currently setup: 3LayerA, 4LayerA
    %Measurement options
    measure.minDist = 0.1; % Smallest electrode distance, meters
    measure.maxDist = 1000; %  Largest electrode distance, meters
    measure.numMeasurements = 21; %total # of measurements
    measure.noiseCoef = 0.11; %How "noisy" are the measurements
end

%% Set inversion options
options.kMax = 10; %max number of layers allowed in models
options.numSteps = 1e6; %total iterations for MCMC loop. 1e7+ recommended
options.mLPSCoefficient = 1e4;
options.modelChoice = measure.modelChoice;
%mLPS = max layers per step. Set higher for longer 'burn-in' period.
options.saveStart = floor(options.numSteps/2);
%saveStart is the # of steps before end to start sampling. Should not
%sample until max # of layers has been reached AND it has had time to test
%several models with max # of layers.
options.saveSkip = 100; %sample every (saveSkip)th step once sampling begins
options.intlVar = 1.0; %variance = how much misfit accepted.
options.alterVar = true; %If false, model variance will never change

%If numSteps is not sufficiently high, reset above quantities appropriately
if options.mLPSCoefficient*sum(2:options.kMax) > options.numSteps
    options.mLPSCoefficient = floor(options.numSteps/sum(2:options.kMax));
    disp(['Not enough steps, changing burn-in time']);
end
if options.numSteps - options.saveStart < options.mLPSCoefficient*...
        (sum(2:options.kMax-1)+(0.5*options.kMax))
    options.saveStart = options.numSteps - (options.mLPSCoefficient*...
        ceil(sum(2:options.kMax-1)+(0.5*options.kMax)));
    disp(['Changing saveStart time']);
end

measure.kMax = options.kMax;

% Create bounds on parameter values. These bounds are based on Appendix A
% in Malinverno 2002. See also the "genericMedium" constructor function
%Bound parameters. Bounds based on Appendix A, Malinverno 2002
pBounds.maxLayers = options.kMax; % max # of layers in a given model
pBounds.depthMin = 1e-1; %min depth for layer interface (not top)
pBounds.depthMax = measure.maxDist; % max depth for layer interface
pBounds.rhoMin = 1e-8; % min resistivity, NEEDS UPDATE
pBounds.rhoMax = 1e8; % max resistivity, NEEDS UPDATE
pBounds.varMin = 1e-8; % valid?
pBounds.varMax = 1e8; % valid?
pBounds.varChange = 1e-1;  %valid?
pBounds.intlVar = options.intlVar; %initial variance
pBounds.numSteps = options.numSteps; %
%{
noiseCoefs=[0.0,0.01,0.02,0.05,0.1,0.2];
parfor inoise=1:(length(noiseCoefs)+1)
    thisMeasure = measure;    
    thisOptions = options;
    
    if inoise == (length(noiseCoefs)+1) % special case for sampling the prior.
        thisMeasure.noiseCoef=0.0;
        thisOptions.samplePrior = true;
        filename = ['Ensemble_', thisMeasure.modelChoice, '_',...
            'prior', '_', date, '.mat'];
    else
        thisMeasure.noiseCoef=noiseCoefs(inoise);
        thisOptions.samplePrior = false;
        filename = ['Ensemble_', thisMeasure.modelChoice, '_',...
            num2str(thisMeasure.noiseCoef), '_', date, '.mat'];
    end
    
    data = createSyntheticData(thisMeasure, forwardModel); %creates measurements
    results = mcmcAlgorithm(data,forwardModel,thisOptions, pBounds);
    
    doSaving(filename,results,data,thisMeasure,thisOptions,forwardModel,pBounds);
end
%}
options.samplePrior = false;
 data = createSyntheticData(measure,forwardModel);
 results = mcmcAlgorithm(data,forwardModel,options,pBounds);
 filename = ['Ensemble_', measure.modelChoice, '_',...
         num2str(measure.noiseCoef), '_', date, '.mat'];
 doSaving(filename, results,data, measure, options, forwardModel,pBounds);