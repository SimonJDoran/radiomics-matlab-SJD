classdef Main < handle
	%MAIN Summary of this class goes here
	%   Detailed explanation goes here
	
	%----------------------------------------------------------------------------
	properties(Constant,Access=private)
		logger = ether.log4m.Logger.getLogger('radiomics.Main');
	end

	properties(SetAccess=private)
		dataSource = [];
	end

	properties(Access=private)
		aimStudyUid = '1.2.840.113564.9.1.2728161578.69.2.5000228280';
		rtStudyUid = '1.3.12.2.1107.5.8.15.100805.30000015110915184033200000001';
		rtSeriesUid = '1.3.12.2.1107.5.8.15.100805.30000015110915184033200000023';
		abdoStudyUid = '1.2.840.113704.1.111.4392.1423732023.6'
		brainStudyUid = '1.2.840.113704.1.111.4392.1423732023.6'
		% Map<SeriesUid,Series>
		refSeriesMap = [];
		% Map<SeriesUid,Matrix3D>
		seriesVolumeMap = [];
		% Map<SopInstanceUid,SeriesUid>
		instSeriesMap = [];
	end

	methods
		%-------------------------------------------------------------------------
		function this = Main()
			this.dataSource = radiomics.DbDataSource();
		end

		%-------------------------------------------------------------------------
		function run(this)
			import radiomics.*;
			this.logger.info('Radiomics prototype startup');
			this.logger.info(@() sprintf('Retrieving RtStructs for study: %s', ...
				this.rtStudyUid));
			rtStructList = this.dataSource.getRtStructList(this.aimStudyUid, ...
				DataSource.Study);
			this.buildRefSeriesMap(rtStructList);
			for i=1:rtStructList.size()
				rtStruct = rtStructList.get(i);
				this.processRtStruct(rtStruct);
			end
			this.logger.info('Radiomics prototype shutdown');
		end

	end

	methods(Access=private)
		%-------------------------------------------------------------------------
		function buildRefSeriesMap(this, rtStructList)
			import radiomics.*;
			this.refSeriesMap = containers.Map('KeyType', 'char', 'ValueType', 'any');
			this.seriesVolumeMap = containers.Map('KeyType', 'char', 'ValueType', 'any');
			this.instSeriesMap = containers.Map('KeyType', 'char', 'ValueType', 'any');
			nRtStruct = rtStructList.size();
			for i=1:nRtStruct
				rtStruct = rtStructList.get(i);
				refSeriesUidList = rtStruct.getReferencedSeriesUidList();
				for j=1:refSeriesUidList.size()
					refSeriesUid = refSeriesUidList.get(j);
					series = this.dataSource.getImageSeries(refSeriesUid, ...
						DataSource.Series);
					this.insertSeries(series);
				end
			end
			this.logger.info(@() sprintf('%d referenced series loaded', ...
				this.refSeriesMap.length()));
		end

		%-------------------------------------------------------------------------
		function insertSeries(this, series)
			if (isempty(series))
				return;
			end
			this.refSeriesMap(series.instanceUid) = series;
			instList = series.getSopInstanceList();
			for i=1:instList.size()
				inst = instList.get(i);
				this.instSeriesMap(inst.instanceUid) = series.instanceUid;
			end
			this.seriesVolumeMap(series.instanceUid) = radiomics.ImageVolume(series);
			this.logger.info(@() sprintf('Series loaded: %s', ...
				series.instanceUid));
		end

		%-------------------------------------------------------------------------
		function loadImageReferences(this, imageRefs)
			import radiomics.*;
			for i=1:imageRefs.size()
				ref = imageRefs.get(i);
				if this.instSeriesMap.isKey(ref.sopInstanceUid)
					continue;
				end
				series = this.dataSource.getImageSeries(ref.sopInstanceUid, ...
					DataSource.Instance);
				this.insertSeries(series);
			end
		end

		%-------------------------------------------------------------------------
		function outputResults(this, results)
			import radiomics.*;
			metrics = Aerts.getMetrics();
			for i=1:metrics.size()
				name = metrics.get(i);
				if ~results.isKey(name)
					continue;
				end
				fprintf('%s: %f\n', name, results(name));
			end
		end

		%-------------------------------------------------------------------------
		function processRtStruct(this, rtStruct)
			this.logger.info(@() sprintf('Processing RtStruct: %s', ...
				rtStruct.label));
% 			figure;
% 			colormap(gray);
			roiList = rtStruct.getRoiList();
			nRoi = roiList.size();
			for i=1:nRoi
				roi = roiList.get(i);
				this.logger.info(@() sprintf('Processing RtRoi: %s (%d of %d)', ...
					roi.name, i, nRoi));
				roiImageRefs = roi.getImageReferenceList();
				this.loadImageReferences(roiImageRefs);
				seriesUid = this.instSeriesMap(roiImageRefs.get(1).sopInstanceUid);
				iv = this.seriesVolumeMap(seriesUid);
%				clims = [min(iv.data(:)), max(iv.data(:))];
				[nY,nX,nZ] = size(iv.data);
				ivMask = zeros(nY, nX, nZ);
				contourList = roi.getContourList();
				for j=1:contourList.size()
					contour = contourList.get(j);
					% Assume only ever be one image referenced in a contour.
					contourRef = contour.getImageReferenceList().toArray();
					% Assume single frame images
					ivIdx = find(cellfun(@(c) strcmp(c, contourRef.sopInstanceUid), ...
						iv.sopInstUids));
					points = contour.getContourPointsList();
					mask = poly2mask(points(:,1), points(:,2), nY, nX);
					ivMask(:,:,ivIdx) = mask;
				end
				results = containers.Map('KeyType', 'char', 'ValueType', 'any');
				% First-order stats
				radiomics.AertsStatistics.compute(iv.data, ivMask, results);
				% Shape/Size
				radiomics.AertsShape.compute(iv.data, ivMask, iv.pixelDimensions, ...
					results);
				% Texture
				radiomics.AertsTexture.compute(iv.data, ivMask, results);
				this.outputResults(results);
			end
		end

	end

end

