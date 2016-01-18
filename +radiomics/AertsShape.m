classdef AertsShape < handle
	%AERTSSHAPE Summary of this class goes here
	%   Decoding tumour phenotype by noninvasive imaging using a quantitative
	% radiomics approach. Aerts et al. Nature Communications 2014
	% DOI: 10.1038/ncomms5006
	
	properties(Constant)
		Compactness1 = 'Aerts.Shape.Compactness1';
		Compactness2 = 'Aerts.Shape.Compactness2';
		MaximumDiameter = 'Aerts.Shape.MaximumDiameter';
		SphericalDisproportion = 'Aerts.Shape.SphericalDisproportion';
		Sphericity = 'Aerts.Shape.Sphericity';
		SurfaceArea = 'Aerts.Shape.SurfaceArea';
		SurfaceToVolumeRatio = 'Aerts.Shape.SurfaceToVolumeRatio';
		Volume = 'Aerts.Shape.Volume';
	end
	
	%----------------------------------------------------------------------------
	methods(Static)
		%-------------------------------------------------------------------------
		function collector = compute(image3D, mask3D, pixelDims, collector)
			import radiomics.*;
			[faces, vertices] = isosurface(mask3D, 0.5);
			% Convert to mm instead of pixels
			for i=1:3
				faces(:,i) = faces(:,i)*pixelDims(i);
				vertices(:,i) = vertices(:,i)*pixelDims(i);
			end
			dt = delaunayTriangulation(vertices);
			[hullVertices,v] = convexHull(dt);
			area = AertsShape.area(dt, hullVertices);
			volume = sum(mask3D(:))*prod(pixelDims);
			collector(AertsShape.Compactness1) = volume/(sqrt(pi)*area.^(2/3));
			collector(AertsShape.Compactness2) = (36*pi*volume.^2)/(area.^3);
			collector(AertsShape.MaximumDiameter) = AertsShape.maxDiameter(...
				dt.Points);
			% Radius of sphere of equivalent volume: sphereR
			sphereR = (3*volume/(4*pi)).^(1/3);
			collector(AertsShape.SphericalDisproportion) = area/(4*pi*sphereR.^2);
			collector(AertsShape.Sphericity) = (pi.^(1/3)*(6*volume).^(2/3))/area;
			collector(AertsShape.SurfaceArea) = area;
			collector(AertsShape.SurfaceToVolumeRatio) = area/volume;
			collector(AertsShape.Volume) = volume;
			fprintf('Voxels: %f\nIsosurface: %f\nRatio: %f\n', volume, v, volume/v);
		end

	end % methods(Static)

	%----------------------------------------------------------------------------
	methods(Static,Access=private)
		%-------------------------------------------------------------------------
		function result = area(dt, hullVertices)
			import radiomics.*;
			result = 0;
			sz = size(hullVertices);
			nVerts = sz(1);
			for i=1:nVerts
				verts = zeros(3, 3);
				verts(1,:) = dt.Points(hullVertices(i,1),:);
				verts(2,:) = dt.Points(hullVertices(i,2),:);
				verts(3,:) = dt.Points(hullVertices(i,3),:);
				result = result + AertsShape.areaTriangle(verts);
			end
		end

		%-------------------------------------------------------------------------
		function result = areaTriangle(verts)
			ab = verts(1,:)-verts(2,:);
			ac = verts(1,:)-verts(3,:);
			result = 0.5*norm(cross(ab, ac));
		end

		%-------------------------------------------------------------------------
		function pHist = histogram(greyLevels)
			rawHist = histcounts(greyLevels);
			idx = rawHist > 0;
			pHist = zeros(numel(rawHist),1);
			pHist(idx) = rawHist(idx)/sum(rawHist(idx));
		end

		%-------------------------------------------------------------------------
		function result = maxDiameter(allPoints)
			sz = size(allPoints);
			nPoints = sz(1);
			maxDistance = zeros(1, nPoints);
			x = allPoints(:,1);
			y = allPoints(:,2);
			z = allPoints(:,3);
			for i=1:nPoints
			  distances = sqrt((x-x(i)).^2+(y-y(i)).^2+(z-z(i)).^2);
			  maxDistance(i) = max(distances);
			end
			result = max(maxDistance);
		end

		%-------------------------------------------------------------------------
		function result = meanAbsDev(greyLevels)
			result = mean(abs(greyLevels-mean(greyLevels)));
		end

		%-------------------------------------------------------------------------
		function result = range(greyLevels)
			result = max(greyLevels)-min(greyLevels);
		end

		%-------------------------------------------------------------------------
		function result = rms(greyLevels)
			result = sqrt(mean(greyLevels.^2));
		end

		%-------------------------------------------------------------------------
		function result = uniformity(pHist)
			result = sum(pHist.^2);
		end

	end % methods(Static,Access=private)

end

