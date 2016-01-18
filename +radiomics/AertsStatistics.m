classdef AertsStatistics < handle
	%AERTSSTATISTICS Summary of this class goes here
	%   Detailed explanation goes here
	
	properties(Constant)
		Energy = 'Aerts.Statistics.Energy';
		Entropy = 'Aerts.Statistics.Entropy';
		Kurtosis = 'Aerts.Statistics.Kurtosis';
		Maximum = 'Aerts.Statistics.Maximum';
		Mean = 'Aerts.Statistics.Mean';
		MeanAbsoluteDeviation = 'Aerts.Statistics.MeanAbsoluteDeviation';
		Median = 'Aerts.Statistics.Median';
		Minimum = 'Aerts.Statistics.Minimum';
		Range = 'Aerts.Statistics.Range';
		RMS = 'Aerts.Statistics.RMS';
		Skewness = 'Aerts.Statistics.Skewness';
		StandardDeviation = 'Aerts.Statistics.StandardDeviation';
		Uniformity = 'Aerts.Statistics.Uniformity';
		Variance = 'Aerts.Statistics.Variance';
	end
	
	%----------------------------------------------------------------------------
	methods(Static)
		%-------------------------------------------------------------------------
		function collector = compute(image3D, mask3D, collector)
			import radiomics.*;
			greyLevels = image3D(mask3D == 1);
			pHist = AertsStatistics.histogram(greyLevels);

			maxGrey = max(greyLevels);
			minGrey = min(greyLevels);
			meanGrey = mean(greyLevels);
			collector(AertsStatistics.Energy) = sum(greyLevels.^2);
			collector(AertsStatistics.Entropy) = AertsStatistics.entropy(pHist);
			collector(AertsStatistics.Kurtosis) = kurtosis(greyLevels);
			collector(AertsStatistics.Maximum) = maxGrey;
			collector(AertsStatistics.Mean) = meanGrey;
			collector(AertsStatistics.MeanAbsoluteDeviation) = ...
				mean(abs(greyLevels-meanGrey));
			collector(AertsStatistics.Median) = median(greyLevels);
			collector(AertsStatistics.Minimum) = minGrey;
			collector(AertsStatistics.Range) = maxGrey-minGrey;
			collector(AertsStatistics.RMS) = sqrt(mean(greyLevels.^2));
			collector(AertsStatistics.Skewness) = skewness(greyLevels);
			collector(AertsStatistics.StandardDeviation) = std(greyLevels);
			collector(AertsStatistics.Uniformity) = sum(pHist.^2);
			collector(AertsStatistics.Variance) = var(greyLevels);
		end

	end % methods(Static)

	%----------------------------------------------------------------------------
	methods(Static,Access=private)
		%-------------------------------------------------------------------------
		function result = entropy(pHist)
			idx = pHist > 0;
			result = -sum(pHist(idx).*log2(pHist(idx)));
		end

		%-------------------------------------------------------------------------
		function pHist = histogram(greyLevels)
			rawHist = histcounts(greyLevels);
			idx = rawHist > 0;
			pHist = zeros(numel(rawHist),1);
			pHist(idx) = rawHist(idx)/sum(rawHist(idx));
		end

	end % methods(Static,Access=private)

end

