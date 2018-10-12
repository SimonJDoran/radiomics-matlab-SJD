classdef TextureAnalyser3D < radiomics.TextureAnalyser
	%TEXTUREANALYSER2D Summary of this class goes here
	%   Detailed explanation goes here

	%----------------------------------------------------------------------------
	properties(Constant,Access=private)
		logger = ether.log4m.Logger.getLogger('radiomics.TextureAnalyser3D');
	end

	%----------------------------------------------------------------------------
	properties(Access=private)
		refSeriesMap = [];
		seriesVolumeMap = [];
		instSeriesMap = [];
	end

	%----------------------------------------------------------------------------
	methods
		%-------------------------------------------------------------------------
		function resultList = analyse(this, radItems, dataSource, projectId)
			resultList = ether.collect.CellArrayList('radiomics.TextureResult');

			this.logger.info(@() sprintf('Fetching referenced series'));
			nRadItems = numel(radItems);
			this.buildRefSeriesMap(radItems, dataSource, projectId);
			for i=1:nRadItems
				this.logger.info(@() sprintf('Processing annotation (%d of %d)', ...
					i, nRadItems));
            cellRadItem = radItems(i);
				radItem = cellRadItem{1};
            
            if isa(radItem, 'radiomics.IaItem')
               this.processIaItem(radItem, resultList);
            end
            if isa(radItem, 'radiomics.RtRoiItem')
               this.processRtRoiItem(radItem, resultList);
            end
			end
		end
	
	end

	%----------------------------------------------------------------------------
	methods(Access=private)
		%-------------------------------------------------------------------------
		function buildRefSeriesMap(this, radItems, dataSource, projectId)
			import radiomics.*;
			this.refSeriesMap = containers.Map('KeyType', 'char', ...
				'ValueType', 'any');
			this.seriesVolumeMap = containers.Map('KeyType', 'char', ...
				'ValueType', 'any');
			this.instSeriesMap = containers.Map('KeyType', 'char', ...
				'ValueType', 'any');
			this.logger.info(@() sprintf('Fetching referenced series'));
			nItems = numel(radItems);
			for i=1:nItems
            cellRadItem = radItems(i);
				radItem = cellRadItem{1};
            
            if isa(radItem, 'radiomics.IaItem')
               refSeriesUidList = radItem.ia.getReferencedSeriesUidList();
            elseif isa(radItem, 'radiomics.RtRoiItem')
               refSeriesUidList = radItem.rtRoi.getReferencedSeriesUidList();
            else return
            end
            for j=1:refSeriesUidList.size()
               refSeriesUid = refSeriesUidList.get(j);
               if this.refSeriesMap.isKey(refSeriesUid)
                  continue;
               end
               series = dataSource.getImageSeries(projectId, ...
                  refSeriesUid, DataSource.Series);
               if ~isempty(series)
                  this.insertSeries(series);
                  this.logger.info(@() sprintf('Series: %d - %s (%s)', series.number, ...
                     series.description, series.instanceUid));
               else
                  this.logger.info(@() sprintf('Series not found: UID - %s', ...
                     refSeriesUid));
               end
            end
               
			end
			this.logger.info(@() sprintf('%d referenced series loaded', ...
				this.refSeriesMap.length()));
		end

		%-------------------------------------------------------------------------
		function iv = iaCreateImageVolume(this, ia)
			iv = [];
			iaImageRefs = ia.getAllReferences();
			if ~this.loadImageReferences(iaImageRefs)
				return;
			end
			if (numel(iaImageRefs) > 1)
				% volume spans series
				throw(MException('radiomics:TextureAnalyzer3D', 'Multiseries volume detected'));
			end
			images = iaImageRefs.imageStudy.imageSeries.getAllImages;
			seriesUids = arrayfun(@(c) this.instSeriesMap(c.sopInstanceUid), images, ...
				'UniformOutput', false);
			seriesUids = unique(seriesUids);
			nSeries = numel(seriesUids);
			if (nSeries == 1)
				iv = this.seriesVolumeMap(seriesUids{1});
				return;
			end
			% volume spans series
			throw(MException('radiomics:TextureAnalyzer3D', 'Multiseries volume detected'));
		end

		%-------------------------------------------------------------------------
		function iv = rtRoiCreateImageVolume(this, rtRoi)
			iv = [];
         seriesUids = rtRoi.getReferencedSeriesUidList();
         if (seriesUids.size() > 1)
				% volume spans series
				throw(MException('radiomics:TextureAnalyzer3D', 'Multiseries volume detected'));
         end
         iv = this.seriesVolumeMap(seriesUids.get(1));
      end
      
      %-------------------------------------------------------------------------
		function ivMask = iaCreateVolumeMask(this, iv, ia)
			if isempty(iv)
				throw(MException('Radiomics:MainUi', ...
					'ImageVolume not found'));
			end
			[nY,nX,nZ] = size(iv.data);
			ivMask = zeros(nY, nX, nZ, 'logical');
			markups = ia.getAllMarkups();
			for n=1:numel(markups)
				markup = markups(n);
				% Assume single frame images
				ivIdx = find(cellfun(@(c) strcmp(c, markup.imageReferenceUid), ...
					iv.sopInstUids));
				points = markup.getTwoDCoordinateArray();
				% Shift to 1-based coords
				points = points+1;
				mask = poly2mask(points(:,1), points(:,2), nY, nX);
				ivMask(:,:,ivIdx) = mask;
         end
         if ~any(ivMask(:))
				throw(MException('Radiomics:MainUi', ...
               'Mask volume contains zero pixels'));
			end
		end

      
      %-------------------------------------------------------------------------
		function ivMask = rtRoiCreateVolumeMask(this, iv, rtRoi)
			if isempty(iv)
				throw(MException('Radiomics:MainUi', ...
					'ImageVolume not found'));
			end
			[nY,nX,nZ] = size(iv.data);
			ivMask = zeros(nY, nX, nZ, 'logical');
			
         cl = rtRoi.getContourList();
         for i=1:cl.size()
            contour = cl.get(i);
            refList = contour.getImageReferenceList();
            if (numel(refList) ~= 1)
               throw(MException('Radiomics:MainUi', ...
					'Contour spans more than one image slice.'));
            end
            points = contour.getContourPointsList();
            % Shift to 1-based coords
				points = points+1;
				mask = poly2mask(points(:,1), points(:,2), nY, nX);
            
            % Find the position in the array where this goes.
            sopInstUid = refList.get(1).sopInstanceUid;
            ivIdx = find(cellfun(@(c) strcmp(c, sopInstUid), ...
					iv.sopInstUids));
            ivMask(:,:,ivIdx) = mask;
         end
         if ~any(ivMask(:))
				throw(MException('Radiomics:MainUi', ...
               'Mask volume contains zero pixels'));           
         end
            
		end

		%-------------------------------------------------------------------------
		function seriesUid = getReferencedSeriesUid(this, roi)
			seriesUid = [];
			roiImageRefs = roi.getImageReferenceList();
			if ~this.loadImageReferences(roiImageRefs)
				return;
			end
			seriesUid = this.instSeriesMap(roiImageRefs.get(1).sopInstanceUid);
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
		function bool = loadImageReferences(this, imageRefs)
			import radiomics.*;
			bool = false;
			for i=1:numel(imageRefs)
				if ~this.refSeriesMap.isKey(...
						imageRefs(i).imageStudy.imageSeries.instanceUid)
					return;
				end
			end
			bool = true;
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
		function processIaItem(this, iaItem, resultList)
			ia = iaItem.ia;
			this.logger.info(@() sprintf('Processing Patient %s, ImageAnnotation: %s', ...
				iaItem.iac.person.name, ia.name));
			iv = this.iaCreateImageVolume(ia);
			try
				ivMask = this.iaCreateVolumeMask(iv, ia);
				% Native pixels
				results = containers.Map('KeyType', 'char', 'ValueType', 'any');
				radiomics.AertsStatistics.compute(iv.data, ivMask, results);
				radiomics.AertsShape.compute(ivMask, iv.pixelDimensions, results);
				radiomics.AertsTexture.compute(iv.data, ivMask, results);

				% Wavelet decompositions
				this.processWavelet(iv.data, ivMask, results);

				resultList.add(radiomics.TextureResult(results, iaItem));
			catch ex
				this.logger.warn(...
					@() sprintf('ERROR: Processing ImageAnnotation failed: %s - %s', ...
						ia.name, ex.message));
				this.logger.warn(...
					@() sprintf('ERROR in IAC UID: %s', iaItem.iac.uniqueIdentifier));
			end
		end

		%-------------------------------------------------------------------------
		function processRtRoiItem(this, rtRoiItem, resultList)
			rtRoi = rtRoiItem.rtRoi;
			this.logger.info(@() sprintf('Processing Patient %s, RT-STRUCT: %s', ...
				rtRoi.getPatientName(), rtRoi.name));
			iv = this.rtRoiCreateImageVolume(rtRoi);
			try
				ivMask = this.rtRoiCreateVolumeMask(iv, rtRoi);
				% Native pixels
				results = containers.Map('KeyType', 'char', 'ValueType', 'any');
				radiomics.AertsStatistics.compute(iv.data, ivMask, results);
				radiomics.AertsShape.compute(ivMask, iv.pixelDimensions, results);
				radiomics.AertsTexture.compute(iv.data, ivMask, results);

				% Wavelet decompositions
				this.processWavelet(iv.data, ivMask, results);

				resultList.add(radiomics.TextureResult(results, rtRoiItem));
			catch ex
				this.logger.warn(...
					@() sprintf('ERROR: Processing ROI failed: %s - %s', ...
						rtRoi.name, ex.message));
				this.logger.warn(...
					@() sprintf('ERROR in RT-STRUCT UID: %s', rtRoiIte.dateTime));
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

