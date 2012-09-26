function grdecl = readOperatorModField(fid,grdecl,kw)
% Read operator KEYWORDS
%
%  SYNOPSIS
%
%   grdecl = readOperatorModField(fid,grdecl,kw)
%  
%  PARAMETERS:
%   grdecl - a grdecl structure which have to have defined the
%            faults which multfelt have values for
%   kw   - KEYWORD, At the moment it recongnize 'MULTIPLY' and 'EQUALS'
%         multiply can only be none on existing fields. EQUALS accept
%         empty fields for 'MULTX','MULTY','MULTZ'
%     
%
%  RETURN:
%   grdecl - a grdecl structure
%
lin = fgetl(fid);
count = 1;
while isempty(regexp(lin, '^/', 'once'))
    % Skip blank lines and comments.
   if(~(isempty(lin) || all(isspace(lin)) || ~isempty(regexp(lin, '^--', 'match'))))
    split = regexp(lin, '(\w\.*\-*\**)+', 'match');
    name=char(split(1));    
    if(~length(split)==8)
        error(['Wrong line in readOpertor ', kw ,' for ',name])
    end
    value=str2num(char(split(2)));
    region=zeros(1,6);
    for i=3:8
       region(i-2)=str2num(char(split(i)));
    end
    [X,Y,Z] = meshgrid(region(1):region(2),...
        region(3):region(4),...
        region(5):region(6));
    logind = sub2ind(grdecl.cartDims,X(:),Y(:),Z(:));
    
    
    if( strcmp(kw,'MULTIPLY'))
        if(isfield(grdecl,name))
            grdecl.(name)(logind) = grdecl.(name)(logind)*value;
        else
            error(['Try do use ', kw , ' one non existing field ', name])
        end
    elseif( strcmp(kw,'EQUALS'))
        if(isfield(grdecl,name))
            grdecl.(name)(logind) = value;
        elseif ( any(strcmp(name,{'MULTX','MULTY','MULTZ'})))
            disp(['Use ', kw , ' one non existing field ', name])
            grdecl.(name) = ones(prod(grdecl.cartDims),1);
            grdecl.(name)(logind) = value;
        else
            error(['Try do use ', kw , ' one non existing field ', name])
        end
    else
        error(['Unknown uperator ', kw])
    end
   
   end
   lin = fgetl(fid);
   count =count +1;
end
