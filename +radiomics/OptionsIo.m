classdef OptionsIo < handle
	%OPTIONSIO Summary of this class goes here
	%   Detailed explanation goes here
	
	%----------------------------------------------------------------------------
	properties
	end
	
	%----------------------------------------------------------------------------
	properties(Constant,Access=private)
		ATTR_ID = 'id';
		ATTR_PATH = 'path';
		NODE_OPTIONS = 'radiomicsOptions';
		NODE_PATH = 'path';
		NODE_PROJECT = 'project';
		NODE_TARGET_PATH = 'targetPath';
		NODE_TEXT = '#text';
		NODE_XNAT = 'xnat';
	end

	%----------------------------------------------------------------------------
	methods
		%-------------------------------------------------------------------------
		function [options,message] = read(this, filePath)
			message = '';
			try
				doc = xmlread(filePath);
				fprintf('File read - %s\n', filePath);
				options = this.parseDoc(doc);
			catch me
				fprintf(2, 'Error reading file - %s\n', me.message);
				message = me.message;
				options = [];
			end
		end

		%-------------------------------------------------------------------------
		function [status,message] = write(this, options, filePath)
			status = 0;
			message = '';
			[fileId,ioMessage] = fopen(filePath, 'w', 'l', 'UTF-8');
			if (fileId < 0)
				message = ioMessage;
				status = 1;
				return;
			end
			this.writeDtd(fileId);
			this.writeDoc(fileId, options);
			fclose(fileId);
		end

	end
	
	%----------------------------------------------------------------------------
	methods(Access=private)
		%-------------------------------------------------------------------------
		function options = parsePath(~, pathNode, options)
			import ether.Xml;
			import radiomics.*;
			childNodes = pathNode.getChildNodes();
			for i=0:childNodes.getLength-1
				node = childNodes.item(i);
				switch char(node.getNodeName)
					case OptionsIo.NODE_TEXT
						continue;

					case OptionsIo.NODE_TARGET_PATH
						options.targetPath = Xml.getAttrStr(node.getAttributes(), ...
							OptionsIo.ATTR_PATH);

					otherwise
				end
			end
		end

		%-------------------------------------------------------------------------
		function options = parseDoc(this, doc)
			import ether.Xml;
			import radiomics.*;
			options = radiomics.Options();
			rootNode = doc.getDocumentElement();
			if (~strcmp(rootNode.getNodeName(), OptionsIo.NODE_OPTIONS))
				throw(MException('OptionsIo', ...
					['Incorrect document type: ',rootNode.getNodeName()]));
			end

			childNodes = rootNode.getChildNodes();
			for i=0:childNodes.getLength-1
				node = childNodes.item(i);
				switch char(node.getNodeName)
					case OptionsIo.NODE_TEXT
						continue;

					case OptionsIo.NODE_PATH
						this.parsePath(node, options);

					case OptionsIo.NODE_XNAT
						this.parseXnat(node, options);

					otherwise
				end
			end
		end

		%-------------------------------------------------------------------------
		function options = parseXnat(~, xnatNode, options)
			import ether.Xml;
			import radiomics.*;
			childNodes = xnatNode.getChildNodes();
			for i=0:childNodes.getLength-1
				node = childNodes.item(i);
				switch char(node.getNodeName)
					case OptionsIo.NODE_TEXT
						continue;

					case OptionsIo.NODE_PROJECT
						options.projectId = Xml.getAttrStr(node.getAttributes(), ...
							OptionsIo.ATTR_ID);

					otherwise
				end
			end
		end

		%-------------------------------------------------------------------------
		function writeDoc(~, fileId, options)
			fprintf(fileId, '<radiomicsOptions>\n');
			fprintf(fileId, '	<path>\n');
			fprintf(fileId, '		<targetPath path="%s" />\n', options.targetPath);
			fprintf(fileId, '	</path>\n');
			fprintf(fileId, '	<xnat>\n');
			fprintf(fileId, '		<project id="%s" />\n', options.projectId);
			fprintf(fileId, '	</xnat>\n');
			fprintf(fileId, '</radiomicsOptions>\n');
		end

		%-------------------------------------------------------------------------
		function writeDtd(~, fileId)
			fprintf(fileId, '<?xml version="1.0" encoding="UTF-8"?>\n\n');
			fprintf(fileId, '<!DOCTYPE radiomicsOptions [\n');
			fprintf(fileId, '	<!ELEMENT radiomicsOptions (path,xnat)>\n');
			fprintf(fileId, '	<!ELEMENT path (targetPath)>\n');
			fprintf(fileId, '	<!ELEMENT targetPath EMPTY>\n');
			fprintf(fileId, '	<!ATTLIST targetPath\n');
			fprintf(fileId, '		path CDATA #REQUIRED\n');
			fprintf(fileId, '	>\n');
			fprintf(fileId, '	<!ELEMENT xnat (project)>\n');
			fprintf(fileId, '	<!ELEMENT project EMPTY>\n');
			fprintf(fileId, '	<!ATTLIST project\n');
			fprintf(fileId, '		id CDATA #REQUIRED\n');
			fprintf(fileId, '	>\n');
			fprintf(fileId, ']>\n\n');
		end

	end
	
end

