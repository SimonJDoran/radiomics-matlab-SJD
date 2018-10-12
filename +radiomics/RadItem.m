classdef (Abstract) RadItem < handle
	%IAITEM Summary of this class goes here
	%   Detailed explanation goes here
	
	properties(SetAccess=protected)
      type;
		lesionNumber;
		roiNumber;
		scan = '';
	end

	properties(Abstract)
		personId;
		personName;
      dateTime;
   end
   
   methods
      function this = RadItem(arg1, arg2)
      end
   end 
   
   methods(Access=protected)
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