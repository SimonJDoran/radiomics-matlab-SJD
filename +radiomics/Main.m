classdef Main < handle
	%MAIN Summary of this class goes here
	%   Detailed explanation goes here
	
	%----------------------------------------------------------------------------
	properties(Constant,Access=private)
		logger = ether.log4m.Logger.getLogger('radiomics.Main');
	end

	%----------------------------------------------------------------------------
	properties(SetAccess=private)
		dataSource = [];
	end

	%----------------------------------------------------------------------------
	properties(Access=private)
		aimStudyUid = '1.2.840.113564.9.1.2728161578.69.2.5000228280';
%		aimStudyUid = '1.2.840.113564.9.1.2728161578.69.2.5000194425';
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

	%----------------------------------------------------------------------------
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

	%----------------------------------------------------------------------------
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
		function iv = createImageVolume(this, roi)
			roiImageRefs = roi.getImageReferenceList();
			this.loadImageReferences(roiImageRefs);
			seriesUid = this.instSeriesMap(roiImageRefs.get(1).sopInstanceUid);
			iv = this.seriesVolumeMap(seriesUid);
		end

		%-------------------------------------------------------------------------
		function ivMask = createVolumeMask(~, iv, roi)
			[nY,nX,nZ] = size(iv.data);
			ivMask = zeros(nY, nX, nZ);
			contourList = roi.getContourList();
			for n=1:contourList.size()
				contour = contourList.get(n);
				% Assume only ever be one image referenced in a contour.
				contourRef = contour.getImageReferenceList().toArray();
				% Assume single frame images
				ivIdx = find(cellfun(@(c) strcmp(c, contourRef.sopInstanceUid), ...
					iv.sopInstUids));
				points = contour.getContourPointsList();
				mask = poly2mask(points(:,1), points(:,2), nY, nX);
				ivMask(:,:,ivIdx) = mask;
			end
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
		function outputResults(~, results)
			import radiomics.*;
			metrics = Aerts.getMetrics();
			prefix = {'', 'LLL.', 'LLH.', 'LHL.', 'LHH.', 'HLL.', 'HLH.', 'HHL.', 'HHH.'};
			for j=1:numel(prefix)
				for i=1:metrics.size()
					name = [prefix{j},metrics.get(i)];
					if ~results.isKey(name)
						continue;
					end
					fprintf('%s: %f\n', name, results(name));
				end
			end
		end

		%-------------------------------------------------------------------------
		function decompResults = processDecomp(~, decomp, mask, prefix)
			results = containers.Map('KeyType', 'char', 'ValueType', 'any');
			% First-order stats
			radiomics.AertsStatistics.compute(decomp, mask, results);
			% Texture
			radiomics.AertsTexture.compute(decomp, mask, results);
			% Pack them with the prefix
			decompResults = containers.Map('KeyType', 'char', 'ValueType', 'any');
			keys = results.keys();
			for i=1:numel(keys)
				decompResults([prefix,'.',keys{i}]) = results(keys{i});
			end
		end

		%-------------------------------------------------------------------------
		function processRtStruct(this, rtStruct)
			this.logger.info(@() sprintf('Processing RtStruct: %s', ...
				rtStruct.label));
			roiList = rtStruct.getRoiList();
			nRoi = roiList.size();
			for m=1:nRoi
				roi = roiList.get(m);
				this.logger.info(@() sprintf('Processing RtRoi: %s (%d of %d)', ...
					roi.name, m, nRoi));
				iv = this.createImageVolume(roi);
				ivMask = this.createVolumeMask(iv, roi);

				% Native pixels
				results = containers.Map('KeyType', 'char', 'ValueType', 'any');
				radiomics.AertsStatistics.compute(iv.data, ivMask, results);
				radiomics.AertsShape.compute(ivMask, iv.pixelDimensions, results);
				radiomics.AertsTexture.compute(iv.data, ivMask, results);

				% Wavelet decompositions
				this.processWavelet(iv.data, ivMask, results);

				this.outputResults(results);
			end
		end

		%-------------------------------------------------------------------------
		function results = processWavelet(this, data, mask, results)
			transform = radiomics.Wavelet.dwt3u(data, 'coif1', 'mode', 'zpd');
			dirString = {'L','H'};
			for i=1:2
				for j=1:2
					for k=1:2
						prefix = [dirString{i},dirString{j},dirString{k}];
						this.logger.info(...
							@() sprintf('Processing wavelet decomposition: %s', prefix));
						dirResults = this.processDecomp(transform.dec{i,j,k}, ...
							mask, prefix);
						dirKeys = dirResults.keys();
						for m=1:numel(dirKeys)
							results(dirKeys{m}) = dirResults(dirKeys{m});
						end
					end
				end
			end
		end

	end

end

