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
		fuseButton;
		importAimItem;
		importDicomItem;
		jOutputText;
		lesionEdit;
		nLogLines = 0;
		options = [];
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
		function delete(this)
			this.saveOptions();
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
		function initApplication(this)
			optionsFile = [this.productDir,this.productTag,'_options.xml'];
			io = radiomics.OptionsIo();
			if (exist(optionsFile, 'file') ~= 2)
				this.options = radiomics.Options();
				io.write(this.options, optionsFile);
			else
				this.options = io.read(optionsFile);
				if isempty(this.options)
					this.options = radiomics.Options();
				end
			end
			if isempty(this.options.projectId)
				this.options.projectId = 'Cervix_Radiomi';
			end
			this.logInfo(@() sprintf('Project ID: %s', this.options.projectId));
		end

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
			uicontrol(this.patientEdit);

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
			this.dirText.String = this.options.targetPath;
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
			this.patientEdit.KeyReleaseFcn = @this.onEditKeyRelease;
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
			this.fuseButton = uicontrol(searchStrip, 'Style', 'pushbutton', ...
				'String', 'Fuse');
			this.fuseButton.Callback = @this.onFuse;
			this.fuseButton.Enable = 'off';

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
			x = x+buttonW+gap;
			this.fuseButton.Position = [x yPad buttonW scanH];
		end

		%-------------------------------------------------------------------------
		function initTable(this, xPad, yPad, gap)
			frPos = this.frame.Position;
			frameW = frPos(3);
			this.table = uitable(this.frame);
			this.table.CellSelectionCallback = @this.onCellSelection;
			this.table.ColumnName = ...
				{'Person Name','Person ID','Date/Time','Scan','Lesion','ROI', 'Type'};
			this.table.ColumnWidth = ...
				{200,150,150,'auto','auto','auto','auto'};
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
			multi = this.enableStr((numel(this.tableSelection)/2) > 1);
			this.fuseButton.Enable = multi;
		end

		%-------------------------------------------------------------------------
		function onEditKeyRelease(this, ~, event)
			if (~strcmp(event.Key, 'return'))
				return
			end
			this.onSearch();
		end

		%-------------------------------------------------------------------------
		function onExit(this, ~, ~)
			close(this.frame);
			this.delete();
		end

		%-------------------------------------------------------------------------
		function onFuse(this, ~, ~)
			this.frame.Pointer = 'watch';
			rowIdx = unique(this.tableSelection(:,1));
			nRows = length(rowIdx);
			iaItems = this.table.UserData;
			if isempty(iaItems)
				this.frame.Pointer = 'arrow';
				return;
			end
			if isempty(this.options.targetPath)
				this.selectTargetPath();
				if isempty(this.options.targetPath)
					this.frame.Pointer = 'arrow';
					return;
				end
			end
			this.logInfo(@() sprintf('ROI Fusion: processing %d annotations...', nRows));
			fuser = radiomics.RoiFuser();
			iacList = fuser.fuse(iaItems(rowIdx), this.dataSource, ...
				this.options.projectId);
			this.logInfo(@() sprintf('ROI Fusion: %i fused ROIs...', ...
				iacList.size()));
			for i=1:iacList.size()
				iac = iacList.get(i);
				this.saveFusedIac(iac);
			end

			this.logInfo(@() sprintf('ROI Fusion: processing annotations complete'));
			this.frame.Pointer = 'arrow';
		end

		%-------------------------------------------------------------------------
		function onImportAim(this, ~, ~)
			import ether.dicom.io.*;
			title = 'Import AIM Files';
			path = uigetdir(this.options.localImportPath, title);
			if ~isa(path, 'char')
				return;
			end
			this.frame.Pointer = 'watch';
			this.options.localImportPath = [path,filesep()];
			this.logInfo(@() ...
				['Local AIM import directory: ',this.options.localImportPath]);
			this.saveOptions();
			this.dataSource.importAim(path);
			this.logInfo(@() sprintf('Local AIM import complete'));
			this.frame.Pointer = 'arrow';
		end

		%-------------------------------------------------------------------------
		function onImportDicom(this, ~, ~)
			import ether.dicom.io.*;
			title = 'Import DICOM Files';
			path = uigetdir(this.options.localImportPath, title);
			if ~isa(path, 'char')
				return;
			end
			this.frame.Pointer = 'watch';
			this.options.localImportPath = [path,filesep()];
			this.logInfo(@() ...
				['Local DICOM import directory: ',this.options.localImportPath]);
			this.saveOptions();
			this.dataSource.importDicom(path);
			this.logInfo(@() sprintf('Local DICOM import complete'));
			this.frame.Pointer = 'arrow';
		end

		%-------------------------------------------------------------------------
		function onOutputDir(this, ~, ~)
			this.selectTargetPath();
		end

		%-------------------------------------------------------------------------
		function onProcess(this, ~, ~)
			this.frame.Pointer = 'watch';
			rowIdx = unique(this.tableSelection(:,1));
			nRows = length(rowIdx);
			radItems = this.table.UserData;
			if isempty(radItems)
				this.frame.Pointer = 'arrow';
				return;
			end
			if isempty(this.options.targetPath)
				this.selectTargetPath();
				if isempty(this.options.targetPath)
					this.frame.Pointer = 'arrow';
					return;
				end
			end
			this.logInfo(@() sprintf('Processing %d ROIs...', nRows));
			analyser = radiomics.TextureAnalyser3D();
			resultList = analyser.analyse(radItems(rowIdx), this.dataSource, ...
				this.options.projectId);
			this.saveResults(resultList);
			this.frame.Pointer = 'arrow';
			this.logInfo(@() sprintf('Processing RT-STRUCTs complete'));
			return;
		end

		%-------------------------------------------------------------------------
		function onSearch(this, ~, ~)
			this.frame.Pointer = 'watch';
			this.table.UserData = [];
			this.table.Data = [];
			drawnow();
			this.processButton.Enable = this.enableStr(false);
			patStr = get(this.patientEdit, 'String');
