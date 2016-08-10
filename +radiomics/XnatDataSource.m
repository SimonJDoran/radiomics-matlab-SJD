classdef XnatDataSource < radiomics.DataSource
	%XNATDATASOURCE Summary of this class goes here
	%   Detailed explanation goes here
	
	%----------------------------------------------------------------------------
	properties(Constant,Access=private)
		logger = ether.log4m.Logger.getLogger('radiomics.DbDataSource');
	end

	%----------------------------------------------------------------------------
	properties(Access=private)
		conn = [];
		xds = [];
	end
	
	%----------------------------------------------------------------------------
	methods
		%-------------------------------------------------------------------------
		function this = XnatDataSource()
			xnatToolkit = etherj.xnat.XnatToolkit.getToolkit();
% 			this.conn = xnatToolkit.createServerConnection(...
% 				'https://bifrost.icr.ac.uk:8443/XNAT_ROI', 'jamesd', 'Trl-50%');
			this.conn = xnatToolkit.createServerConnection(...
				'https://bifrost.icr.ac.uk:8443/XNAT_ROI', 'admin', 'XN_admin-2015');
			this.conn.open();
			this.xds = xnatToolkit.createDataSource(this.conn);
		end

		%-------------------------------------------------------------------------
		function delete(this)
			this.safeShutdown(this.conn);
		end

		%-------------------------------------------------------------------------
		function rtStruct = getRtStructForMarkup(this, markupUid)
			jRtStruct = this.xds.getRtStructForMarkup(markupUid);
			if ~isempty(jRtStruct)
				rtStruct = ether.dicom.RtStruct(jRtStruct);
			else
				rtStruct = [];
			end
		end

		%-------------------------------------------------------------------------
		function iacList = searchIac(this, patient, varargin)
			iacList = ether.collect.CellArrayList(...
				'ether.aim.ImageAnnotationCollection');

			if ((nargin == 3) && ischar(varargin{1}))
				projectId = varargin{1};
			else
				projectId = '';
			end
			jIacList = this.xds.searchIac(projectId, patient);
			for i=0:jIacList.size()-1
				jIac = jIacList.get(i);
				iacList.add(ether.aim.ImageAnnotationCollection(jIac));
			end
		end

		%-------------------------------------------------------------------------
		function series = getImageSeries(this, uid, type, varargin)
			import radiomics.*;
			series = [];
			switch type
				case DataSource.Study
					this.logger.warn('DataSource::getImageSeries(): Study-wide search not supported');

				case DataSource.Series
					jSeries = this.xds.getSeries(uid);
					series = ether.dicom.Toolkit.getToolkit().createSeries(jSeries);

				case DataSource.Instance
					this.logger.warn('DataSource::getImageSeries(): Instance search not supported');

				otherwise
					throw(MException('Radiomics:DataSource', ...
						['Unknown ID type: ',type]));
			end
		end

		%-------------------------------------------------------------------------
		function list = getRtStructList(this, id, type, varargin)
			import radiomics.*;
			switch type
				case DataSource.Study
					rtList = this.getRtStructsForStudy(id);
					aimList = this.getAimRois(id);

				case DataSource.Series
					rtList = this.getRtStructsForSeries(id);
					aimList = this.getAimRois(id);

				otherwise
					throw(MException('Radiomics:DataSource', ...
						['Unknown ID type: ',type]));
			end
			list = ether.collect.CellArrayList('ether.dicom.RtStruct');
			list.addAll(rtList);
			list.addAll(aimList);
		end

		%-------------------------------------------------------------------------
		function safeShutdown(this, conn)
			try
				conn.close();
			catch ex
				this.logger.warn(ex.getMessage());
			end
		end

	end

	%----------------------------------------------------------------------------
	methods(Access=private)
	end

end

