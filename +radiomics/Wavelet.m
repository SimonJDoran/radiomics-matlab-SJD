classdef Wavelet
	%WAVELET Summary of this class goes here
	%   Detailed explanation goes here
	
	%----------------------------------------------------------------------------
	properties
	end
	
	%----------------------------------------------------------------------------
	methods(Static)
		function wt = dwt3u(X,varargin)
			% Undecimated conversion of MATLAB's dwt3, see doc dwt3 for details.
			import radiomics.*;
			% Check arguments.
			nbIn = nargin;
			narginchk(2,4);
			LoD = cell(1,3); HiD = cell(1,3); LoR = cell(1,3); HiR = cell(1,3);
			argStatus = true;
			nextARG = 2;
			if ischar(varargin{1})
				 [LD,HD,LR,HR] = wfilters(varargin{1}); 
				 for k = 1:3
					  LoD{k} = LD; HiD{k} = HD; LoR{k} = LR; HiR{k} = HR;
				 end

			elseif isstruct(varargin{1})
				 if isfield(varargin{1},'w1') && isfield(varargin{1},'w2') && ...
							isfield(varargin{1},'w3')
					  for k = 1:3
							[LoD{k},HiD{k},LoR{k},HiR{k}] = ...
								 wfilters(varargin{1}.(['w' int2str(k)]));
					  end
				 elseif isfield(varargin{1},'LoD') && isfield(varargin{1},'HiD') && ...
						  isfield(varargin{1},'LoR') && isfield(varargin{1},'HiR')
					  for k = 1:3
							LoD{k} = varargin{1}.LoD{k}; HiD{k} = varargin{1}.HiD{k};
							LoR{k} = varargin{1}.LoR{k}; HiR{k} = varargin{1}.HiR{k};
					  end
				 else
					  argStatus = false;
				 end

			elseif iscell(varargin{1})
				 if ischar(varargin{1}{1})
					  for k = 1:3
							[LoD{k},HiD{k},LoR{k},HiR{k}] = wfilters(varargin{1}{k});
					  end
				 elseif iscell(varargin{1})
					  Sarg = size(varargin{1});
					  if isequal(Sarg,[1 4])
							if ~iscell(varargin{1}{1})
								 LoD(1:end) = varargin{1}(1); HiD(1:end) = varargin{1}(2);
								 LoR(1:end) = varargin{1}(3); HiR(1:end) = varargin{1}(4);
							else
								 LoD = varargin{1}{1}; HiD = varargin{1}{2};
								 LoR = varargin{1}{3}; HiR = varargin{1}{4};
							end
					  elseif isequal(Sarg,[3 4])
							LoD = varargin{1}(:,1)'; HiD = varargin{1}(:,2)';
							LoR = varargin{1}(:,3)'; HiR = varargin{1}(:,4)';
					  else
							argStatus = false;
					  end
				 end
			else
				 argStatus = false;
			end
			if ~argStatus
				 error(message('Wavelet:FunctionArgVal:Invalid_ArgVal'));
			end
			sX = size(X);

			% Check arguments for Extension.
			dwtEXTM = 'sym';
			for k = nextARG:2:nbIn-1
				 switch varargin{k}
					case 'mode'  , dwtEXTM = varargin{k+1};
				 end
			end

			X = double(X);
			dec = cell(2,2,2);
			permVect = [];
			[a_Lo,d_Hi] = Wavelet.wdec1D(X,LoD{1},HiD{1},permVect,dwtEXTM);
			permVect = [2,1,3];
			[aa_Lo_Lo,da_Lo_Hi] = Wavelet.wdec1D(a_Lo,LoD{2},HiD{2},permVect,dwtEXTM);
			[ad_Hi_Lo,dd_Hi_Hi] = Wavelet.wdec1D(d_Hi,LoD{2},HiD{2},permVect,dwtEXTM);
			permVect = [1,3,2];
			[dec{1,1,1},dec{1,1,2}] = Wavelet.wdec1D(aa_Lo_Lo,LoD{3},HiD{3},permVect,dwtEXTM);
			[dec{2,1,1},dec{2,1,2}] = Wavelet.wdec1D(da_Lo_Hi,LoD{3},HiD{3},permVect,dwtEXTM);
			[dec{1,2,1},dec{1,2,2}] = Wavelet.wdec1D(ad_Hi_Lo,LoD{3},HiD{3},permVect,dwtEXTM);
			[dec{2,2,1},dec{2,2,2}] = Wavelet.wdec1D(dd_Hi_Hi,LoD{3},HiD{3},permVect,dwtEXTM);
			wt.sizeINI = sX;
			wt.filters.LoD = LoD;
			wt.filters.HiD = HiD;
			wt.filters.LoR = LoR;
			wt.filters.HiR = HiR;
			wt.mode = dwtEXTM;
			wt.dec = dec;
		end

		%-------------------------------------------------------------------------
		function demo
			z = zeros(65,65,65);
			z(:,:,33:end) = 1;
			zT = radiomics.Wavelet.dwt3u(z,'coif1','mode','zpd');
			figure;
			k = 0;
			for k1 = 1:2
				for k2 = 1:2
					for k3 = 1:2
						k = k+1;
						subplot(3,3,k);
						plot(squeeze(z(32,32,:)),'.-');
						hold on;
						plot(squeeze(zT.dec{k1,k2,k3}(32,32,:)),'-o');
						title(num2str([k1 k2 k3]));
					end
				end
			end
		end

	end

	%----------------------------------------------------------------------------
	methods(Static,Access=private)
		%-----------------------------------------------------------------------%
		% Method from MATLAB's dwt3 modified to do no decimation if 'zpd'
		% specified. Modified by Matt Orton.
		function [L,H] = wdec1D(X,Lo,Hi,perm,dwtEXTM)

			if ~isempty(perm) , X = permute(X,perm); end
			sX = size(X);
			if length(sX)<3 , sX(3) = 1; end

			lf = length(Lo);
			lx = sX(2);
			lc = lx+lf-1;
			if lx<lf+1
				 nbAdd = lf-lx+1;
				 switch dwtEXTM
					  case {'sym','symh','symw','asym','asymh','asymw','ppd'}
							Add = zeros(sX(1),nbAdd,sX(3));
							X = [Add , X , Add];
				 end
			end

			switch dwtEXTM
				 case 'zpd'             % Zero extension.

				 case {'sym','symh'}    % Symmetric extension (half-point).
					  X = [X(:,lf-1:-1:1,:) , X , X(:,end:-1:end-lf+1,:)];

				 case 'sp0'             % Smooth extension of order 0.
					  X = [X(:,ones(1,lf-1),:) , X , X(:,lx*ones(1,lf-1),:)];

				 case {'sp1','spd'}     % Smooth extension of order 1.
					  Z = zeros(sX(1),sX(2)+ 2*lf-2,sX(3));
					  Z(:,lf:lf+lx-1,:) = X;
					  last = sX(2)+lf-1;
					  for k = 1:lf-1
							Z(:,last+k,:) = 2*Z(:,last+k-1,:)- Z(:,last+k-2,:);
							Z(:,lf-k,:)   = 2*Z(:,lf-k+1,:)- Z(:,lf-k+2,:);
					  end
					  X = Z; clear Z;

				 case 'symw'            % Symmetric extension (whole-point).
					  X = [X(:,lf:-1:2,:) , X , X(:,end-1:-1:end-lf,:)];

				 case {'asym','asymh'}  % Antisymmetric extension (half-point).
					  X = [-X(:,lf-1:-1:1,:) , X , -X(:,end:-1:end-lf+1,:)];        

				 case 'asymw'           % Antisymmetric extension (whole-point).
					  X = [-X(:,lf:-1:2,:) , X , -X(:,end-1:-1:end-lf,:)];

				 case 'rndu'            % Uniformly randomized extension.
					  X = [randn(sX(1),lf-1,sX(3)) , X , randn(sX(1),lf-1,sX(3))];        

				 case 'rndn'            % Normally randomized extension.
					  X = [randn(sX(1),lf-1,sX(3)) , X , randn(sX(1),lf-1,sX(3))];        

				 case 'ppd'             % Periodized extension (1).
					  X = [X(:,end-lf+2:end,:) , X , X(:,1:lf-1,:)];

				 case 'per'             % Periodized extension (2).
					  if rem(lx,2) , X = [X , X(:,end,:)]; lx = lx + 1; end
					  I = [lx-lf+1:lx , 1:lx , 1:lf];
					  if lx<lf
							I = mod(I,lx);
							I(I==0) = lx;
					  end
					  X = X(:,I,:);
			end
			L = convn(X,Lo);
			H = convn(X,Hi);
			clear X
			switch dwtEXTM
				 case 'zpd'
				 otherwise
					  lenL = size(L,2);
					  first = lf; last = lenL-lf+1;
					  L = L(:,first:last,:); H = H(:,first:last,:);
					  lenL = size(L,2);
					  first = 1+floor((lenL-lc)/2);  last = first+lc-1;
					  L = L(:,first:last,:); H = H(:,first:last,:);
			end
			% original code
			% L = L(:,2:2:end,:);
			% H = H(:,2:2:end,:);
			% replacement code for undecimated transforms (all of switch statement)
			switch dwtEXTM
				 case 'zpd'
					  first = floor(length(Lo)/2)+1;
					  last = first+sX(2)-1;
					  L = L(:,first:last,:);
					  H = H(:,first-1:last-1,:);
				 otherwise
					  % do same thing as original code unless zpd (Zero extension) selected
					  L = L(:,2:2:end,:);
					  H = H(:,2:2:end,:);
			end

			if isequal(dwtEXTM,'per')
				 last = ceil(lx/2);
				 L = L(:,1:last,:);
				 H = H(:,1:last,:);
			end

			if ~isempty(perm)
				 L = permute(L,perm);
				 H = permute(H,perm);
			end
		end

	end
end

