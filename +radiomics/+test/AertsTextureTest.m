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
			this.mask3D(11:14,15:18,4:5) = 1;
			image3D = AertsTexture.discretise(image3D, this.mask3D, this.nG);
			[result,nDir] = AertsTexture.glcm3D(image3D, this.mask3D, this.nG);
			this.verifyEqual(size(result), [nDir,this.nG,this.nG]);
		end
	end
	
end

