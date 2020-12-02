classdef genericMedium < handle
        
    properties (Access = private)
        %%%%%%%% Solution physical properties %%%%%%%%%%%%%%%%%%%%%%%%
        depths;     % current accepted solution log-depths, maxLayersx1
        rhos;       % current accepted solution log-resistivities,maxLayersx1
        numLayers;  % number of layers in proposed solution
        %%%%%%%%%%%%%%%%%% Solution math properties %%%%%%%%%%%%%%%%%%%%
        var;        % variance \sigma^2
        residual;   % residual (vector)
        misfit;     % norm of residual
        mahalDist;  % Mahalanobis distance \Phi(G)
        likeProb;   %likelihood
        Cdi;        % inverse of data+forward modeling covariance matrix.
        %%%%%%%%%% The following are bounds on values %%%%%%%%%%
        depthMin;   % Minimum log-depth for a layer interface (besides top)
        depthMax;   % Maximum log-depth for a layer interface
        rhoMin;     % Minimum log-resistivity
        rhoMax;     % Maximum log-resistivity
        hMin;       % Minimum log-thickness
        varMin;     % in LOG
        varMax;     % in LOG
        numMeasurements;
        %%%%%%%%%%%% How much to change values by %%%%%%%%%%%%%%
        depthChange;% standard deviation for depth changes
        rhoChange;  % standard deviation for rho changes
        varChange;  % log, standard deviation for var changes (not really setup yet)
        badRunsThreshold; % how many bad runs you can have before it errors
    end
        
    %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
    
    methods

%%%%%%%%%% Core Functions %%%%%%%%%%

        %Constructor - initializes with a 1-layer model
        function obj = genericMedium(pBounds,numMeasurements)
            obj.numMeasurements = numMeasurements;
            obj.depths = [log10(0); nan*zeros(pBounds.maxLayers-1,1)];
            obj.numLayers = nnz(~isnan(obj.depths));
            obj.setVar(pBounds.intlVar);
            obj.depthMin = log10(pBounds.depthMin);
            obj.depthMax = log10(pBounds.depthMax);
            obj.rhoMin = log10(pBounds.rhoMin);
            obj.rhoMax = log10(pBounds.rhoMax);
            obj.rhos = [obj.rhoMin+(0.5*(obj.rhoMax - obj.rhoMin));...
                nan*zeros(pBounds.maxLayers-1,1)];
            obj.varMin = log10(pBounds.varMin);
            obj.varMax = log10(pBounds.varMax);
            obj.hMin = (obj.depthMax - obj.depthMin)/(2*pBounds.maxLayers);
            obj.depthChange = obj.hMin;    % Update?
            obj.rhoChange = obj.rhoMax/2;  % Update?
            obj.varChange = log10(pBounds.varChange);
            obj.mahalDist = 0;
            obj.likeProb = 0;
            obj.misfit = 0;
            obj.badRunsThreshold = ceil(log10(pBounds.numSteps)*20);
        end
        
        %This is meant to send the solution to another genericMedium object
        function output = sendSln(obj)
            output.depths = obj.depths;
            output.rhos = obj.rhos;
            output.var = obj.var;
            output.misfit = obj.misfit;
            output.Cdi = obj.Cdi;
            output.residual = obj.residual;
        end
        
        %This is meant to recieve properties from another genericMedium
        %object
        function recieveSln(obj, input)
            obj.depths = input.depths;
            obj.rhos = input.rhos;
            obj.numLayers = nnz(~isnan(obj.depths));
            obj.Cdi = input.Cdi;
            obj.residual = input.residual;
            obj.setVar(input.var);
            obj.misfit = input.misfit;
            obj.calculatePosterior();
            if nnz(~isnan(obj.depths)) ~= nnz(~isnan(obj.rhos))
                fprintf('Error: accepted solution # of layers dont match');
            end
        end
        
%%%%%%%%%%%%%% Checks %%%%%%%%%%%%%%%%%%%%        
        
        %
        function sortLayers(obj)
            %sorts layers of proposed solution. Should be called before
            %accepting solution or checking properties
            [~,idx]=sort(obj.depths);
            obj.rhos = obj.rhos(idx);
            obj.depths = obj.depths(idx);
        end
        
        %
        function good = checkDepthProperties(obj,proposedDepth,indx)
            %checks new depth values to make sure in bounds
            testDepths = obj.depths(~isnan(obj.depths));
            if indx <= length(testDepths) %if perturbDepth, 
                testDepths(indx) = []; %remove old layer depth before comparison
            end
            if (proposedDepth > obj.depthMax-obj.hMin || proposedDepth < obj.depthMin) || ...
                    (min(abs(proposedDepth - testDepths)) < obj.hMin)
                good = false;
            else
                good = true;
            end
        end
        
        %
        function good = checkRhoProperties(obj,proposedRho)
            %checks to make sure rho values are in bounds
            if (proposedRho < obj.rhoMin || proposedRho>obj.rhoMax)
                good = false;
            else
                good = true;
            end
        end
        
        %
        function good = checkVarProperties(obj,input)
            %checks var values to be in bounds
            %assumes input in logspace
            if (input > obj.varMax || input < obj.varMin)
                good = false;
            else
                good = true;
            end
        end
        
