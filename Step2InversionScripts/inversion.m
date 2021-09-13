function filenameOut = inversion(filename,varargin)
%{
6/21/21
Step 2 in the process, after createSyntheticData (or adequately formatted
data is acquired by other means). 'filename' will be the name of a file
(jut a string) containing data generated by createSyntheticData. This
program loads that file, sets a bunch of options and parameter bounds in
preparation for the data inversion, and then uses mcmcAlgorithm
(MCMC=Markov Chain Monte Carlo) to invert the data.
The input file linked by filename should contain
    data: a structure with fields:
        x: a vector of x-values, or electrode spacings
        lambda: a 'lambda matrix' generated from x, see 'makeLambda' script
        fx*: a vector of y-values (apparent resistivity measurements) at the
            corresponding x-values from above, with NO noise added
        y: vector of y-values WITH noise
        Cd: covariance matrix
        subStructChoice*: string indicating which subsurface structure was
            used to generate the data, see subStructGen script
        noiseCoef*: how noisy the data was
(*NOTE: fx,subStructChoice,and noiseCoef aren't used in this step, so they
are not necessary to run this script, but they will be used in step 3).
There is an optional input, priorOn, which controls whether or not the
prior distribution will be sampled during the inversion. Default is false,
in order to set it to true, call this function like
inversion(filename,'priorOn',true)
    forwardModel: a function handle for the forward model to be used
The output will be another filename containing everything that was imported
as well as the set options and parameter bounds, and a results structure
containing the results from the inversion.
%}

%% Part 0 preliminary 
defaultPriorOn =false;
p = inputParser;
addRequired(p,'filename',@ischar);
addParameter(p,'priorOn',defaultPriorOn,@islogical);
parse(p,filename,varargin{:});

addpath(genpath(fileparts(mfilename('fullpath'))))
load(filename)



%% Set options

options.numSteps = 2e8; %total iterations for loop.
options.mLPSCoefficient = 1e4; %max layers per step, controls 'burn-in' length
%max layers will be set to 2 for the first 2*mLPSCoef steps, 3 for the next 
%3*mLPSCoef steps, 4 for the next 4*mLPSCoef steps, etc.
options.saveStart = floor(options.numSteps/2);
%saveStart is the # of steps before end to start sampling. Should not
%sample until max # of layers has been reached AND it has had time to test
%several models with max # of layers.
options.saveSkip = 400; %sample every (saveSkip)th step once sampling begins
options.alterVar = true; %Whether or not the inversion is hierarchical.
%Set to true for hierarchical (variance is one of the parameters which can
%change) or false for not (variance will never change from intlVar.
options.samplePrior = p.Results.priorOn; %If true, will base acceptance probability on
%prior distribution (only set to true for testing purposes)
options.pctSteps = 5;
%once mcmc loop starts, a statement is printed regularly that tells you the
%algorithm is x% finished. If you set pctSteps = 1, you will be updated at
%1%,2%,3%... if pctSteps = 5, it will be 5%,10%,15%... if options.numSteps
%is huge, set pctSteps = 1 or 2 so you don't go long periods without
%knowing if the loop is progressing or not. If options.numSteps is small,
%set pctSteps = 10 or 20 since the loop will finish quickly and you might
%not want a flood of print statements. This is purely for convenience so
%there is no 'wrong' setting

%% Set parameter bounds
% Create bounds on parameter values. Some bounds are based on Appendix A
% in Malinverno 2002. See also the "genericMedium" constructor function
%Bound parameters. Bounds based on Appendix A, Malinverno 2002
pBounds.maxLayers = 10; % max # of layers in a given model
pBounds.depthMin = 1e-1; %min depth for layer interface, ie max thickness of top layer
pBounds.depthMax = max(data.x); % max depth for layer interface
pBounds.hMin = 10^((log10(pBounds.depthMax) - log10(pBounds.depthMin))/...
    (2*pBounds.maxLayers)); %min layer thickness. Malinverno 2002 Append A1
pBounds.depthChange = pBounds.hMin; %Std dev for depth changes btwn steps
pBounds.rhoMin = 1e-8; % min resistivity, ohm meters
pBounds.rhoMax = 1e8; % max resistivity, ohm meters
pBounds.rhoChange = 1.5; % Std dev for resistivity change btwn steps
pBounds.varMin = 1e-8; % min variance
pBounds.varMax = 1e8; % max variance
pBounds.varChange = 1e-1;  %amount variance can change by if alterVar=true
pBounds.intlVar = 1.0; %initial variance. 
%Controls how much misfit accepted.
pBounds.numSteps = options.numSteps; %used to set badRunsThreshold in genericSln

%% Perform inversion

%If numSteps is not sufficiently high, reset above quantities appropriately
if options.mLPSCoefficient*sum(2:pBounds.maxLayers) > options.numSteps
    options.mLPSCoefficient = floor(options.numSteps/sum(2:pBounds.maxLayers));
    disp(['Not enough steps, changing burn-in time']);
end
if options.numSteps - options.saveStart < options.mLPSCoefficient*...
        (sum(2:pBounds.maxLayers-1)+(0.5*pBounds.maxLayers))
    options.saveStart = options.numSteps - (options.mLPSCoefficient*...
        ceil(sum(2:pBounds.maxLayers-1)+(0.5*pBounds.maxLayers)));
    disp(['Changing saveStart time']);
end

results = mcmcAlgorithm(data,forwardModel,options,pBounds);

%% Save
if p.Results.priorOn
    filenameOut = ['Ensemble_', data.subStructChoice,'_',...
        num2str(data.noiseCoef),'_PRIOR_',date,'.mat'];
else    
    filenameOut = ['Ensemble_', data.subStructChoice, '_',...
        num2str(data.noiseCoef), '_', date, '.mat'];
end

save(filenameOut,'results','data','options','forwardModel',...
    'pBounds','-v7.3'); %-v7.3 allows for saving of large files

end
