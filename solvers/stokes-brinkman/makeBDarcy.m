function B = makeBDarcy(G, rock, fluid, Dofs, element, cells)
% makeBDarcy -- Construct the B matrix of the Darcy system with Taylor-Hood
%               elements based on grid and rock.
%
% SYNOPSIS:
%   B = makeBDarcy(G, rock, fluid, Dofs, element)
%
% PARAMETERS:
%
%   G       - Grid structure as generated by 'cartGrid'.
%
%   rock    - Rock data structure with valid field 'perm'.
%
%   fluid   - Fluid object containing 'fluid.mu' (water viscosity) and
%             'fluid.mu_eff' (the effective viscosity).
%
%   Dofs    - Degrees of Freedom structure as generated by 'findCartDofs'.
%
%   element - The name of a file containing element matrices. 
%             Default element = 'TH' gives file 'ElementMat2D'/'3D'.
%
%   cells   - The subset of the grid to calculate the B matrix for.
%
% RETURNS:
%   The B matrix for v1, v2 (and v3) in mixed system (only Darcy equation) with
%     Taylor-Hood elements based on half-dofs.
%
% COMMENTS:
%  Using half-dofs = Each velocity dof is assosiated with a cell, thus a
%  velocity dof that is shared between two, four, six or eight cells will appear in
%  the structure HalfDofs two, four, six or eight times, respectively.
        
  error(nargchk(5, 6, nargin, 'struct'));
    
  dim=numel(G.cartDims);
  
  % Load matrices for the reference element
  if strcmp(element, 'TH')
    if dim==2
      load ElementMat2D;
    elseif dim==3
      load ElementMat3D;
    end
  else
    load(element);
  end

  dxi = find(G.cellFaces(:,2)==1);  dxj = find(G.cellFaces(:,2)==2);
  dyi = find(G.cellFaces(:,2)==3);  dyj = find(G.cellFaces(:,2)==4);
  dx  = G.faces.centroids(G.cellFaces(dxj,1),1)-...
        G.faces.centroids(G.cellFaces(dxi,1),1);
  dy  = G.faces.centroids(G.cellFaces(dyj,1),2)-...
        G.faces.centroids(G.cellFaces(dyi,1),2);
  dx=dx(cells); dy=dy(cells);
  if dim==3
    dzi = find(G.cellFaces(:,2)==5);  dzj = find(G.cellFaces(:,2)==6);
    dz  = G.faces.centroids(G.cellFaces(dzj,1),3)- ...
          G.faces.centroids(G.cellFaces(dzi,1),3); 
    dz=dz(cells);
  end

  if size(rock.perm,2)==2
    KIx = 1./rock.perm(cells,1);
    KIy = 1./rock.perm(cells,2);
  elseif size(rock.perm,2)==3
    KIx = 1./rock.perm(cells,1);
    KIy = 1./rock.perm(cells,2);
    KIz = 1./rock.perm(cells,3);
  elseif size(rock.perm,2)==1
    KIx = 1./rock.perm(cells);
    KIy = 1./rock.perm(cells);
    if dim==3
      KIz = 1./rock.perm(cells);
    end
  end

  mu  = fluid.mu;         mut = fluid.mu_eff;
  nHD = size(Dofs.HalfDofs,2)*numel(cells);
  
  B_I  = zeros([size(Dofs.Vdofs,2)*size(Dofs.Vdofs,2)*numel(cells), 1]);
  B_J  = zeros([size(Dofs.Vdofs,2)*size(Dofs.Vdofs,2)*numel(cells), 1]);
  B1_V = zeros([size(Dofs.Vdofs,2)*size(Dofs.Vdofs,2)*numel(cells), 1]);
  B2_V = zeros([size(Dofs.Vdofs,2)*size(Dofs.Vdofs,2)*numel(cells), 1]);
  if dim==3
    B3_V = zeros([size(Dofs.Vdofs,2)*size(Dofs.Vdofs,2)*numel(cells), 1]);
  end
  
  locHD = compressDofs(Dofs.HalfDofs(cells,:));
  
  for i = 1:numel(cells),
    
    if mod(i,10000)==0 disp(i); end;
    Iv = locHD(i,:);   

    locixB = size(Dofs.Vdofs,2)*size(Dofs.Vdofs,2)*(i-1)+1:...
             size(Dofs.Vdofs,2)*size(Dofs.Vdofs,2)*i;

    %% K11 og K22
    %B1(Iv,Iv)=B1(Iv,Iv)+dx*dy*dz/8*Kx(i)*mu*VV;
    %B2(Iv,Iv)=B2(Iv,Iv)+dx*dy*dz/8*Ky(i)*mu*VV;
    %B3(Iv,Iv)=B3(Iv,Iv)+dx*dy*dz/8*Kz(i)*mu*VV;
    
    B_I(locixB) = reshape(repmat(Iv.', [1, size(Dofs.Vdofs,2)]), [], 1);
    B_J(locixB) = reshape(repmat(Iv,   [size(Dofs.Vdofs,2), 1]), [], 1);
     
    if dim==2
      
      val1 = dx(i)*dy(i)/4*KIx(i)*mu*M.VV;
      val2 = dx(i)*dy(i)/4*KIy(i)*mu*M.VV;
      
      B1_V(locixB) = val1(:); B2_V(locixB) = val2(:);
      
    elseif dim==3
      
      val1 = dx(i)*dy(i)*dz(i)/8*KIx(i)*mu*M.VV;
      val2 = dx(i)*dy(i)*dz(i)/8*KIy(i)*mu*M.VV;
      val3 = dx(i)*dy(i)*dz(i)/8*KIz(i)*mu*M.VV;
      
      B1_V(locixB) = val1(:); B2_V(locixB) = val2(:); B3_V(locixB) = val3(:);
    
    end
  end
  clear locixB val1 val2 val3 Iv;
  
  B1 = sparse(B_I,B_J,B1_V);
  clear B1_V;	
  B2 = sparse(B_I,B_J,B2_V);
  clear B2_V;
  if dim==3
    B3 = sparse(B_I,B_J,B3_V);
  end
  clear B3_V B_I B_J;

  if dim==2
     B = [B1              sparse(nHD,nHD);...
          sparse(nHD,nHD) B2             ];
     
  elseif dim==3
  B = [B1              sparse(nHD,nHD) sparse(nHD,nHD);...
       sparse(nHD,nHD) B2              sparse(nHD,nHD);...
       sparse(nHD,nHD) sparse(nHD,nHD) B3             ];
  end
end

function dofs = compressDofs(dofs);
s1 = size(dofs,1); s2 = size(dofs,2);
dofs   = reshape(dofs',[],1);
active = find(accumarray(dofs(:), 1) > 0);
compr  = zeros([max(dofs), 1]);
compr(active) = 1 : numel(active);
dofs = compr(dofs);
dofs = reshape(dofs',s2,s1)';
end
