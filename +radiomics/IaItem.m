classdef IaItem < radiomics.RadItem
	%IAITEM Summary of this class goes here
	%   Detailed explanation goes here
	
	properties
      seriesDescription;
   end
   
   properties(SetAccess=private)
		ia = [];
		iac = [];
	end

	properties(Dependent)
		personId;
		personName;
      dateTime;
	end

	methods
		function this = IaItem(ia, iac)
         if ~isa(ia,'ether.aim.ImageAnnotation')
            return
         end
			this.ia = ia;
         if ~isa(iac,'ether.aim.ImageAnnotationCollection')
            return
         end
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
      
      function value = get.dateTime(this)
         value = this.ia.dateTime;
      end
   end

end

