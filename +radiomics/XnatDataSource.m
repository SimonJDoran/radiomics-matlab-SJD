classdef XnatDataSource < radiomics.DataSource
	%XNATDATASOURCE Summary of this class goes here
	%   Detailed explanation goes here
	
	%----------------------------------------------------------------------------
	properties(Constant,Access=private)
		logger = ether.log4m.Logger.getLogger('radiomics.XnatDataSource');
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
			xnatToolkit = icr.etherj.xnat.XnatToolkit.getToolkit();
			this.conn = xnatToolkit.createServerConnection(...
				'http://localhost:8015/XNAT_SIMOND', 'admin', 'admin');
			this.conn.open();
			this.xds = xnatToolkit.createDataSource(this.conn);
		end

		%-------------------------------------------------------------------------
		function delete(this)
			this.safeShutdown(this.conn);
		end

		%-------------------------------------------------------------------------
		function rtStruct = getRtStructForMarkup(this, projectId, markupUid)
			jRtStruct = this.xds.getRtStructForMarkup(projectId, markupUid);
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
				projectLabel = varargin{1};
         else
				projectLabel = '';
			end
			%jIacList = this.xds.searchIac(projectId, patient);
         xns = icr.etherj.matlab.XnatSearcherForMatlab(this.xds);         
         jIacList = xns.searchIacProjLabelSubjLabel(projectLabel, patient);
         
			for i=0:jIacList.size()-1
				jIac = jIacList.get(i);
				iacList.add(ether.aim.ImageAnnotationCollection(jIac));
			end
		end

		%-------------------------------------------------------------------------
		function rtsList = searchRts(this, patient, varargin)
			rtsList = ether.collect.CellArrayList(...
				'ether.dicom.RtStruct');

			if ((nargin == 3) && ischar(varargin{1}))
				projectLabel = varargin{1};
         else
				projectLabel = '';
			end
			
         xns = icr.etherj.matlab.XnatSearcherForMatlab(this.xds);         
         jRtsList = xns.searchRtsProjLabelSubjLabel(projectLabel, patient);
         
			for i=0:jRtsList.size()-1
				jRts = jRtsList.get(i);
				rtsList.add(ether.dicom.RtStruct(jRts));
			end
		end

		%-------------------------------------------------------------------------
		function series = getImageSeries(this, projectId, uid, type, varargin)
			import radiomics.*;
			series = [];
			switch type
				case DataSource.Study
					this.logger.warn('DataSource::getImageSeries(): Study-wide search not supported');

				case DataSource.Series
					jSeriesMap = this.xds.getSeries(projectId, uid);
					jSeries = jSeriesMap.values.iterator.next();
					if ~isempty(jSeries)
						series = ether.dicom.Toolkit.getToolkit().createSeries(jSeries);
					else
						this.logger.info(['DataSource::getImageSeries(): UID not found:',uid]);
					end

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

