classdef TextureAnalyser < handle
	%TEXTUREANALYSER Summary of this class goes here
	%   Detailed explanation goes here
	
	%----------------------------------------------------------------------------
	properties
	end

	%----------------------------------------------------------------------------
	methods(Abstract)
		%-------------------------------------------------------------------------
		resultList = analyse(this, iaItems, dataSource, projectId);
	end

end

