classdef AertsTexture
	%AERTSTEXTURE Summary of this class goes here
	% Decoding tumour phenotype by noninvasive imaging using a quantitative
	% radiomics approach. Aerts et al. Nature Communications 2014
	% DOI: 10.1038/ncomms5006

	properties(Constant)
		Autocorrelation = 'Aerts.Texture.Autocorrelation';
		ClusterProminence = 'Aerts.Texture.ClusterProminence';
		ClusterShade = 'Aerts.Texture.ClusterShade';
		ClusterTendency = 'Aerts.Texture.ClusterTendency';
		Contrast = 'Aerts.Texture.Contrast';
		Correlation = 'Aerts.Texture.Correlation';
		DifferenceEntropy = 'Aerts.Texture.DifferenceEntropy';
		Dissimilarity = 'Aerts.Texture.Dissimilarity';
		Energy = 'Aerts.Texture.Energy';
		Entropy = 'Aerts.Texture.Entropy';
		Homogeneity1 = 'Aerts.Texture.Homogeneity1';
		Homogeneity2 = 'Aerts.Texture.Homogeneity2';
		InformationalMeasureCorrelation1 = ...
			'Aerts.Texture.InformationalMeasureCorrelation1';
		InformationalMeasureCorrelation2 = ...
			'Aerts.Texture.InformationalMeasureCorrelation2';
		InverseDifferenceMomentNormalised = ...
			'Aerts.Texture.InverseDifferenceMomentNormalised';
		InverseDifferenceNormalised = 'Aerts.Texture.InverseDifferenceNormalised';
		InverseVariance = 'Aerts.Texture.InverseVariance';
		MaximumProbability = 'Aerts.Texture.MaximumProbability';
		SumAverage = 'Aerts.Texture.SumAverage';
		SumEntropy = 'Aerts.Texture.SumEntropy';
		SumVariance = 'Aerts.Texture.SumVariance';
		Variance = 'Aerts.Texture.Variance';
		ShortRunEmphasis = 'Aerts.Texture.ShortRunEmphasis';
		LongRunEmphasis = 'Aerts.Texture.LongRunEmphasis';
		GreyLevelNonUniformity = 'Aerts.Texture.GreyLevelNonUniformity';
		RunLengthNonUniformity = 'Aerts.Texture.RunLengthNonUniformity';
		RunPercentage = 'Aerts.Texture.RunPercentage';
		LowGreyLevelRunEmphasis = 'Aerts.Texture.LowGreyLevelRunEmphasis';
		HighGreyLevelRunEmphasis = 'Aerts.Texture.HighGreyLevelRunEmphasis';
		ShortRunLowGreyLevelEmphasis = ...
			'Aerts.Texture.ShortRunLowGreyLevelEmphasis';
		ShortRunHighGreyLevelEmphasis = ...
			'Aerts.Texture.ShortRunHighGreyLevelEmphasis';
		LongRunLowGreyLevelEmphasis = ...
			'Aerts.Texture.LongRunLowGreyLevelEmphasis';
		LongRunHighGreyLevelEmphasis = ...
			'Aerts.Texture.LongRunHighGreyLevelEmphasis';
	end

	%----------------------------------------------------------------------------
	methods(Static)
		%-------------------------------------------------------------------------
		function [collector,bins] = compute(inImage3D, mask3D, collector, dimFlag, bins)
			import radiomics.*;

			% default to 3D processing
			if nargin<4 || isempty(dimFlag)
				dimFlag = '3D';
			end

			% default number of discrete grey levels
			if nargin<5
				bins = 8;
			end

			sz = size(inImage3D);
			if length(sz)==2
				% pad in z-direction to make array 3D
				zzd = zeros(size(inImage3D));
				zzb = false(size(inImage3D));
				inImage3D = cat(3, zzd, inImage3D, zzd);
				mask3D = cat(3, zzb, mask3D, zzb);
				sz = size(inImage3D);
				dimFlag = '2D';
			end

			[image3D,bins] = AertsTexture.discretise(inImage3D, mask3D, bins);
			AertsTexture.glcmMetrics(image3D, mask3D, length(bins)-1, collector, dimFlag);
			% Max run length is largest array dimension
			nR = max(sz);
			AertsTexture.glrlmMetrics(image3D, mask3D, length(bins)-1, nR, collector, dimFlag);
		end

		%-------------------------------------------------------------------------
		function [result,bins] = discretise(image3D, mask3D, bins)
			result = zeros(size(image3D));
			% Note: discretize is a built-in function.
			% Result of this approach NOT identical to previous code as bin
			% edges will be different (even though bin number is the same).
			if isscalar(bins)
				[result(mask3D),bins] = discretize(image3D(mask3D), bins);
				% bins is now an array of bin edges
			else
				result(mask3D) = discretize(image3D(mask3D), bins);
			end
		end

		%-------------------------------------------------------------------------
		function [result,nDir] = glcm3D(image3D, mask3D, nBins, dimFlag, fNormalise)
			import radiomics.*;
			if nargin < 5
				fNormalise = true;
			end
			[directions,nDir] = AertsTexture.directions3D(dimFlag);
			result = zeros(nDir, nBins, nBins);
			% Linear subscripts of voxels in ROI
			idx = find(mask3D == 1);
			sz = size(image3D);
			maskedImage = image3D.*mask3D;
			% Precompute for speed
			maskedVoxels = maskedImage(idx);
			for k=1:nDir
				p = zeros(nBins, nBins);
				% Compute linear subscripts of the voxels in the current direction
				% from voxels in ROI
				currDir = squeeze(directions(k,:));
				[dirY,dirX,dirZ] = ind2sub(sz, idx);
				dirY = dirY+currDir(1);
				dirX = dirX+currDir(2);
				dirZ = dirZ+currDir(3);
				dirIdx = sub2ind(sz, dirY, dirX, dirZ);
				maskedVoxelsCurrDir = maskedImage(dirIdx);
				% GLCM for current direction
				% Equivalent to:
				% for i=1:nBins
				%    for j=1:nBins
				%       p(i,j) = ...
				%          nnz((maskedVoxels == i) & (maskedVoxelsCurrDir == j));
				%    end
				% end
				p = histcounts2(maskedVoxels, maskedVoxelsCurrDir, ...
					0.5:1:(nBins+0.5), 0.5:1:(nBins+0.5));
				% Normalise
				if fNormalise
					sumP = sum(p(:));
					if sumP > 0
						result(k,:,:) = p/sumP;
					end
				else
					result(k,:,:) = p;
				end
			end
		end

		%-------------------------------------------------------------------------
		function [result,nDir] = glrlm3D(image3D, mask3D, nG, nR, dimFlag)
			import radiomics.*;
			[directions,nDir] = AertsTexture.directions3D(dimFlag);
			result = zeros(nDir, nG, nR);
			maskedImage = image3D.*mask3D;
			% Find the pixels matching each grey level
			maskedIdx = find(maskedImage ~= 0);
			glIdx = cell(nG, 1);
			for i=1:nG
				glIdx{i} = maskedIdx(maskedImage(maskedIdx) == i);
			end
			for k=1:nDir
				p = zeros(nG, nR);
				currDir = squeeze(directions(k,:));
				for i=1:nG
					idx = glIdx{i};
					if isempty(idx)
						continue
					end
					runStartFlag = AertsTexture.isRunStart(maskedImage, idx, currDir);
					runLength = AertsTexture.findRunLengthArr(maskedImage, ...
						idx(runStartFlag), currDir, nR);
					[runLengthCounts,edges] = histcounts(runLength, 'BinMethod', ...
						'integers');
					jdx = round(edges(1:end-1)+0.5);
					p(i,jdx) = runLengthCounts;
					% Equivalent to:
					% for j=1:nPixels
					%    % Pixel must be a start of a run.
					%    if (~AertsTexture.isRunStart(maskedImage, idx(j), currDir))
					%       continue;
					%    end
					%    runLength = AertsTexture.findRunLength(maskedImage, idx(j), ...
					%       currDir, nR);
					%    p(i,runLength) = p(i,runLength)+1;
					% end
				end
				result(k,:,:) = p;
			end
		end

	end % methods(Static)

	%----------------------------------------------------------------------------
	methods(Static,Access=private)
		%-------------------------------------------------------------------------
		function result = autocorrelation(p)
			result = 0;
			sz = size(p);
			nG = sz(1);
			for i=1:nG
				for j=1:nG
					result = result+i*j*p(i,j);
				end
			end
		end

		%-------------------------------------------------------------------------
		function result = clusterProminence(p, muX, muY)
			result = 0;
			sz = size(p);
			nG = sz(1);
			for i=1:nG
				for j=1:nG
					result = result+(i+j-muX-muY).^4*p(i,j);
				end
			end
		end

		%-------------------------------------------------------------------------
		function result = clusterShade(p, muX, muY)
			result = 0;
			sz = size(p);
			nG = sz(1);
			for i=1:nG
				for j=1:nG
					result = result+(i+j-muX-muY).^3*p(i,j);
				end
			end
		end

		%-------------------------------------------------------------------------
		function result = clusterTendency(p, muX, muY)
			result = 0;
			sz = size(p);
			nG = sz(1);
			for i=1:nG
				for j=1:nG
					result = result+(i+j-muX-muY).^2*p(i,j);
				end
			end
		end

		%-------------------------------------------------------------------------
		function result = contrast(p)
			result = 0;
			sz = size(p);
			nG = sz(1);
			for i=1:nG
				for j=1:nG
					result = result+(abs(i-j)).^2*p(i,j);
				end
			end
		end

		%-------------------------------------------------------------------------
		function result = correlation(p, muX, muY, sigmaX, sigmaY)
			result = 0;
			sz = size(p);
			nG = sz(1);
			for i=1:nG
				for j=1:nG
					result = result+(i*j*p(i,j)+muX*muY);
				end
			end
			result = result/(sigmaX*sigmaY);
		end

		%-------------------------------------------------------------------------
		function [directions,nDir] = directions3D(dimFlag)
			% Compute the (dY,dX,dZ) vectors for each direction from chosen pixel
			% Directions that are opposite of another direction are omitted.
			switch dimFlag
				case '2D'
					nDir = 4;
					directions = zeros(nDir, 3);
					% First row of square around are +1y
					directions(1:3,1) = 1;
					% First column of square above are -1x
					directions(1,2) = -1;
					% Third column of square around are +1x
					directions(3:4,2) = 1;
				case '3D'
					nDir = 13;
					directions = zeros(nDir, 3);
					% Square above is -1z
					directions(1:9,3) = -1;
					% First row of square above are +1y
					directions(1:3,1) = 1;
					% Third row of square above are -1y
					directions(7:9,1) = -1;
					% First column of square above are -1x
					directions(1:3:9,2) = -1;
					% Third column of square above are +1x
					directions(3:3:9,2) = 1;
					% First row of square around are +1y
					directions(10:12,1) = 1;
					% First column of square above are -1x
					directions(10,2) = -1;
					% Third column of square around are +1x
					directions(12:13,2) = 1;
				otherwise
			end
		end

		%-------------------------------------------------------------------------
		function result = dissimilarity(p)
			result = 0;
			sz = size(p);
			nG = sz(1);
			for i=1:nG
				for j=1:nG
					result = result+abs(i-j)*p(i,j);
				end
			end
		end

		%-------------------------------------------------------------------------
		function result = energy(p)
			result = p.^2;
			result = sum(result(:));
		end

		%-------------------------------------------------------------------------
		function result = entropy(p)
			idx = p > 0;
			result = -sum(p(idx).*log2(p(idx)));
		end

		%-------------------------------------------------------------------------
		function runLength = findRunLength(image3D, idx, dir, nR)
			import radiomics.*;
			sz = size(image3D);
			[y,x,z] = ind2sub(sz, idx);
			runLength = 1;
			for i=1:nR-1
				dirY = y+i*dir(1);
				dirX = x+i*dir(2);
				dirZ = z+i*dir(3);
				fValid = AertsTexture.isValidIdx(dirY, dirX, dirZ, ...
					sz(1), sz(2), sz(3));
				if ~fValid || (image3D(dirY,dirX,dirZ) ~= image3D(idx))
					break
				end
				runLength = runLength+1;
			end
		end

		%-------------------------------------------------------------------------
		function runLength = findRunLengthArr(image3D, idx, dir, nR)
			import radiomics.*;
			sz = size(image3D);
			[y,x,z] = ind2sub(sz, idx);
			runLength = ones(size(idx));
			fActive = true(size(idx));
			for i=1:nR-1
				dirY = y(fActive)+i*dir(1);
				dirX = x(fActive)+i*dir(2);
				dirZ = z(fActive)+i*dir(3);
				fActive(fActive) = AertsTexture.isValidIdx(dirY, dirX, dirZ, ...
					sz(1), sz(2), sz(3)) & ...
					(image3D(sub2ind(sz,dirY,dirX,dirZ)) == image3D(idx(fActive)));
				if ~any(fActive)
					break
				end
				runLength(fActive) = runLength(fActive)+1;
			end
		end

		%-------------------------------------------------------------------------
		function collector = glcmMetrics(image3D, mask3D, nG, collector, dimFlag)
			import radiomics.*;
			[glcmAll,nDir] = AertsTexture.glcm3D(image3D, mask3D, nG, dimFlag);
			% Precompute reused quantities according to Aerts 2014
			mu = zeros(nDir, 1);
			pX = zeros(nDir, nG);
			pY = zeros(nDir, nG);
			muX = zeros(nDir, 1);
			muY = zeros(nDir, 1);
			sigmaX = zeros(nDir, 1);
			sigmaY = zeros(nDir, 1);
			pXPlusY = zeros(nDir, 2*nG);
			pXMinusY = zeros(nDir, nG);
			hX = zeros(nDir, 1);
			hY = zeros(nDir, 1);
			hXY = zeros(nDir, 1);
			hXY1 = zeros(nDir, 1);
			ramp = 1:nG;
			for k=1:nDir
				p = squeeze(glcmAll(k,:,:));
				mu(k) = mean(p(:));
				pX(k,:) = sum(p, 2);
				pY(k,:) = sum(p, 1);
				muX(k) = sum(ramp.*pX(k,:));
				muY(k) = sum(ramp.*pY(k,:));
				sigmaX(k) = sum(((ramp-muX(k)).^2).*pX(k,:));
				sigmaY(k) = sum(((ramp-muY(k)).^2).*pY(k,:));
				pXPlusY(k,:) = AertsTexture.pXPlusY(p);
				pXMinusY(k,:) = AertsTexture.pXMinusY(p);
				hX(k) = AertsTexture.entropy(pX(k,:));
				hY(k) = AertsTexture.entropy(pY(k,:));
				hXY(k) = AertsTexture.entropy(p);
				hXY1(k) = AertsTexture.partialEntropy(p, pX(k,:), pY(k,:));
			end
			hXY2 = hX+hY;
			% Compute metrics for each direction then average for final value
			autoCorr = zeros(nDir, 1);
			clusterProm = zeros(nDir, 1);
			clusterShade = zeros(nDir, 1);
			clusterTend = zeros(nDir, 1);
			contrast = zeros(nDir, 1);
			correlation = zeros(nDir, 1);
			diffEntropy = zeros(nDir, 1);
			dissimilarity = zeros(nDir, 1);
			energy = zeros(nDir, 1);
			homog1 = zeros(nDir, 1);
			homog2 = zeros(nDir, 1);
			imc1 = zeros(nDir, 1);
			imc2 = zeros(nDir, 1);
			idmn = zeros(nDir, 1);
			idn = zeros(nDir, 1);
			inverseVar = zeros(nDir, 1);
			maxP = zeros(nDir, 1);
			sumAverage = zeros(nDir, 1);
			sumEntropy = zeros(nDir, 1);
			sumVariance = zeros(nDir, 1);
			valid = false(nDir, 1);
			for k=1:nDir
				p = squeeze(glcmAll(k,:,:));
				% Metrics are undefined if p is all zero
				valid(k) = ~all(p(:) == 0);
				if ~valid(k)
					continue;
				end
				autoCorr(k) = AertsTexture.autocorrelation(p);
				clusterProm(k) = AertsTexture.clusterProminence(p, muX(k), muY(k));
				clusterShade(k) = AertsTexture.clusterShade(p, muX(k), muY(k));
				clusterTend(k) = AertsTexture.clusterTendency(p, muX(k), muY(k));
				contrast(k) = AertsTexture.contrast(p);
				correlation(k) = AertsTexture.correlation(p, muX(k), muY(k), ...
					sigmaX(k), sigmaY(k));
				diffEntropy(k) = AertsTexture.entropy(pXMinusY(k,:));
				dissimilarity(k) = AertsTexture.dissimilarity(p);
				energy(k) = AertsTexture.energy(p);
				homog1(k) = AertsTexture.homogeneity1(p);
				homog2(k) = AertsTexture.homogeneity2(p);
				imc1(k) = (hXY(k)-hXY1(k))/max([hX(k),hY(k)]);
				imc2(k) = sqrt(1-exp(-2*(hXY2(k)-hXY(k))));
				idmn(k) = AertsTexture.idmn(p);
				idn(k) = AertsTexture.idn(p);
				inverseVar(k) = AertsTexture.inverseVariance(p);
				maxP(k) = max(p(:));
				sumAverage(k) = AertsTexture.sumAverage(pXPlusY(k,:));
				sumEntropy(k) = AertsTexture.entropy(pXPlusY(k,2:end));
				sumVariance(k) = AertsTexture.sumVariance(pXPlusY(k,:), ...
					sumAverage(k));
			end
			collector(AertsTexture.Autocorrelation) = mean(autoCorr(valid));
			collector(AertsTexture.ClusterProminence) = mean(clusterProm(valid));
			collector(AertsTexture.ClusterShade) = mean(clusterShade(valid));
			collector(AertsTexture.ClusterTendency) = mean(clusterTend(valid));
			collector(AertsTexture.ClusterShade) = mean(clusterShade(valid));
			collector(AertsTexture.Contrast) = mean(contrast(valid));
			collector(AertsTexture.Correlation) = mean(correlation(valid));
			collector(AertsTexture.DifferenceEntropy) = mean(diffEntropy(valid));
			collector(AertsTexture.Dissimilarity) = mean(dissimilarity(valid));
			collector(AertsTexture.Energy) = mean(energy(valid));
			collector(AertsTexture.Entropy) = mean(hXY(valid));
			collector(AertsTexture.Homogeneity1) = mean(homog1(valid));
			collector(AertsTexture.Homogeneity2) = mean(homog2(valid));
			collector(AertsTexture.InformationalMeasureCorrelation1) = ...
				mean(imc1(valid));
			collector(AertsTexture.InformationalMeasureCorrelation2) = ...
				mean(imc2(valid));
			collector(AertsTexture.InverseDifferenceMomentNormalised) = ...
				mean(idmn(valid));
			collector(AertsTexture.InverseDifferenceNormalised) = mean(idn(valid));
			collector(AertsTexture.InverseVariance) = mean(inverseVar(valid));
			collector(AertsTexture.MaximumProbability) = mean(maxP(valid));
			collector(AertsTexture.SumAverage) = mean(sumAverage(valid));
			collector(AertsTexture.SumEntropy) = mean(sumEntropy(valid));
			collector(AertsTexture.SumVariance) = mean(sumVariance(valid));
			% Variance is ignored as definition makes no sense in Aerts or Haralick
		end

		%-------------------------------------------------------------------------
		function collector = glrlmMetrics(image3D, mask3D, nG, nR, collector, dimFlag)
			import radiomics.*;
			[glrlmAll,nDir] = AertsTexture.glrlm3D(image3D, mask3D, nG, nR, dimFlag);
			% Precompute reused quantities according to Aerts 2014
			nP = nnz(mask3D);
			sumP = zeros(nDir, 1);
			for k=1:nDir
				p = squeeze(glrlmAll(k,:,:));
				sumP(k) = sum(p(:));
			end
			% Compute metrics for each direction then average for final value
			sre = zeros(nDir, 1);
			lre = zeros(nDir, 1);
			gln = zeros(nDir, 1);
			rln = zeros(nDir, 1);
			rp = zeros(nDir, 1);
			lglre = zeros(nDir, 1);
			hglre = zeros(nDir, 1);
			srlgle = zeros(nDir, 1);
			srhgle = zeros(nDir, 1);
			lrlgle = zeros(nDir, 1);
			lrhgle = zeros(nDir, 1);
			valid = false(nDir, 1);
			for k=1:nDir
				p = squeeze(glrlmAll(k,:,:));
				% Metrics are undefined if p is all zero
				valid(k) = ~all(p(:) == 0);
				if ~valid(k)
					continue;
				end
				sre(k) = AertsTexture.shortRunEmphasis(p, sumP(k));
				lre(k) = AertsTexture.longRunEmphasis(p, sumP(k));
				gln(k) = AertsTexture.greyLevelNonUniformity(p, sumP(k));
				rln(k) = AertsTexture.runLengthNonUniformity(p, sumP(k));
				rp(k) = sumP(k)/nP;
				lglre(k) = AertsTexture.lowGreyLevelRunEmphasis(p, sumP(k));
				hglre(k) = AertsTexture.highGreyLevelRunEmphasis(p, sumP(k));
				srlgle(k) = AertsTexture.shortRunLowGreyLevelEmphasis(p, sumP(k));
				srhgle(k) = AertsTexture.shortRunHighGreyLevelEmphasis(p, sumP(k));
				lrlgle(k) = AertsTexture.longRunLowGreyLevelEmphasis(p, sumP(k));
				lrhgle(k) = AertsTexture.longRunHighGreyLevelEmphasis(p, sumP(k));
			end
			collector(AertsTexture.ShortRunEmphasis) = mean(sre(valid));
			collector(AertsTexture.LongRunEmphasis) = mean(lre(valid));
			collector(AertsTexture.GreyLevelNonUniformity) = mean(gln(valid));
			collector(AertsTexture.RunLengthNonUniformity) = mean(rln(valid));
			collector(AertsTexture.RunPercentage) = mean(rp(valid));
			collector(AertsTexture.LowGreyLevelRunEmphasis) = mean(lglre(valid));
			collector(AertsTexture.HighGreyLevelRunEmphasis) = mean(hglre(valid));
			collector(AertsTexture.ShortRunLowGreyLevelEmphasis) = ...
				mean(srlgle(valid));
			collector(AertsTexture.ShortRunHighGreyLevelEmphasis) = ...
				mean(srhgle(valid));
			collector(AertsTexture.LongRunLowGreyLevelEmphasis) = ...
				mean(lrlgle(valid));
			collector(AertsTexture.LongRunHighGreyLevelEmphasis) = ...
				mean(lrhgle(valid));
		end

		%-------------------------------------------------------------------------
		function result = homogeneity1(p)
			result = 0;
			sz = size(p);
			nG = sz(1);
			for i=1:nG
				for j=1:nG
					result = result+p(i,j)/(1+abs(i-j));
				end
			end
		end

		%-------------------------------------------------------------------------
		function result = homogeneity2(p)
			result = 0;
			sz = size(p);
			nG = sz(1);
			for i=1:nG
				for j=1:nG
					result = result+p(i,j)/(1+(abs(i-j)).^2);
				end
			end
		end

		%-------------------------------------------------------------------------
		function result = idmn(p)
			result = 0;
			sz = size(p);
			nG = sz(1);
			for i=1:nG
				for j=1:nG
					result = result+p(i,j)/(1+(abs(i-j)/nG).^2);
				end
			end
		end

		%-------------------------------------------------------------------------
		function result = idn(p)
			result = 0;
			sz = size(p);
			nG = sz(1);
			for i=1:nG
				for j=1:nG
					result = result+p(i,j)/(1+(abs(i-j)/nG));
				end
			end
		end

		%-------------------------------------------------------------------------
		function result = inverseVariance(p)
			result = 0;
			sz = size(p);
			nG = sz(1);
			for i=1:nG
				for j=1:nG
					if (i ~= j)
						result = result+p(i,j)/(abs(i-j).^2);
					end
				end
			end
		end

		%-------------------------------------------------------------------------
		function bool = isRunStart(image3D, idx, dir)
			import radiomics.*;
			sz = size(image3D);
			[y,x,z] = ind2sub(sz, idx);
			dirY = y-dir(1);
			dirX = x-dir(2);
			dirZ = z-dir(3);
			bool = AertsTexture.isValidIdx(dirY, dirX, dirZ, sz(1), sz(2), sz(3));
			% edit to enable this function to work when idx is a 1D array
			bool = bool & (image3D(sub2ind(sz,dirY,dirX,dirZ)) ~= image3D(idx));
			%if bool
			%   bool = image3D(dirY,dirX,dirZ) ~= image3D(idx);
			%end
		end

		%-------------------------------------------------------------------------
		% !!! Note order of arguments
		function bool = isValidIdx(y, x, z, maxY, maxX, maxZ)
			bool = (x > 0) & (x <= maxX) & ...
				(y > 0) & (y <= maxY) & ...
				(z > 0) & (z <= maxZ);
		end

		%-------------------------------------------------------------------------
		function result = partialEntropy(p, pX, pY)
			result = 0;
			sz = size(p);
			nG = sz(1);
			for i=1:nG
				for j=1:nG
					if (p(i,j) > 0)
						result = result-p(i,j)*log2(pX(i)*pY(j));
					end
				end
			end
		end

		%-------------------------------------------------------------------------
		function result = pXPlusY(p)
			sz = size(p);
			nG = sz(1);
			result = zeros(2*nG, 1);
			for i=1:nG
				for j=1:nG
					idx = i+j;
					result(idx) = result(idx)+p(i,j);
				end
			end
		end

		%-------------------------------------------------------------------------
		function result = pXMinusY(p)
			sz = size(p);
			nG = sz(1);
			result = zeros(nG, 1);
			for i=1:nG
				for j=1:nG
					idx = abs(i-j)+1;
					result(idx) = result(idx)+p(i,j);
				end
			end
		end

		%-------------------------------------------------------------------------
		function result = runLengthNonUniformity(p, denom)
			sz = size(p);
			nG = sz(1);
			nR = sz(2);
			result = zeros(nR, 1);
			for j=1:nR
				for i=1:nG
					result(j) = result(j)+p(i,j);
				end
				result(j) = result(j).^2;
			end
			result = sum(result)/denom;
		end

		%-------------------------------------------------------------------------
		function result = greyLevelNonUniformity(p, denom)
			sz = size(p);
			nG = sz(1);
			nR = sz(2);
			result = zeros(nG, 1);
			for i=1:nG
				for j=1:nR
					result(i) = result(i)+p(i,j);
				end
				result(i) = result(i).^2;
			end
			result = sum(result)/denom;
		end

		%-------------------------------------------------------------------------
		function result = highGreyLevelRunEmphasis(p, denom)
			result = 0;
			sz = size(p);
			nG = sz(1);
			nR = sz(2);
			for i=1:nG
				iSq = (i.^2);
				for j=1:nR
					result = result+(p(i,j).*iSq);
				end
			end
			result = result/denom;
		end

		%-------------------------------------------------------------------------
		function result = longRunEmphasis(p, denom)
			result = 0;
			sz = size(p);
			nG = sz(1);
			nR = sz(2);
			for i=1:nG
				for j=1:nR
					result = result+(p(i,j).*(j.^2));
				end
			end
			result = result/denom;
		end

		%-------------------------------------------------------------------------
		function result = longRunHighGreyLevelEmphasis(p, denom)
			result = 0;
			sz = size(p);
			nG = sz(1);
			nR = sz(2);
			for i=1:nG
				iSq = i.^2;
				for j=1:nR
					result = result+(p(i,j).*iSq.*(j.^2));
				end
			end
			result = result/denom;
		end

		%-------------------------------------------------------------------------
		function result = longRunLowGreyLevelEmphasis(p, denom)
			result = 0;
			sz = size(p);
			nG = sz(1);
			nR = sz(2);
			for i=1:nG
				invISq = 1./(i.^2);
				for j=1:nR
					result = result+(p(i,j).*(j.^2).*invISq);
				end
			end
			result = result/denom;
		end

		%-------------------------------------------------------------------------
		function result = lowGreyLevelRunEmphasis(p, denom)
			result = 0;
			sz = size(p);
			nG = sz(1);
			nR = sz(2);
			for i=1:nG
				invISq = 1./(i.^2);
				for j=1:nR
					result = result+(p(i,j).*invISq);
				end
			end
			result = result/denom;
		end

		%-------------------------------------------------------------------------
		function result = shortRunEmphasis(p, denom)
			result = 0;
			sz = size(p);
			nG = sz(1);
			nR = sz(2);
			for i=1:nG
				for j=1:nR
					result = result+(p(i,j)./(j.^2));
				end
			end
			result = result/denom;
		end

		%-------------------------------------------------------------------------
		function result = shortRunHighGreyLevelEmphasis(p, denom)
			result = 0;
			sz = size(p);
			nG = sz(1);
			nR = sz(2);
			for i=1:nG
				iSq = i.^2;
				for j=1:nR
					result = result+(p(i,j).*iSq./(j.^2));
					T(i,j) = iSq/j^2;
				end
			end
			result = result/denom;
		end

		%-------------------------------------------------------------------------
		function result = shortRunLowGreyLevelEmphasis(p, denom)
			result = 0;
			sz = size(p);
			nG = sz(1);
			nR = sz(2);
			for i=1:nG
				iSq = i.^2;
				for j=1:nR
					result = result+(p(i,j)./(iSq.*(j.^2)));
				end
			end
			result = result/denom;
		end

		%-------------------------------------------------------------------------
		function result = sumAverage(p)
			result = 0;
			for i=2:numel(p)
				result = result+i*p(i);
			end
		end

		%-------------------------------------------------------------------------
		function result = sumVariance(p, sumAverage)
			result = 0;
			for i=2:numel(p)
				result = result+(i-sumAverage).^2*p(i);
			end
		end

	end % methods(Static,Access=private)

end

