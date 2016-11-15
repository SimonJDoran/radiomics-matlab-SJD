classdef MarkupItem < handle
	%MARKUPITEM Summary of this class goes here
	%   Detailed explanation goes here

	%----------------------------------------------------------------------------
	properties
		ivIdx = -1;
		mask = [];
	end

	%----------------------------------------------------------------------------
	properties(SetAccess=private)
		iaItem = [];
		markup = [];
	end

	%----------------------------------------------------------------------------
	properties(Dependent)
 		imageReferenceUid;
	end

	%----------------------------------------------------------------------------
	properties(Access=private)
		maskInternal = [];
	end

	%----------------------------------------------------------------------------
	methods
		%-------------------------------------------------------------------------
		function this = MarkupItem(markup, iaItem)
			if ~isa(markup, 'ether.aim.GeometricShape')
				throw(MException('Radiomics:MarkupItem', ...
					'Markup must be a GeometricShape'));
			end
			this.markup = markup;
			this.iaItem = iaItem;
% 			annoName = char(ia.name);
% 			tokens = strsplit(annoName, '~');
% 			tokens = strsplit(tokens{1}, '-');
% 			if (~this.parseTokens(tokens))
% 				this.lesionNumber = -1;
% 				this.scan = [tokens{1}];
% 				this.roiNumber = -1;
% 			end
		end

		%-------------------------------------------------------------------------
		function value = get.imageReferenceUid(this)
			value = char(this.markup.imageReferenceUid);
		end

	end

	%----------------------------------------------------------------------------
	methods(Access=private)
% 		function value = get.personName(this)
% 			value = char(this.iac.person.name);
% 		end
	end

end

