classdef AertsTexture
	%AERTSTEXTURE Summary of this class goes here
	%   Decoding tumour phenotype by noninvasive imaging using a quantitative
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
		RunPercentage = 'Aerts.Texture.RunPercentage';
		LowGreyLevelRunEmphasis = 'Aerts.Texture.LowGreyLevelRunEmphasis';
		HighGreyLevelRunEmphasis = 'Aerts.Texture.HighGreyLevelRunEmphasis';
		ShortRunLowGreyLevelRunEmphasis = ...
			'Aerts.Texture.ShortRunLowGreyLevelRunEmphasis';
		ShortRunHighGreyLevelRunEmphasis = ...
			'Aerts.Texture.ShortRunHighGreyLevelRunEmphasis';
		LongRunLowGreyLevelRunEmphasis = ...
			'Aerts.Texture.LongRunLowGreyLevelRunEmphasis';
		LongRunHighGreyLevelRunEmphasis = ...
			'Aerts.Texture.LongRunHighGreyLevelRunEmphasis';
	end

	%----------------------------------------------------------------------------
	methods(Static)
		%-------------------------------------------------------------------------
		function collector = compute(inImage3D, mask3D, collector)
			import radiomics.*;
			% Number of discrete grey levels
			nG = 8;
			image3D = AertsTexture.discretise(inImage3D, mask3D, nG);
			AertsTexture.glcmMetrics(image3D, mask3D, nG, collector);
			[glcmAll,nDir] = AertsTexture.glcm3D(image3D, mask3D, nG);
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
			collector(AertsTexture.InverseVariance) = mean(inverseVar);
			collector(AertsTexture.MaximumProbability) = mean(maxP(valid));
			collector(AertsTexture.SumAverage) = mean(sumAverage(valid));
			collector(AertsTexture.SumEntropy) = mean(sumEntropy(valid));
			collector(AertsTexture.SumVariance) = mean(sumVariance(valid));
			% Variance is ignored as definition makes no sense in Aerts or Haralick
		end

		%-------------------------------------------------------------------------
		function result = discretise(image3D, mask3D, nG)
			idx = find(mask3D == 1);
			pixels = image3D(idx);
			imageMin = min(pixels(:));
			imageMax = max(pixels(:));
			range = imageMax-imageMin;
			result = zeros(size(image3D));
			result(idx)= 1+ceil((nG-1)*((pixels-imageMin)/range));
		end

		%-------------------------------------------------------------------------
		function [result,nDir] = glcm3D(image3D, mask3D, nG)
			import radiomics.*;
			[directions,nDir] = AertsTexture.directions();
			result = zeros(nDir, nG, nG);
			% Linear subscripts of voxels in ROI
			idx = find(mask3D == 1);
			sz = size(image3D);
			for k=1:nDir
				p = zeros(nG, nG);
				% Compute linear subscripts of the voxels in the current direction
				% from voxels in ROI
				[dirY,dirX,dirZ] = ind2sub(sz, idx);
				dirY = dirY+directions(k,1);
				dirX = dirX+directions(k,2);
				dirZ = dirZ+directions(k,3);
				dirIdx = sub2ind(sz, dirY, dirX, dirZ);
				% GLCM for current direction
				for i=1:nG
					for j=1:nG
						p(i,j) = ...
							nnz((image3D(idx) == i) & (image3D(dirIdx) == j));
					end
				end
				% Normalise
				sumP = sum(p(:));
				if sumP > 0
					result(k,:,:) = p/sumP;
				end
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
		function [directions,nDir] = directions()
			% Compute the (dY,dX,dZ) vectors for each direction from chosen pixel
			% Directions that are opposite of another direction are omitted.
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
		function collector = glcmMetrics(image3D, mask3D, nG, collector)
			import radiomics.*;
			[glcmAll,nDir] = AertsTexture.glcm3D(image3D, mask3D, nG);
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
			collector(AertsTexture.InverseVariance) = mean(inverseVar);
			collector(AertsTexture.MaximumProbability) = mean(maxP(valid));
			collector(AertsTexture.SumAverage) = mean(sumAverage(valid));
			collector(AertsTexture.SumEntropy) = mean(sumEntropy(valid));
			collector(AertsTexture.SumVariance) = mean(sumVariance(valid));
			% Variance is ignored as definition makes no sense in Aerts or Haralick
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