%			lesionStr = get(this.lesionEdit, 'String');
% 			scanItems = get(this.scanList, 'String');
% 			scanIdx = get(this.scanList, 'Value');
%			scanStr = scanItems{scanIdx};
			this.logInfo(@() sprintf(...
				'Searching for patients like "%s" in project %s...', ...
				patStr, this.options.projectId));
			

			radItemList = ether.collect.CellArrayList('radiomics.RadItem');
         
         % First add the ImageAnnotationCollections
         iacList = this.dataSource.searchIac(patStr, this.options.projectId);

			for i=1:iacList.size()
				iac = iacList.get(i);
				iaArr = iac.getAllAnnotations();
				for j=1:length(iaArr)
					iaItem = radiomics.IaItem(iaArr(j), iac);
					radItemList.add(iaItem);
				end
         end
          % Now do the same thing for RT-STRUCTs.
         rtsList = this.dataSource.searchRts(patStr, this.options.projectId);
         
			for i=1:rtsList.size()
				rts = rtsList.get(i);
            roiList = rts.getRoiList();
				for j=1:length(roiList)
					rtRoiItem = radiomics.RtRoiItem(roiList.get(j), rts);
					radItemList.add(rtRoiItem);
				end
			end

			% ToDo: Filter the iaItemList for lesion and scan matches
			nCols = 7;
			data = cell(radItemList.size(), nCols);
			items = this.sortRadItems(radItemList.toCellArray());
			for i=1:radItemList.size()
				cellItem = items(i);
            item = cellItem{1};
				data{i,1} = item.personName;
				data{i,2} = item.personId;
				data{i,3} = item.dateTime;
				data{i,4} = item.scan;
				data{i,5} = item.lesionNumber;
				data{i,6} = item.roiNumber;
            data{i,7} = '';
            if isa(item, 'radiomics.IaItem')
               data{i,7} = 'IAC';
            end
            if isa(item, 'radiomics.RtRoiItem')
               data{i,7} = 'RT-STRUCT';
            end
         end         
         
         if (iacList.size() + rtsList.size()) == 0
				message = sprintf('No results for: %s', patStr);
				this.logInfo(message);
				msgbox(message, 'Search', 'warn', 'modal');
				this.frame.Pointer = 'arrow';
				return;
         end
         
			this.table.UserData = items;
			this.table.Data = data;
			this.logInfo(@() sprintf('Search complete'));
			this.frame.Pointer = 'arrow';
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
			if isempty(this.jOutputText)
				return;
			end
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

		%-------------------------------------------------------------------------
		function iaOutputResults(this, results, IaItem)
			import radiomics.*;
        
			iac = iaItem.iac;
			patientName = iac.person.name;
			if isempty(patientName)
				patientName = iac.person.id;
			end
			if isempty(patientName)
				patientName = iac.uniqueIdentifier;
			end
			patDir = [this.options.targetPath,patientName,filesep()];
			if (exist(patDir, 'dir') == 0)
				mkdir(patDir);
			end
			lesionStr = '';
			if (~isempty(iaItem.scan))
				if (iaItem.lesionNumber > 0) && (iaItem.roiNumber > 0)
					lesionStr = sprintf('%s-%03i-%s-%03i', iaItem.personName, ...
						iaItem.lesionNumber, iaItem.scan, iaItem.roiNumber);
				else
					lesionStr = strjoin(strsplit(erase(iaItem.scan, '.'), ' '), '_');
				end
			end
			ia = iaItem.ia;
			dt = strjoin(strsplit(ia.dateTime, ':'), '-');
			fileName = [patDir,'AertsResults'];
			desc = strjoin(strsplit(iac.description, ' '), '_');
			if ~isempty(desc)
				fileName = [fileName,'_',desc];
			end
			if ~isempty(lesionStr)
				fileName = [fileName,'_',lesionStr];
			end
			fileName = [fileName,'_',dt,'_',ia.uniqueIdentifier,'.txt'];
			this.logInfo(['Writing results to: ',fileName]);
			fileId = fopen(fileName, 'w');
			fprintf(fileId, 'PatientName: %s\n', patientName);
			fprintf(fileId, 'AnnotationCollectionDescription: %s\n', iac.description);
			fprintf(fileId, 'AnnotationName: %s\n', ia.name);
			fprintf(fileId, 'AnnotationUid: %s\n', ia.uniqueIdentifier);
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
			fclose(fileId);
		end


		%-------------------------------------------------------------------------
		function rtRoiOutputResults(this, results, rtRoiItem)
			import radiomics.*;
        
			rts = rtRoiItem.rts;
			patientName = rts.getPatientName();
			if isempty(patientName)
				patientName = rts.getPatientId();
			end
			if isempty(patientName)
				patientName = rts.getSopInstanceUid();
			end
			patDir = [this.options.targetPath,patientName,filesep()];
			if (exist(patDir, 'dir') == 0)
				mkdir(patDir);
			end
			lesionStr = '';
			if (~isempty(rtRoiItem.scan))
				if (rtRoiItem.lesionNumber > 0) && (rtRoiItem.roiNumber > 0)
					lesionStr = sprintf('%s-%03i-%s-%03i', patientName, ...
						rtRoiItem.lesionNumber, rtRoiItem.scan, rtRoiItem.roiNumber);
				else
					lesionStr = strjoin(strsplit(erase(rtRoiItem.scan, '.'), ' '), '_');
				end
			end
		   rtRoi = rtRoiItem.rtRoi;
			dt = strjoin(strsplit(rtRoiItem.dateTime, ':'), '-');
			fileName = [patDir,'AertsResults'];
			desc = strjoin(strsplit(rts.getDescription(), ' '), '_');
			if ~isempty(desc)
				fileName = [fileName,'_',desc];
			end
			if ~isempty(lesionStr)
				fileName = [fileName,'_',lesionStr];
			end
			fileName = [fileName,'_',dt,'_',rts.getSopInstanceUid(),'_',rtRoi.number,'.txt'];
			this.logInfo(['Writing results to: ',fileName]);
			fileId = fopen(fileName, 'w');
			fprintf(fileId, 'PatientName: %s\n', patientName);
			fprintf(fileId, 'RT-STRUCT Description: %s\n', rts.getDescription());
			fprintf(fileId, 'ROI name: %s\n', rtRoi.name);
			fprintf(fileId, 'ROI UID: %s\n', rts.getSopInstanceUid(),'_',rtRoi.number);
         fprintf(fileId, 'Series description: %s\n', rtRoiItem.seriesDescription);
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
			fclose(fileId);
		end

		%-------------------------------------------------------------------------
		function saveFusedIac(this, iac)
			import radiomics.*;
			iacDir = this.options.targetPath;
			if (exist(iacDir, 'dir') == 0)
				mkdir(iacDir);
			end
			iaArr = iac.getAllAnnotations();
			iaName = iaArr(1).name;
			iacUid = iac.uniqueIdentifier;
			fileName = [iacDir,iaName,'_',iacUid,'.xml'];
			this.logInfo(['Writing IAC to: ',fileName]);
			jIac = iac.getJavaIac();
			jWriter = icr.etherj.aim.DefaultXmlWriter();
			try
				jWriter.write(jIac, fileName);
			catch ex
				this.logWarn(@() sprintf('Error writing IAC: %s', ex.message));
			end
		end

		%-------------------------------------------------------------------------
		function saveOptions(this)
			optionsFile = [this.productDir,this.productTag,'_options.xml'];
			io = radiomics.OptionsIo();
			io.write(this.options, optionsFile);
		end

		%-------------------------------------------------------------------------
		function saveResults(this, resultList)
			for i=1:resultList.size()
				result = resultList.get(i);
            if isa(result.radItem, 'radiomics.IaItem')
				   this.iaOutputResults(result.results, result.radItem)
            elseif isa(result.radItem, 'radiomics.RtRoiItem')
				   this.rtRoiOutputResults(result.results, result.radItem)
            end            
			end
		end

		%-------------------------------------------------------------------------
		function selectTargetPath(this)
			path = uigetdir(this.options.targetPath, 'Select results directory');
			if isempty(path)
				return;
			end
			this.options.targetPath = [path,filesep()];
			this.dirText.String = this.options.targetPath;
			this.logInfo(@() ['Results directory set to: ',this.options.targetPath]);
			this.saveOptions();
			drawnow();
		end

		%-------------------------------------------------------------------------
		function items = sortRadItems(this, items)
			% Sort into name order
			names = cellfun(@(item) item.personName, items, ...
            'UniformOutput', false);
			dateTimes = cellfun(@(item) string(item.dateTime), items, ...
				'UniformOutput', false);
			[names,idx] = sort(names);
			dateTimes = dateTimes(idx);
			items = items(idx);
			% Convert dateTimes to uint64
			dates = cellfun(@(dt) icr.etherj.aim.AimUtils.parseDateTime(dt), ...
				dateTimes, 'UniformOutput', false);
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

	end

end

