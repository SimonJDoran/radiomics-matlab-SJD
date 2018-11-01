classdef RtRoiItem < radiomics.RadItem
	%IAITEM Summary of this class goes here
	%   Detailed explanation goes here
	
	properties
      seriesDescription;
   end
   
   properties(SetAccess=private)
		rtRoi = [];
      rts = [];
   end
   
   properties(Dependent)
		personId;
		personName;
      dateTime;
   end 
   
	methods
		function this = RtRoiItem(rtRoi, rts)
         if ~isa(rtRoi,'ether.dicom.RtRoi')
            return 
         end
         this.rtRoi = rtRoi;
         
         if ~isa(rts,'ether.dicom.RtStruct')
            return
         end
			this.rts = rts;
			annoName = char(rts.getPatientName());
			tokens = strsplit(annoName, '~');
			tokens = strsplit(tokens{1}, '-');
			if (~this.parseTokens(tokens))
				this.lesionNumber = -1;
				this.scan = [tokens{1}];
				this.roiNumber = -1;
			end
		end

		function value = get.personName(this)
			value = this.rts.getPatientName();
      end
      
      function value = get.personId(this)
         value = this.rts.getPatientId();
      end
      
      function value = get.dateTime(this)
         value = [this.rts.date, this.rts.time];
      end
	end


end