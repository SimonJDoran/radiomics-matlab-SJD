classdef IaItem < handle
	%IAITEM Summary of this class goes here
	%   Detailed explanation goes here
	
	properties(SetAccess=private)
		ia = [];
		iac = [];
		lesionNumber;
		roiNumber;
		scan = '';
	end

	properties(Dependent)
		personId;
		personName;
	end

	methods
		function this = IaItem(ia, iac)
			this.ia = ia;
			this.iac = iac;
			annoName = char(ia.name);
			tokens = strsplit(annoName, '~');
			tokens = strsplit(tokens{1}, '-');
			if (~this.parseTokens(tokens))
				this.lesionNumber = -1;
				this.scan = [tokens{1}];
				this.roiNumber = -1;
			end
		end

		function value = get.personId(this)
			value = char(this.iac.person.id);
		end

		function value = get.personName(this)
			value = char(this.iac.person.name);
		end
	end

	methods(Access=private)
		function bool = parseTokens(this, tokens)
			bool = false;	
			if (length(tokens) < 3)
				return;
			end
			if (tokens{2}(end) == 'a') || (tokens{1}(end) == 'A')
				this.scan = 'A';
			elseif (tokens{2}(end) == 'b') || (tokens{1}(end) == 'B')
				this.scan = 'B';
			else
				return;
			end
			value = str2double(tokens{2}(1:end-1));
			if ~isfinite(value)
				return;
			end
			this.lesionNumber = value;
			endIdx = 0;
			while ((endIdx < length(tokens{3})) && isstrprop(tokens{3}(endIdx+1), 'digit'))
				endIdx = endIdx+1;
			end
			value = str2double(tokens{3}(1:endIdx));
			if ~isfinite(value)
				return;
			end
			this.roiNumber = value;
			bool = true;
			return;
		end
	end

end

