classdef RoiFuser < handle
	%ROIFUSER Summary of this class goes here
	%   Detailed explanation goes here
	
	%----------------------------------------------------------------------------
	properties(Constant,Access=private)
		logger = ether.log4m.Logger.getLogger('radiomics.RoiFuser');
	end

	properties
	end
	
	%----------------------------------------------------------------------------
	methods
		%-------------------------------------------------------------------------
		function iacList = fuse(this, iaItems, dataSource, projectId)
			iacList = ether.collect.CellArrayList('ether.aim.ImageAnnotationCollection');
			seriesMarkupMap = this.buildSeriesMarkupMap(iaItems);
			nSeries = seriesMarkupMap.length();
			keys = seriesMarkupMap.keys();
			for i=1:nSeries
				seriesUid = keys{i};
				series = this.loadSeries(dataSource, projectId, seriesUid);
				miMap = seriesMarkupMap(seriesUid);
				this.processSeries(series, miMap, iacList);
			end
		end
	end

	%----------------------------------------------------------------------------
	methods(Access=private)
		%-------------------------------------------------------------------------
		function [markupItemList,instSeriesMap] = buildMarkupItemInfo(this, iaItems)
			nIaItems = numel(iaItems);
			markupItemList = ether.collect.CellArrayList('radiomics.MarkupItem');
 			instSeriesMap = containers.Map('KeyType', 'char', ...
 				'ValueType', 'any');
			for i=1:nIaItems
				iaItem = iaItems(i);
				refSeries = iaItem.ia.getAllReferences().imageStudy.imageSeries;
				markups = iaItem.ia.getAllMarkups;
				nMarkups = numel(markups);
				if (nMarkups > 1)
					this.logInfo(@() sprintf('NB: %i markups in annotation!', ...
						nMarkups));
				end
				for j=1:nMarkups
					markup = markups(j);
					if (~isa(markup, 'ether.aim.TwoDimensionPolyline'))
						continue;
					end
					refImageUid = markup.imageReferenceUid;
					seriesUid = '';
					for k=1:numel(refSeries)
						currRefSeries = refSeries(k);
						if (~isempty(currRefSeries.getImage(refImageUid)))
							seriesUid = refSeries.instanceUid;
							break;
						end
					end
					if isempty(seriesUid)
						this.logger.warn(...
							@() sprintf('Bad Markup: %s', markup.uniqueIdentifier));
						continue;
					end
					instSeriesMap(refImageUid) = seriesUid;
					mi = radiomics.MarkupItem(markup, iaItem);
					markupItemList.add(mi);
				end
			end
		end

		%-------------------------------------------------------------------------
		function seriesMarkupMap = buildSeriesMarkupMap(this, iaItems)
			[markupItemList,instSeriesMap] = this.buildMarkupItemInfo(iaItems);

			seriesMarkupMap = containers.Map('KeyType', 'char', 'ValueType', 'any');
			for i=1:markupItemList.size()
				mi = markupItemList.get(i);
				seriesUid = instSeriesMap(mi.markup.imageReferenceUid);
				if ~seriesMarkupMap.isKey(seriesUid)
					miMap = containers.Map('KeyType', 'char', 'ValueType', 'any');
					seriesMarkupMap(seriesUid) = miMap;
				end
				miMap = seriesMarkupMap(seriesUid);
				miMap(mi.markup.uniqueIdentifier) = mi;
			end
		end

		%-------------------------------------------------------------------------
		function seriesUids = buildSeriesUids(~, iaItems)
			nItems = numel(iaItems);
			seriesUids = {};
			for i=1:nItems
				itemUids = iaItems(i).ia.getReferencedSeriesUidList().toCellArray();
				seriesUids = [seriesUids,itemUids];
			end
			seriesUids = unique(seriesUids);
		end

		%-------------------------------------------------------------------------
		function [miArr,ivIdx] = computeImageVolumeIndices(~, miMap, iv)
			miArr = miMap.values;
			uidArr = cellfun(@(mi) mi.imageReferenceUid(), miArr, ...
				'UniformOutput', false);
			ivIdx = cell2mat( ...
				cellfun(@(c) find(strcmp(c, iv.sopInstUids)), uidArr, ...
					'UniformOutput', false));
			[ivIdx,sortedIdx] = sort(ivIdx);
			miArr = [miArr{sortedIdx}];
			[nY,nX,~] = size(iv.data);
			for i=1:numel(miArr)
				miArr(i).ivIdx = ivIdx(i);
				coords = miArr(i).markup.getTwoDCoordinateArray();
				miArr(i).mask = poly2mask(coords(:,1), coords(:,2), nY, nX);
			end
		end

		%-------------------------------------------------------------------------
		function newIac = createIac(this, miMap, series, iaIdx)
			newIac = [];
			nowDt = char(etherj.aim.AimUtils.toDateTime(java.util.Date()));
			miArr = this.getSortedMarkupItems(miMap);
			iac = miArr(1).iaItem.iac;
			jIac = this.createJIac(iac, nowDt);
			ia = miArr(1).iaItem.ia;
			jIa = etherj.aim.ImageAnnotation();
			jIa.setUid(dicomuid());
			jIa.setComment(sprintf('%s / %i / %s / Fused ROI %i', ...
				series.modality, series.number, series.description, iaIdx));
			jIa.setDateTime(nowDt);
			jIa.setName(sprintf('%s_%s_FusedRoi_%i', iac.person.name, ...
				series.date, iaIdx));
			imageRefs = miArr(1).iaItem.ia.getAllReferences();
			% Assume just one image reference
			study = imageRefs(1).imageStudy;
			jImageRef = etherj.aim.DicomImageReference();
			jImageRef.setUid(dicomuid());
			jStudy = this.createJImageStudy(study);
			jImageRef.setStudy(jStudy);
			series = study.imageSeries;
			jSeries = this.createJImageSeries(series);
			jStudy.setSeries(jSeries);
			jIa.addReference(jImageRef);
			for i=1:numel(miArr)
				imageRefs = miArr(i).iaItem.ia.getAllReferences();
				% Assume just one image reference
				images = imageRefs(1).imageStudy.imageSeries.getAllImages();
				% Assume just one image
				image = images(1);
				jImage = this.createJImage(image);
				markup = miArr(i).markup;
				jMarkup = this.createJMarkup(markup);
				if ~isempty(jMarkup)
					jSeries.addImage(jImage);
					jIa.addMarkup(jMarkup);
				end
			end
			if ((jIa.getReferenceCount() > 0) && (jIa.getMarkupCount() > 0))
				jIac.addAnnotation(jIa);
				newIac = ether.aim.ImageAnnotationCollection(jIac);
			end
		end

		%-------------------------------------------------------------------------
		function jEquipment = createJEquipment(~, equipment)
			jEquipment = etherj.aim.Equipment(equipment.manufacturerName, ...
				equipment.manufacturerModelName);
			jEquipment.setDeviceSerialNumber(equipment.deviceSerialNumber);
			jEquipment.setSoftwareVersion(equipment.softwareVersion);
		end

		%-------------------------------------------------------------------------
		function jIac = createJIac(this, iac, nowDt)
			jIac = etherj.aim.ImageAnnotationCollection();
			jIac.setUid(dicomuid());
			jIac.setAimVersion(iac.aimVersion);
			jIac.setDateTime(nowDt);
			jIac.setEquipment(this.createJEquipment(iac.equipment));
			jIac.setPerson(this.createJPerson(iac.person));
			jIac.setUser(this.createJUser(iac.user));
		end

		%-------------------------------------------------------------------------
		function jImage = createJImage(~, image)
			jImage = etherj.aim.Image();
			jImage.setSopInstanceUid(image.sopInstanceUid);
			jImage.setSopClassUid(image.sopClassUid);
		end

		%-------------------------------------------------------------------------
		function jImageSeries = createJImageSeries(~, series)
			jImageSeries = etherj.aim.ImageSeries();
			jImageSeries.setInstanceUid(series.instanceUid);
			modality = series.modality;
			jModality = etherj.aim.Code();
			jModality.setCode(modality.code);
			jModality.setCodeSystem(modality.codeSystem);
			jModality.setCodeSystemName(modality.codeSystemName);
			jModality.setCodeSystemVersion(modality.codeSystemVersion);
			jImageSeries.setModality(jModality);
		end

		%-------------------------------------------------------------------------
		function jImageStudy = createJImageStudy(~, study)
			jImageStudy = etherj.aim.ImageStudy();
			jImageStudy.setInstanceUid(study.instanceUid);
			jImageStudy.setStartDate(study.startDate);
			jImageStudy.setStartTime(study.startTime);
		end

		%-------------------------------------------------------------------------
		function jMarkup = createJMarkup(this, markup)
			jMarkup = [];
			switch (class(markup))
				case 'ether.aim.TwoDimensionPolyline'
					jMarkup = this.createJTwoDimensionPolyline(markup);
			end
		end

		%-------------------------------------------------------------------------
		function jPerson = createJPerson(~, person)
			jPerson = etherj.aim.Person(person.name, person.birthDate, person.id);
			jPerson.setEthnicGroup(person.ethnicGroup);
			jPerson.setSex(person.sex);
		end

		%-------------------------------------------------------------------------
		function jMarkup = createJTwoDimensionPolyline(~, markup)
			jMarkup = etherj.aim.TwoDimensionPolyline();
			jMarkup.setUid(dicomuid());
			jMarkup.setImageReferenceUid(markup.imageReferenceUid);
			jMarkup.setReferencedFrameNumber(markup.referencedFrameNumber);
			jMarkup.setIncludeFlag(markup.includeFlag);
			jMarkup.setDescription(markup.description);
			jMarkup.setLabel(markup.label);
			jMarkup.setLineColour(markup.lineColour);
			jMarkup.setShapeId(markup.shapeIdentifier);
			coords = markup.getTwoDCoordinates();
			for i=1:numel(coords)
				coord = coords(i);
				jCoord = etherj.aim.TwoDimensionCoordinate(coord.index, coord.x, ...
					coord.y);
				jMarkup.addCoordinate(jCoord);
			end
		end

		%-------------------------------------------------------------------------
		function jUser = createJUser(~, user)
			jUser = etherj.aim.User(user.name, user.loginName);
			jUser.setNumberWithinRoleOfClinicalTrial(...
				user.numberWithinRoleOfClinicalTrial);
			jUser.setRoleInTrial(user.roleInTrial);
		end

		%-------------------------------------------------------------------------
		function contigMiMap = getContiguousMarkupItems(this, miMap, iv)
			[nY,nX,nZ] = size(iv.data);
			ivMask = zeros(nY, nX, nZ);
			contigMiMap = containers.Map('KeyType', 'char', 'ValueType', 'any');

			% Markups sorted into ascending order by referenced slice index
			miArr = this.getSortedMarkupItems(miMap);
			% Seed markup is first in array, testing subsequent markups should
			% quickly build up a set of contiguous markups. Testing both previous
			% and next slices allows U-shaped ROIs to be built. Testing next
			% slices is much less efficient than previous slices as probably only
			% one next slice markup will be added for each forward pass through the
			% sorted markups.
			seedMi = miArr(1);
			seedUid = seedMi.markup.uniqueIdentifier;
			contigMiMap(seedUid) = seedMi;
			miMap.remove(seedUid);
			ivMask(:,:,seedMi.ivIdx) = seedMi.mask;
			this.logger.info(@() sprintf('Seed markup: slice %i, %s', ...
				seedMi.ivIdx, seedUid));

			% Adding seed counts as in increment to get into the while loop
			nIncr = 1;
			% Loop until no more markups are added to contiguous map or there are
			% no more markups
			while ((nIncr > 0) && (miMap.length() > 0))
				this.logger.info('Contiguity test loop start...');
				nIncr = 0;
				miArr = this.getSortedMarkupItems(miMap);
				for i=1:numel(miArr)
					mi = miArr(i);
					% Test contiguity with previous slice's mask. ROI can grow
					% downwards
					if (mi.ivIdx > 1)
						testMask = ivMask(:,:,mi.ivIdx-1);
						if (any(testMask(:) & mi.mask(:)))
							% Update the volume mask and move the markup from the main
							% map to the contiguous map
							ivMask(:,:,mi.ivIdx) = mi.mask;
							miUid = mi.markup.uniqueIdentifier;
							contigMiMap(miUid) = mi;
							miMap.remove(miUid);
							nIncr = nIncr+1;
							this.logger.info(@() ...
								sprintf('Markup added downward: slice %i, %s', ...
								mi.ivIdx, miUid'));
							% Skip the next slice test, markup already added
							continue;
						end
					end
					% Test contiguity with next slice's mask. ROI can grow upwards
					if (mi.ivIdx < nZ)
						testMask = ivMask(:,:,mi.ivIdx+1);
						if (any(testMask(:) & mi.mask(:)))
							% Update the volume mask and move the markup from the main
							% map to the contiguous map
							ivMask(:,:,mi.ivIdx) = mi.mask;
							miUid = mi.markup.uniqueIdentifier;
							contigMiMap(miUid) = mi;
							miMap.remove(miUid);
							nIncr = nIncr+1;
							this.logger.info(@() ...
								sprintf('Markup added upward: slice %i, %s', ...
								mi.ivIdx, miUid'));
						end
					end
				end
			end
			this.logger.info(@() ...
				sprintf('Contiguity test loop finished. %i markups remain', ...
				miMap.length()));
		end

		%-------------------------------------------------------------------------
		function miArr = getSortedMarkupItems(~, miMap)
			miArr = miMap.values;
			miArr = [miArr{:}];
			[~,sortedIdx] = sort([miArr.ivIdx]);
			miArr = miArr(sortedIdx);
		end

		%-------------------------------------------------------------------------
		function series = loadSeries(this, dataSource, projectId, uid)
			series = dataSource.getImageSeries(projectId, ...
				uid, radiomics.DataSource.Series);
			if ~isempty(series)
				this.logger.info(@() sprintf('Series: %d - %s (%s)', series.number, ...
					series.description, series.instanceUid));
			else
				this.logger.info(@() sprintf('Series not found: UID - %s', uid));
			end
		end

		%-------------------------------------------------------------------------
		function processSeries(this, series, miMap, iacList)
			this.logger.info(@() sprintf('Processing series %i - %s', ...
				series.number, series.description));
			iv = radiomics.ImageVolume(series);
			this.computeImageVolumeIndices(miMap, iv);

			i = 0;
			while (miMap.length() > 0)
				contigMiMap = this.getContiguousMarkupItems(miMap, iv);
				i = i+1;
				iac = this.createIac(contigMiMap, series, i);
				if (~isempty(iac))
					iacList.add(iac);
					this.logger.info(...
						@() sprintf('IAC built: %i, %i markups remaining', ...
							i, miMap.length()));
				else
					this.logger.warn(...
						@() sprintf('IAC EMPTY!: %i, %i markups unprocessed', ...
							i, miMap.length()));
					break;
				end
			end
		end

	end

end

