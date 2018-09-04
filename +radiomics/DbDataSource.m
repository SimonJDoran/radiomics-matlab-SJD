classdef DbDataSource < radiomics.DataSource
	%DBDATASOURCE Summary of this class goes here
	%   Detailed explanation goes here
	
	%----------------------------------------------------------------------------
	properties(Constant,Access=private)
		logger = ether.log4m.Logger.getLogger('radiomics.DbDataSource');
	end

	%----------------------------------------------------------------------------
	properties(SetAccess=private)
		aimDb;
		dcmDb;
		jDataSource;
	end

	%----------------------------------------------------------------------------
	properties(Access=private)
		etherDcmToolkit;
		jAimToolkit;
		jDcmToolkit;
	end

	%----------------------------------------------------------------------------
	methods
		%-------------------------------------------------------------------------
		function this = DbDataSource(aimDb, dcmDb)
			import ether.dicom.*;
			this.etherDcmToolkit = Toolkit.getToolkit();
			this.jDcmToolkit = icr.etherj.dicom.DicomToolkit.getToolkit();
			this.jAimToolkit = icr.etherj.aim.AimToolkit.getToolkit();
			if (nargin ~= 2)
				this.dcmDb = this.jDcmToolkit.createDicomDatabase();
				this.aimDb = this.jAimToolkit.createAimDatabase();
			else
				this.aimDb = aimDb;
				this.dcmDb = dcmDb;
			end
		end

		%-------------------------------------------------------------------------
		function delete(this)
			this.safeShutdown(this.aimDb);
			this.safeShutdown(this.dcmDb);
		end

		%-------------------------------------------------------------------------
		function importAim(this, dir)
			this.aimDb.importDirectory(dir);
		end

		%-------------------------------------------------------------------------
		function importDicom(this, dir)
			this.dcmDb.importDirectory(dir);
		end

		%-------------------------------------------------------------------------
		function series = getImageSeries(this, projectId, uid, type, varargin)
			import radiomics.*;
			series = [];
			switch type
				case DataSource.Study
					this.logger.warn(...
						'DataSource::getImageSeries(): Study-wide search not supported');

				case DataSource.Series
					series = this.getSeries(uid);

				case DataSource.Instance
					series = this.getSeriesForInstance(uid);

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
		function iacList = searchIac(this, patient, varargin)
			import radiomics.*;
			import ether.aim.*;
			iacList = ether.collect.CellArrayList(...
				'ether.aim.ImageAnnotationCollection');

			jParser = this.jAimToolkit.createXmlParser();
			jFileUidPairs = this.aimDb.search(patient);
			for i=0:jFileUidPairs.size()-1
				try
					jIac = jParser.parse(jFileUidPairs.get(i).getPath());
					iacList.add(ImageAnnotationCollection(jIac));
				catch ex
					this.logger.warn(['DbDataSource::searchIac(): ',ex.message]);
				end
			end
		end

	end

	%----------------------------------------------------------------------------
	methods(Access=private)
		%-------------------------------------------------------------------------
		function rtStructList = getAimRois(this, uid)
			import icr.etherj.aim.*;
			import org.dcm4che2.data.*;
			rtStructList = ether.collect.CellArrayList('ether.dicom.RtStruct');

			jFileUidPairs = this.aimDb.searchDicomUid(uid);
			converter = this.jDcmToolkit.createRoiConverter( ...
				this.jDcmToolkit.createDataSource());
			for i=0:jFileUidPairs.size()-1
				iac = XmlParser.parse(jFileUidPairs.get(i).getPath());
				dcm = converter.toRtStruct(iac);
				rtStruct = this.etherDcmToolkit.createRtStruct(dcm);
				rtStructList.add(rtStruct);
			end
		end

		%-------------------------------------------------------------------------
		function rtStructList = getRtStructsForStudy(this, uid)
			import icr.etherj.dicom.*;
			import org.dcm4che2.data.*;
			rtStructList = ether.collect.CellArrayList('ether.dicom.RtStruct');

			% Search spec
			rtSpec = this.jDcmToolkit.createSearchSpecification();
			% Modality criterion
			rtModSc = this.jDcmToolkit.createSearchCriterion(Tag.Modality, ...
				SearchCriterion.Equal, Modality.RTSTRUCT);
			rtModSc.setDicomType(SearchCriterion.Instance);
			rtSpec.addCriterion(rtModSc);
			% Series UID criterion
			rtStUidSc = this.jDcmToolkit.createSearchCriterion( ...
				Tag.StudyInstanceUID, SearchCriterion.Equal, uid);
			rtStUidSc.setDicomType(SearchCriterion.Instance);
			rtSpec.addCriterion(rtStUidSc);

			% Search and populate the list
			rtInstList = this.dcmDb.searchInstance(rtSpec);
			for i=0:rtInstList.size()-1
				rtStruct = this.etherDcmToolkit.createRtStruct(rtInstList.get(i));
				rtStructList.add(rtStruct);
			end
		end

		%-------------------------------------------------------------------------
		function series = getSeries(this, uid)
			import icr.etherj.dicom.*;
			import org.dcm4che2.data.*;
			series = [];

			% Search spec
			spec = this.jDcmToolkit.createSearchSpecification();
			% Series UID criterion
			sc = this.jDcmToolkit.createSearchCriterion( ...
				Tag.SeriesInstanceUID, SearchCriterion.Equal, uid);
			sc.setDicomType(SearchCriterion.Series);
			spec.addCriterion(sc);

			% Search and populate the list
			patientRoot = this.dcmDb.search(spec);
			patients = patientRoot.getPatientList();
			if (patients.isEmpty())
				return;
			end
			% Series must exist but can only exist in one Patient and one Study
			jSeries = patients.get(0).getStudyList().get(0).getSeries(uid);
			jInstList = jSeries.getSopInstanceList();
			jSopInst = jInstList.get(0);
			sopInst = this.etherDcmToolkit.createSopInstance( ...
				char(jSopInst.getPath()), jSopInst.getDicomObject());
			series = this.etherDcmToolkit.createSeries(sopInst);
			series.addSopInstance(sopInst, this.etherDcmToolkit);
			for i=1:jInstList.size()-1
				jSopInst = jInstList.get(i);
				sopInst = this.etherDcmToolkit.createSopInstance( ...
					char(jSopInst.getPath()), jSopInst.getDicomObject());
				series.addSopInstance(sopInst, this.etherDcmToolkit);
			end
		end

		%-------------------------------------------------------------------------
		function series = getSeriesForInstance(this, uid)
			import icr.etherj.dicom.*;
			import org.dcm4che2.data.*;
			series = [];

			jSopInst = this.dcmDb.searchInstance(uid);
			if (isempty(jSopInst))
				return;
			end
			seriesUid = char(jSopInst.getSeriesUid());
			series = this.getSeries(seriesUid);
		end

		%-------------------------------------------------------------------------
		function safeShutdown(this, db)
			try
				db.shutdown();
			catch ex
				this.logger.warn(ex.getMessage());
			end
		end
	end
	
end