%%%%%%%%%% RANDOM WALK OPTIONS %%%%%%%%%%%%%%%
        
        %
        function perturbDepth(obj)
            %Alters proposed solution by changing a layer depth
            %Assumes more than a one-layer model (don't use otherwise)
            success = false;
            nbad = 0;
            while ~success
                nbad=nbad+1;
                if(nbad>obj.badRunsThreshold)
                    error('nbad exceeded max,perturbDepth');
                end
                indx = randi([2,obj.numLayers]); %Don't touch first layer
                dummy = obj.depths(indx) + obj.depthChange*randn;
                success = obj.checkDepthProperties(dummy,indx);
            end
            obj.depths(indx) = dummy;
            if ~issorted(obj.depths)
                obj.sortLayers();
            end
        end
        
        %
        function deleteLayer(obj)
            indx = randi([2,obj.numLayers]);
            obj.depths(indx:end) = [obj.depths(indx+1:end); NaN];%shift cells up
            obj.rhos(indx:end) = [obj.rhos(indx+1:end); NaN];
            obj.numLayers = nnz(~isnan(obj.depths));
        end
            
        %
        function addLayer(obj)
            success = false;
            nbad = 0;
            indx = obj.numLayers+1; %Index of the new layer
            while ~success
                nbad=nbad+1;
                if(nbad>obj.badRunsThreshold)
                    error('nbad exceeded max,addLayer');
                end
                dummyDepth = obj.depthMin + rand*(obj.depthMax - obj.depthMin);
                dummyRho = obj.rhoMin + rand*(obj.rhoMax - obj.rhoMin);
                if obj.checkDepthProperties(dummyDepth,indx) &&...
                        obj.checkRhoProperties(dummyRho)
                    success = true;
                end
            end
            obj.depths(indx) = dummyDepth;
            obj.rhos(indx) = dummyRho;
            obj.numLayers = nnz(~isnan(obj.depths));
            if ~issorted(obj.depths)
                obj.sortLayers();
            end
        end
        
        %
        function perturbRho(obj)
            success = false;
            nbad = 0;
            while ~success
                nbad=nbad+1;
                if(nbad>obj.badRunsThreshold)
                    error('nbad exceeded max ,perturbRho');
                end
                indx = randi([1,obj.numLayers]);
                dummy = obj.rhos(indx) + obj.rhoChange*randn;
                success = obj.checkRhoProperties(dummy);
            end
            obj.rhos(indx) = dummy;
        end
        
        %
        function perturbVar(obj)
            success = false;
            nbad = 0;
            while ~success
                nbad = nbad+1;
                if (nbad>obj.badRunsThreshold)
                    error('nbad exceeded max, perturbVar')
                end
                dvar = log10(obj.var);
                dummy = dvar+(obj.varChange*randn);
                success = obj.checkVarProperties(dummy);
            end
            obj.setVar(10^dummy);
        end
          
%%%%%%%%%% GET IT %%%%%%%%%%%%%%%%%%%%
        
        %
        function [depths,rhos] = getSolution(obj)
            depths = 10.^obj.depths;
            rhos = 10.^obj.rhos;
        end
        
        %
        function N = getNumLayers(obj)
            N = obj.numLayers;
        end
        
        %
        function output = getMahalDist(obj)
            output = obj.mahalDist;
        end
        
        %
        function output = getVar(obj)
            output = obj.var;
        end
        
        function output = getMisfit(obj)
            output = obj.misfit;
        end
        
        function output = getLikeProb(obj)
            output = obj.likeProb;
        end
    
        function output = getCdi(obj)
            output = obj.Cdi;
        end
%%%%%%%%%%% SET IT %%%%%%%%%%%%%%%% %for manually setting stuff
        function setCdi(obj,Cdi)
            obj.Cdi = Cdi;
        end
        
        function setVar(obj,input)
            obj.var = input;
        end
        
        function setMisfit(obj,residual)
            % input should be (vector) residual and Cdi.
            %             obj.misfit = norm(input);
            obj.residual = residual;
            obj.misfit = norm(residual);
            obj.calculatePosterior();
        end
        
        function calculatePosterior(obj)
            %input is misfit
            obj.mahalDist = obj.residual'*obj.Cdi*obj.residual/obj.var;
            obj.likeProb = exp(-0.5*obj.mahalDist)/...
                ((sqrt(2*pi*obj.var))^obj.numMeasurements);
        end
    end
end