% compare2DDarcySBBCExample -- A simple test case comparison between
%                              Darcy and Stokes-Brinkman solvers driven
%                              by pressure BCs.
%
% SYNOPSIS:
%   compare2DDarcySBBCExample
%
% PARAMETERS:
%   None
%
% RETURNS:
%   Nothing, though being implemented as a script, the variables remain
%   available in the base workspace upon completion.

% set grid parameters
nx        = 30;  
ny        = 30;
cartDims  = [nx ny];
physDims  = [0 1 0 1];

% generate grid and DOFs
G          = cartGrid2D(cartDims,physDims([2 4]));
G.physDims = physDims;
G          = computeGeometry(G);
Dofs       = findCartDofs(G);

% generate rock and fluid structs
fluid        = initSingleFluid;
fluid.mu_eff = 0;
rock.perm    = ones(G.cells.num,1)*darcy()/1000;
rock.poros   = repmat(0.3, [G.cells.num, 1]);
gravity off;

% set BCs
ind         = any(G.faces.neighbors==0,2);
bcfaces     = find(ind);
dum         = false(G.faces.num,1); 
dum(bcfaces)= true;
tags        = G.cellFaces(dum(G.cellFaces(:,1)),2);
bcfaces     = G.cellFaces(dum(G.cellFaces(:,1)),1);

face_le = bcfaces(tags==1); face_r = bcfaces(tags==2);
face_l  = bcfaces(tags==3); face_u = bcfaces(tags==4);
bcfaces = [face_l;face_u];

BCsb = addBCSB([],   face_le, 'pressure',   repmat(p_le, numel(face_le), 1), G, Dofs);
BCsb = addBCSB(BCsb, face_r , 'pressure',   repmat(p_r,  numel(face_r),  1), G, Dofs);
BCsb = addBCSB(BCsb, bcfaces, 'velocity_n', repmat(0,    numel(bcfaces), 1), G, Dofs); 
BCd  = addBC(  [],   face_le, 'pressure',   repmat(2e5, numel(face_le), 1));
BCd  = addBC(  BCd,  face_r , 'pressure',   repmat(1e5, numel(face_r),  1));

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% Fine-scale Stokes-Brinkman (Taylor-Hood)
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

% assemble system
Ssb = makeSystemSB(G, Dofs, rock, fluid);

% solve system
[Ssb, FSsb] = solveSystemSB(Ssb, G, Dofs, 'bc', BCsb);
FSsb        = nodeToCellData(FSsb, G, Dofs);

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% Fine-scale Darcy (Raviart-Thomas)
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

% assemble system
S = computeMimeticIP(G, rock);

% solve system
[FSd, xwRef] = solveIncompFlow(initResSol(G, 0.0), initWellSol([], 0.0), ...
                                 G, S, fluid, 'bc', BCd);

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% Plotting and printing
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

cellNo   = rldecode(1:G.cells.num, double(G.cells.numFaces), 2) .';
fluxFSd  = accumarray(cellNo, abs(FSd.cellFlux));
fluxFSsb = accumarray(cellNo, abs(FSsb.cellFlux));

fprintf(1,'\nL2 pressure norm: \t%4.2d', ...
        norm(abs(FSsb.cellPressure-FSd.cellPressure))/norm(FSd.cellPressure));

fprintf(1,'\nL2 flux norm:\t\t%4.2d\n',...
        norm(abs(fluxFSsb-fluxFSd))/norm(fluxFSd));

figure('Position',[0 300 800 800]);
subplot(2,2,1); plotCellData(G, fluxFSd*day());cx = caxis;
title('Darcy flux [m/day]'); shading flat; axis equal tight; 
subplot(2,2,2); plotCellData(G, fluxFSsb*day()); caxis(cx);
title('Stokes-Brinkman flux [m/day]'); shading flat; axis equal tight;
subplot(2,2,3); plotCellData(G, convertTo(FSd.cellPressure, barsa()));
title('Darcy pressure [bar]'); shading flat; axis equal tight; cx = caxis;
subplot(2,2,4); plotCellData(G, convertTo(FSsb.cellPressure, barsa())); caxis(cx);
title('Stokes-Brinkman pressure [bar]'); shading flat; axis equal tight;
