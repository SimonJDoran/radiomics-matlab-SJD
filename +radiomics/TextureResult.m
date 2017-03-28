classdef TextureResult < handle
	%TEXTURERESULT Summary of this class goes here
	%   Detailed explanation goes here
	
	properties(SetAccess=private)
		results;
		iaItem;
	end
	
	%----------------------------------------------------------------------------
	methods
		%-------------------------------------------------------------------------
		function this = TextureResult(results, iaItem)
			this.results = results;
			this.iaItem = iaItem;
		end
	end
	
end

