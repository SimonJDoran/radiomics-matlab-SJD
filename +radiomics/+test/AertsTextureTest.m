classdef AertsTextureTest < matlab.unittest.TestCase
	%AERTSTEXTURETEST Summary of this class goes here
	%   Detailed explanation goes here
	
	properties
		nY;
		nX;
		nZ;
		nG;
		mask3D;
	end
	
	methods(TestMethodSetup)
 		function runPreTest(this)
			this.nY = 24;
			this.nX = 32;
			this.nZ = 8;
			this.nG = 8;
			this.mask3D = zeros(this.nY, this.nX, this.nZ);
 		end
	end

	methods(Test)
		function testDiscretise(this)
			import radiomics.*;
			image3D = repmat(1:this.nX, this.nY, 1, this.nZ);
			this.mask3D(9:16,13:20,3:6) = 1;
			idx = this.mask3D == 1;
			result = AertsTexture.discretise(image3D, this.mask3D, this.nG);
			this.verifyEqual(min(result(idx)), 1);
			this.verifyEqual(max(result(idx)), this.nG);
		end

		function testGlcm3D(this)
			import radiomics.*;
			image3D = repmat(1:this.nX, this.nY, 1, this.nZ);
			this.mask3D(11:14,13:20,4:5) = 1;
			image3D = AertsTexture.discretise(image3D, this.mask3D, this.nG);
			[~,nDir] = AertsTexture.glcm3D(image3D, this.mask3D, this.nG);
			for i=1:this.nG
				constGlcmAll = zeros(nDir,this.nG,this.nG);
				constGlcmAll(1:13,i,i) = [21;24;21;28;32;28;21;24;21;42;48;42;56];
				constant3D = repmat(i, this.nY, this.nX, this.nZ);
				% Not normalised to allow inspection of pixel counts
				result = AertsTexture.glcm3D(constant3D, this.mask3D, this.nG, false);
				this.verifyEqual(size(result), [nDir,this.nG,this.nG]);
				this.verifyTrue(all(result(:) == constGlcmAll(:)), ...
					sprintf('GLCM not verified for GL: %d', i));
			end
		end

		function testGlrlm3D(this)
			import radiomics.*;
			image3D = repmat(1:this.nX, this.nY, 1, this.nZ);
			this.mask3D(11:14,13:20,4:5) = 1;
			image3D = AertsTexture.discretise(image3D, this.mask3D, this.nG);
			nR = max(size(image3D));
			[~,nDir] = AertsTexture.glrlm3D(image3D, this.mask3D, this.nG, nR);
			this.verifyEqual(nDir, 13);
			for i=1:this.nG
				constGlrlmAll = zeros(nDir,this.nG,nR);
				constGlrlmAll(1,i,1:2) = [22,21];
				constGlrlmAll(2,i,1:2) = [16,24];
				constGlrlmAll(3,i,1:2) = [22,21];
				constGlrlmAll(4,i,1:2) = [8,28];
				constGlrlmAll(5,i,2) = 32;
				constGlrlmAll(6,i,1:2) = [8,28];
				constGlrlmAll(7,i,1:2) = [22,21];
				constGlrlmAll(8,i,1:2) = [16,24];
				constGlrlmAll(9,i,1:2) = [22,21];
				constGlrlmAll(10,i,1:4) = [4,4,4,10];
				constGlrlmAll(11,i,4) = 16;
				constGlrlmAll(12,i,1:4) = [4,4,4,10];
				constGlrlmAll(13,i,8) = 8;
				constant3D = repmat(i, this.nY, this.nX, this.nZ);
				result = AertsTexture.glrlm3D(constant3D, this.mask3D, this.nG, nR);
				this.verifyEqual(size(result), [nDir,this.nG,nR]);
				this.verifyTrue(all(result(:) == constGlrlmAll(:)), ...
					sprintf('GLRLM not verified for GL: %d', i));
			end
		end

		function testCompute(this)
			import radiomics.*;
			image3D = repmat(1:this.nX, this.nY, 1, this.nZ);
			this.mask3D(9:16,13:20,3:6) = 1;
			result = AertsTexture.compute(image3D, this.mask3D, ...
				containers.Map('KeyType', 'char', 'ValueType', 'any'));
			metrics = Aerts.getMetrics();
			for i=1:metrics.size()
				metric = metrics.get(i);
				if isempty(strfind(metric, 'Aerts.Texture'))
					continue;
				end
				this.verifyTrue(result.isKey(metric) && isfinite(result(metric)), ...
					sprintf('Metric "%s" missing or non-finite', metric));
			end
		end

	end
	
end

