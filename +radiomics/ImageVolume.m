classdef ImageVolume < handle
	%IMAGEVOLUME Summary of this class goes here
	%   Detailed explanation goes here
	
	properties(SetAccess=private)
		data;
		frameNumbers;
		images;
		locations;
		pixelDimensions;
		seriesUid;
		sopInstUids;
	end
	
	methods
		function this = ImageVolume(series)
			imageArray = series.getImageList().toArray();
			locs = arrayfun(@(image) image.getSliceLocation(), imageArray);
			[locs,idx] = sort(locs);
			imageArray = imageArray(idx);
			nImages = numel(imageArray);
			% MATLAB transposes the axes!
			this.data = zeros(imageArray(1).getRows(), imageArray(1).getColumns(), ...
				nImages);
			for i=1:nImages
				this.data(:,:,i) = imageArray(i).getFloatPixelData();
			end
			this.images = imageArray;
			this.locations = locs;
			this.pixelDimensions = ...
				[flip(imageArray(1).getPixelSpacing()); ...
				 imageArray(1).getSliceThickness()];
			this.frameNumbers = arrayfun(@(image) image.getFrameIndex(), ...
				this.images);
			this.seriesUid = this.images(1).getSeriesUid();
			this.sopInstUids = arrayfun(@(image) {image.getSopInstanceUid()}, ...
				this.images);
		end
	end
	
end

