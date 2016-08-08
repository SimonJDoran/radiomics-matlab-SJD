classdef MainUi < ether.app.AbstractGuiApplication
	%MAINUI Summary of this class goes here
	%   Detailed explanation goes here
	
	%----------------------------------------------------------------------------
	properties(Constant,Access=private)
		logger = ether.log4m.Logger.getLogger('radiomics.Main');
	end

	%----------------------------------------------------------------------------
	properties(SetAccess=private)
		dataSource = [];
		useXnat = false;
	end

	%----------------------------------------------------------------------------
	properties(Access=private)
		dirButton;
		dirText;
		exitItem;
		importAimItem;
		importDicomItem;
		jOutputText;
		lesionEdit;
		nLogLines = 0;
		outputLog = {};
		outputPanel;
		outputText;
		patientEdit;
		processButton;
		scanList;
		searchButton;
		searchPanel;
		table;
		tableSelection = {};
		targetPath = '';
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
		function this = MainUi(useXnat)
			if (numel(useXnat) == 1) && islogical(useXnat)
				this.useXnat = useXnat;
			end
			if this.useXnat
				this.dataSource = radiomics.XnatDataSource();
			else
				this.dataSource = radiomics.DbDataSource();
			end
		end

		%-------------------------------------------------------------------------
		function run(this)
			import radiomics.*;
			this.productName = 'RadiomicsUI';
			this.productTag = 'radiomicsui';
			run@ether.app.AbstractGuiApplication(this);
		end

	end

	%----------------------------------------------------------------------------
	methods(Access=protected)
		%-------------------------------------------------------------------------
		function initComponents(this)
			this.initMenuBar();
			this.frame.OuterPosition = [0 40 1280 960];
 			this.frame.Visible = 'on';
			gap = 2;
			xPad = gap;
			yPad = gap;

			this.initSearchPanel(xPad, yPad, gap);
			this.initTable(xPad, yPad, gap);
			this.initOutputPanel(xPad, yPad, gap);

 			movegui(this.frame, 'center');
		end

		%-------------------------------------------------------------------------
		function onEvent(this, ~, ~)
			this.logger.debug(@() sprintf('Unhandled event'));
		end

 		%-------------------------------------------------------------------------
 		function onMenuEvent(this, ~, ~)
			this.logger.debug(@() sprintf('Unhandled menu event'));
 		end
 	end

	%----------------------------------------------------------------------------
	methods(Access=private)
		%-------------------------------------------------------------------------
		function value = enableStr(~, bool)
			value = 'off';
			if (bool)
				value = 'on';
			end
		end

		%-------------------------------------------------------------------------
		function initMenuBar(this)
			fileMenu = uimenu(this.frame, 'Label', '&File');
			if ~this.useXnat
				this.importAimItem = uimenu(fileMenu, 'Label', 'Import &AIM...', ...
					'Accelerator', 'A', 'Callback', @this.onImportAim);
				this.importDicomItem = uimenu(fileMenu, 'Label', 'Import &DICOM...', ...
					'Accelerator', 'D', 'Callback', @this.onImportDicom);
			end
			this.exitItem = uimenu(fileMenu, 'Label', 'E&xit', 'Separator', 'on', ...
				'Callback', @this.onExit);
		end

		%-------------------------------------------------------------------------
		function initOutputPanel(this, xPad, yPad, gap)
			frPos = this.frame.Position;
			frameW = frPos(3);
			buttonW = 60; % Guess, works on Windows 7

			this.outputPanel = uipanel(this.frame);
			this.outputPanel.Title = 'Output';
			this.outputPanel.Units = 'pixels';
			labelStrip = uipanel(this.outputPanel);
  			labelStrip.BorderType = 'none';
 			labelStrip.Units = 'pixels';
 			dirLabel = uicontrol(labelStrip, 'Style', 'text');
			dirLabel.String = 'Directory';
			dirLabel.HorizontalAlignment = 'left';
			outputStrip = uipanel(this.outputPanel);
			outputStrip.BorderType = 'none';
			outputStrip.Units = 'pixels';
			this.dirText = uicontrol(outputStrip, 'Style', 'edit');
			this.dirText.HorizontalAlignment = 'left';
			this.dirText.Enable = 'inactive';
			this.dirButton = uicontrol(outputStrip, 'Style', 'pushbutton', ...
				'String', 'Output...');
			this.dirButton.Callback = @this.onOutputDir;
			this.outputText = uicontrol(this.outputPanel, 'Style', 'edit');
			this.outputText.HorizontalAlignment = 'left';
			this.outputText.Enable = 'inactive';
			% Force the outputText's underlying Java object to be multiline.
			% MATLAB changes the Java object depending if single or multiline.
			this.outputText.Max = 2;

			% Position everything
			tableBottom = this.table.Position(2);
			labelH = dirLabel.Position(4);
			editW = this.dirText.Position(3);
			editH = this.dirText.Position(4)+yPad;
			titleH = dirLabel.Extent(4);
			outputW = frameW-xPad;
			outputH = tableBottom-gap;
			outputTextH = floor(outputH-(labelH+2*yPad+editH+2*yPad+gap+titleH/2));
			% Account for title extending outside searchPanel
			this.outputPanel.Position = [xPad yPad outputW outputH];
			labelStrip.Position = [xPad yPad+outputTextH+editH outputW-xPad labelH+2*yPad];
			dirLabel.Position = [xPad 0 editW labelH];
			outputStrip.Position = [xPad yPad+outputTextH outputW-xPad editH+2*yPad];
			this.dirText.Position = [xPad yPad 2*outputW/3 editH];
			x = xPad+2*outputW/3+gap;
			this.dirButton.Position = [x yPad buttonW editH];
			this.outputText.Position = [xPad yPad outputW-2*xPad outputTextH];

			% Grab the Java object for the text object. Method findjobj is BSD
			% licensed.
			jUiScrollPane = findjobj(this.outputText);
			this.jOutputText = jUiScrollPane.getComponent(0).getComponent(0);
		end

		%-------------------------------------------------------------------------
		function initSearchPanel(this, xPad, yPad, gap)
			frPos = this.frame.Position;
			frameW = frPos(3);
			frameH = frPos(4);
			editW = 128;
			buttonW = 60; % Guess, works on Windows 7

			this.searchPanel = uipanel(this.frame);
			this.searchPanel.Title = 'Search';
			this.searchPanel.Units = 'pixels';
			labelStrip = uipanel(this.searchPanel);
  			labelStrip.BorderType = 'none';
 			labelStrip.Units = 'pixels';
 			patLabel = uicontrol(labelStrip, 'Style', 'text');
			patLabel.String = 'Patient';
			patLabel.HorizontalAlignment = 'left';
 			lesionLabel = uicontrol(labelStrip, 'Style', 'text');
			lesionLabel.String = 'Lesion';
			lesionLabel.HorizontalAlignment = 'left';
 			scanLabel = uicontrol(labelStrip, 'Style', 'text');
			scanLabel.String = 'Scan';
			scanLabel.HorizontalAlignment = 'left';
			searchStrip = uipanel(this.searchPanel);
			searchStrip.BorderType = 'none';
			searchStrip.Units = 'pixels';
			this.patientEdit = uicontrol(searchStrip, 'Style', 'edit');
			this.patientEdit.HorizontalAlignment = 'left';
			this.lesionEdit = uicontrol(searchStrip, 'Style', 'edit');
			this.lesionEdit.HorizontalAlignment = 'left';
			this.scanList = uicontrol(searchStrip, 'Style', 'popup', ...
				'String', {'','A','B'});
			this.searchButton = uicontrol(searchStrip, 'Style', 'pushbutton', ...
				'String', 'Search');
			this.searchButton.Callback = @this.onSearch;
			this.processButton = uicontrol(searchStrip, 'Style', 'pushbutton', ...
				'String', 'Process');
			this.processButton.Callback = @this.onProcess;
			this.processButton.Enable = 'off';

			% Position everything
			labelH = patLabel.Position(4);
			scanH = this.scanList.Position(4)+yPad;
			titleH = patLabel.Extent(4);
			searchW = frameW-xPad;
			searchH = ceil(titleH+labelH+scanH+4*yPad);
			% Account for title extending outside searchPanel
			this.searchPanel.Position = ...
				[xPad frameH-(3*titleH/2+searchH+yPad) searchW searchH];
			labelStrip.Position = [xPad yPad+scanH searchW-xPad labelH+2*yPad];
			searchStrip.Position = [xPad yPad searchW-xPad scanH+2*yPad];
			patLabel.Position = [xPad 0 editW labelH];
			this.patientEdit.Position = [xPad yPad editW scanH];
			x = xPad+editW+gap;
			lesionLabel.Position = [x 0 editW labelH];
			this.lesionEdit.Position = [x yPad editW scanH];
			x = x+editW+gap;
			scanLabel.Position = [x 0 buttonW labelH];
			this.scanList.Position = [x yPad buttonW scanH];
			x = x+buttonW+gap;
			this.searchButton.Position = [x yPad buttonW scanH];
			x = x+buttonW+gap;
			this.processButton.Position = [x yPad buttonW scanH];
		end

		%-------------------------------------------------------------------------
		function initTable(this, xPad, yPad, gap)
			frPos = this.frame.Position;
			frameW = frPos(3);
			this.table = uitable(this.frame);
			this.table.CellSelectionCallback = @this.onCellSelection;
			this.table.ColumnName = ...
				{'Person Name','Person ID','Date/Time','Scan','Lesion','ROI'};
			this.table.ColumnWidth = ...
				{200,150,150,'auto','auto','auto'};
			this.table.RowStriping = 'on';

			% Position everything
			tableH = 500;
			searchBottom = this.searchPanel.Position(2);
			this.table.Position = [xPad searchBottom-(gap+tableH) frameW-xPad tableH];
		end

		%-------------------------------------------------------------------------
		function onCellSelection(this, ~, event)
			this.tableSelection = event.Indices;
			enable = this.enableStr(~isempty(this.tableSelection));
			this.processButton.Enable = enable;
		end

		%-------------------------------------------------------------------------
		function onExit(this, ~, ~)
			close(this.frame);
			this.delete();
		end

		%-------------------------------------------------------------------------
		function onImportAim(this, ~, ~)
			import ether.dicom.io.*;
			title = 'Import AIM Files';
			path = uigetdir('', title);
			if ~isa(path, 'char')
				return;
			end
			this.dataSource.importAim(path);
		end

		%-------------------------------------------------------------------------
		function onImportDicom(this, ~, ~)
			import ether.dicom.io.*;
			title = 'Import DICOM Files';
			path = uigetdir('', title);
			if ~isa(path, 'char')
				return;
			end
			this.dataSource.importDicom(path);
		end

		%-------------------------------------------------------------------------
		function onOutputDir(this, ~, ~)
			this.selectTargetPath();
		end

		%-------------------------------------------------------------------------
		function onProcess(this, ~, ~)
			rowIdx = unique(this.tableSelection(:,1));
			nRows = length(rowIdx);
			iaItemList = this.table.UserData;
			if iaItemList.size() < 1
				return;
			end
			if isempty(this.targetPath)
				this.selectTargetPath();
				if isempty(this.targetPath)
					return;
				end
			end
			this.logInfo(@() sprintf('Processing %d ROIs...', nRows));
			this.logInfo(@() sprintf('Fetching RT-STRUCTs'));
			rtStructList = ether.collect.CellArrayList('ether.dicom.RtStruct');
			iaList = ether.collect.CellArrayList('ether.aim.ImageAnnotation');
			markupList = ether.collect.CellArrayList('ether.aim.Markup');
			for i=1:nRows
				iaItem = iaItemList.get(rowIdx(i));
				iaList.add(iaItem.ia);
				% Only deal with one markup per annotation for now
				markups = iaItem.ia.getAllMarkups;
				rtStruct = this.dataSource.getRtStructForMarkup(...
					markups(1).uniqueIdentifier);
				if isempty(rtStruct)
					this.logWarn(@() sprintf('No RT-STRUCT found for Markup UID: %s', ...
						markups(1).uniqueIdentifier));
					continue;
				end
				rtStructList.add(rtStruct);
				markupList.add(markups(1));
			end
			if rtStructList.isEmpty()
				message = sprintf('No RT-STRUCTs found');
				this.logWarn(message);
				msgbox(message, 'Process', 'warn', 'modal');
				return;
			end
			this.buildRefSeriesMap(rtStructList);
			for i=1:rtStructList.size()
				rtStruct = rtStructList.get(i);
				ia = iaList.get(i);
				markup = markupList.get(i);
				this.processRtStruct(rtStruct, ia, markup);
			end
		end

		%-------------------------------------------------------------------------
		function onSearch(this, ~, ~)
			this.table.UserData = [];
			this.table.Data = [];
			drawnow();
			this.processButton.Enable = this.enableStr(false);
			patStr = get(this.patientEdit, 'String');
