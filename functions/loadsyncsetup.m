function setup = loadsyncsetup(setupname)
% Load file sync setup from json

if nargin < 1
    setupname = 'setup.json';
end

fid = fopen(setupname);
fdata = fread(fid);
fclose(fid);
fdata = char(fdata');
setup = jsondecode(fdata);

end

