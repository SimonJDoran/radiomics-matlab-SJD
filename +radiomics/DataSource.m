classdef DataSource < handle
	%DATASOURCE Summary of this class goes here
	%   Detailed explanation goes here
	
	properties(Constant)
		Instance = 'Instance';
		Series = 'Series';
		Study = 'Study';
	end
	
	methods(Abstract)
		series = getImageSeries(this, uid, type, varargin);

		roiList = getRtStructList(this, id, type, varargin);
	end
	
end