%			lesionStr = get(this.lesionEdit, 'String');
% 			scanItems = get(this.scanList, 'String');
% 			scanIdx = get(this.scanList, 'Value');
%			scanStr = scanItems{scanIdx};
			this.logInfo(@() sprintf('Searching for patients like "%s"...', patStr));
			iacList = this.dataSource.searchIac(patStr);
			if iacList.size() == 0
				message = sprintf('No results for: %s', patStr);
				this.logInfo(message);
				msgbox(message, 'Search', 'warn', 'modal');
				return;
			end

			iaItemList = ether.collect.CellArrayList('radiomics.IaItem');
			for i=1:iacList.size()
				iac = iacList.get(i);
				iaArr = iac.getAllAnnotations();
				for j=1:length(iaArr)
					iaItem = radiomics.IaItem(iaArr(j), iac);
					iaItemList.add(iaItem);
				end
			end
			% ToDo: Filter the iaItemList for lesion and scan matches
			this.table.UserData = iaItemList;
			nCols = 6;
			data = cell(iaItemList.size(), nCols);
			items = this.sortIaItemsArray(iaItemList.toArray());
			for i=1:iaItemList.size()
				item = items(i);
				data{i,1} = item.personName;
				data{i,2} = item.personId;
				data{i,3} = item.ia.dateTime;
				data{i,4} = item.scan;
				data{i,5} = item.lesionNumber;
				data{i,6} = item.roiNumber;
			end
			this.table.Data = data;
			this.logInfo(@() sprintf('Search complete'));
		end

		%-------------------------------------------------------------------------
		function selectTargetPath(this)
			path = uigetdir(this.targetPath, 'Select results directory');
			if isempty(path)
				return;
			end
			this.targetPath = [path,filesep()];
			this.dirText.String = this.targetPath;
			this.logInfo(@() ['Results directory set to: ',this.targetPath]);
			drawnow();
		end

		%-------------------------------------------------------------------------
		function items = sortIaItemsArray(~, items)
			% Sort into name order
			names = arrayfun(@(item) item.personName, items, 'UniformOutput', false);
			dateTimes = arrayfun(@(item) item.ia.dateTime, items, 'UniformOutput', false);
			[names,idx] = sort(names);
			dateTimes = dateTimes(idx);
			items = items(idx);
			% Convert dateTimes to uint64
			dates = cellfun(@(dt) etherj.aim.AimUtils.parseDateTime(dt), dateTimes, 'UniformOutput', false);
			dateTimes = cellfun(@(dt) dt.getTime(), dates);
			% Sort each name clump by dateTime
			uniqueNames = unique(names);
			startIdx = 1;
			for i=1:numel(uniqueNames)
				nameIdx = strcmp(names, uniqueNames{i});
				[~,dtIdx] = sort(dateTimes(nameIdx));
				nCurrItems = numel(dtIdx);
				currItems = items(startIdx:startIdx+nCurrItems-1);
				items(startIdx:startIdx+nCurrItems-1) = currItems(dtIdx);
				startIdx = startIdx+nCurrItems;
			end
		end

		%-------------------------------------------------------------------------
		function buildRefSeriesMap(this, rtStructList)
			import radiomics.*;
			this.refSeriesMap = containers.Map('KeyType', 'char', 'ValueType', 'any');
			this.seriesVolumeMap = containers.Map('KeyType', 'char', 'ValueType', 'any');
			this.instSeriesMap = containers.Map('KeyType', 'char', 'ValueType', 'any');
			this.logInfo(@() sprintf('Fetching referenced series'));
			nRtStruct = rtStructList.size();
			for i=1:nRtStruct
				rtStruct = rtStructList.get(i);
				refSeriesUidList = rtStruct.getReferencedSeriesUidList();
				for j=1:refSeriesUidList.size()
					refSeriesUid = refSeriesUidList.get(j);
					series = this.dataSource.getImageSeries(refSeriesUid, ...
						DataSource.Series);
					this.insertSeries(series);
					this.logInfo(@() sprintf('Series: %d - %s', series.number, ...
						series.description));
				end
			end
			this.logInfo(@() sprintf('%d referenced series loaded', ...
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
				% Points must be image (x,y) coordinates not patient (x,y,z)
				% coordinates
				image = iv.images(ivIdx);
 				pos = image.imagePosition;
				row = image.imageOrientation(4:6);
				col = image.imageOrientation(1:3);
				pixDims = image.pixelSpacing;
				points2D = points(:,1:2);
				for i=1:contour.numberOfContourPoints
					points2D(i,1:2) = etherj.dicom.DicomUtils.patientCoordToImageCoord(...
						points(i,:), pos, row, col, pixDims);
				end
				mask = poly2mask(points2D(:,1), points2D(:,2), nY, nX);
				if ~any(mask)
					throw(MException('Radiomics:MainUi', ...
						'Contour encloses zero pixels'));
				end
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
		function outputResults(this, rtStruct, results, ia, markup)
			import radiomics.*;
			patDir = [this.targetPath,rtStruct.patientName,filesep()];
			if (exist(patDir, 'dir') == 0)
				mkdir(patDir);
			end
			dt = strjoin(strsplit(ia.dateTime, ':'), '-');
			fileName = [patDir,'AertsResults_',dt,'_',markup.uniqueIdentifier,'.txt'];
			this.logInfo(['Writing results to: ',fileName]);
			fileId = fopen(fileName, 'w');
			fprintf(fileId, 'PatientName: %s\n', rtStruct.patientName);
			fprintf(fileId, 'LesionName: %s\n', rtStruct.name);
			fprintf(fileId, 'MarkupUid: %s\n', markup.uniqueIdentifier);
			metrics = Aerts.getMetrics();
			prefix = {'', 'LLL.', 'LLH.', 'LHL.', 'LHH.', 'HLL.', 'HLH.', 'HHL.', 'HHH.'};
			for j=1:numel(prefix)
				for i=1:metrics.size()
					name = [prefix{j},metrics.get(i)];
					if ~results.isKey(name)
						continue;
					end
					fprintf(fileId, '%s: %f\n', name, results(name));
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
		function processRtStruct(this, rtStruct, ia, markup)
			this.logInfo(@() sprintf('Processing RtStruct: %s', ...
				rtStruct.name));
			roiList = rtStruct.getRoiList();
			nRoi = roiList.size();
			for m=1:nRoi
				roi = roiList.get(m);
				this.logInfo(@() sprintf('Processing RtRoi: %s (%d of %d)', ...
					roi.name, m, nRoi));
				iv = this.createImageVolume(roi);
				try
					ivMask = this.createVolumeMask(iv, roi);
				catch ex
					this.logWarn(['Processing RtRoi failed: ',ex.message]);
					continue;
				end

				% Native pixels
				results = containers.Map('KeyType', 'char', 'ValueType', 'any');
				radiomics.AertsStatistics.compute(iv.data, ivMask, results);
				radiomics.AertsShape.compute(ivMask, iv.pixelDimensions, results);
				radiomics.AertsTexture.compute(iv.data, ivMask, results);

				% Wavelet decompositions
				this.processWavelet(iv.data, ivMask, results);

				this.outputResults(rtStruct, results, ia, markup);
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
						this.logInfo(...
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

		%-------------------------------------------------------------------------
		function logDebug(this, msg)
			this.logger.debug(msg);
			this.logUi(msg);
		end

		%-------------------------------------------------------------------------
		function logInfo(this, msg)
			this.logger.info(msg);
			this.logUi(msg);
		end

		%-------------------------------------------------------------------------
		function logWarn(this, msg)
			this.logger.warn(msg);
			this.logUi(msg);
		end

		%-------------------------------------------------------------------------
		function logUi(this, msg)
			if ~ischar(msg)
				msg = msg();
			end
			this.outputLog = {this.outputLog{:},msg};
			this.nLogLines = this.nLogLines+numel(strsplit(msg, '\n'));
			% Force the outputText's underlying Java object to be multiline.
			% MATLAB changes the Java object depending if single or multiline.
			this.outputText.Max = max(this.nLogLines, 2);
			this.outputText.Value = this.nLogLines;
			this.outputText.String = this.outputLog;
			drawnow();
			this.jOutputText.setCaretPosition(this.jOutputText.getDocument().getLength());
		end

	end

end

