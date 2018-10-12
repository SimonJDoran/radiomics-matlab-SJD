classdef TextureResult < handle
	%TEXTURERESULT Summary of this class goes here
	%   Detailed explanation goes here
	
	properties(SetAccess=private)
		results;
		radItem;
	end
	
	%----------------------------------------------------------------------------
	methods
		%-------------------------------------------------------------------------
		function this = TextureResult(results, radItem)
			this.results = results;
			this.radItem = radItem;
		end
	end
	
end

