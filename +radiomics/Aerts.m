classdef Aerts < handle
	%AERTS Summary of this class goes here
	%   Decoding tumour phenotype by noninvasive imaging using a quantitative
	% radiomics approach. Aerts et al. Nature Communications 2014
	% DOI: 10.1038/ncomms5006
	
	methods(Static)
		function metrics = getMetrics()
			persistent staticMetrics;
			if (isempty(staticMetrics))
				staticMetrics = radiomics.Aerts.createMetrics();
			end
			metrics = ether.collect.List.unmodifiable(staticMetrics);
		end
	end

	methods(Static,Access=private)
		function metrics = createMetrics()
			import radiomics.*;
			metrics = ether.collect.CellArrayList('char');
			metrics.add(AertsStatistics.Energy);
			metrics.add(AertsStatistics.Entropy);
			metrics.add(AertsStatistics.Kurtosis);
			metrics.add(AertsStatistics.Maximum);
			metrics.add(AertsStatistics.Mean);
			metrics.add(AertsStatistics.MeanAbsoluteDeviation);
			metrics.add(AertsStatistics.Median);
			metrics.add(AertsStatistics.Minimum);
			metrics.add(AertsStatistics.Range);
			metrics.add(AertsStatistics.RMS);
			metrics.add(AertsStatistics.Skewness);
			metrics.add(AertsStatistics.StandardDeviation);
			metrics.add(AertsStatistics.Uniformity);
			metrics.add(AertsStatistics.Variance);
			metrics.add(AertsShape.Compactness1);
			metrics.add(AertsShape.Compactness2);
			metrics.add(AertsShape.MaximumDiameter);
			metrics.add(AertsShape.SphericalDisproportion);
			metrics.add(AertsShape.Sphericity);
			metrics.add(AertsShape.SurfaceArea);
			metrics.add(AertsShape.SurfaceToVolumeRatio);
			metrics.add(AertsShape.Volume);
			metrics.add(AertsTexture.Autocorrelation);
			metrics.add(AertsTexture.ClusterProminence);
			metrics.add(AertsTexture.ClusterShade);
			metrics.add(AertsTexture.ClusterTendency);
			metrics.add(AertsTexture.Contrast);
			metrics.add(AertsTexture.Correlation);
			metrics.add(AertsTexture.DifferenceEntropy);
			metrics.add(AertsTexture.Dissimilarity);
			metrics.add(AertsTexture.Energy);
			metrics.add(AertsTexture.Entropy);
			metrics.add(AertsTexture.Homogeneity1);
			metrics.add(AertsTexture.Homogeneity2);
			metrics.add(AertsTexture.InformationalMeasureCorrelation1);
			metrics.add(AertsTexture.InformationalMeasureCorrelation2);
			metrics.add(AertsTexture.InverseDifferenceMomentNormalised);
			metrics.add(AertsTexture.InverseDifferenceNormalised);
			metrics.add(AertsTexture.InverseVariance);
			metrics.add(AertsTexture.MaximumProbability);
			metrics.add(AertsTexture.SumAverage);
			metrics.add(AertsTexture.SumEntropy);
			metrics.add(AertsTexture.SumVariance);
		end
	end

end

