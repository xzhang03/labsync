% rw_def = 'R:\SZ_p1\2photon';
rw_def = 'R:\Andermann_Lab_Archive\active\2photon\stephen';

%% Actual source
rw_source = uigetdir(rw_def);

prompt = {'Enter a general file name:'};
dlgtitle = 'Filenames';
dims = [1 40];
definput = {'*.signals'};
opts.Interpreter = 'tex';
answer = inputdlg(prompt,dlgtitle,dims,definput,opts);

fn_gen = answer{1};

%% Get list
dirlist = dir(fullfile(rw_source,'**', fn_gen));

fns = {dirlist(:).name};
fps = {dirlist(:).folder};

disp(fns')

%% Get confirmation
goahead = input('Filenames look right (1 = yes, 0 = no): ');
if goahead ~= 1
    return;
end

%% Get moving
l = length(fns);
for i = 1 : l
    fn = fns{i};
    lms = strfind(fn, '_');
    mouse = fn(1:lms(1)-1);
    date = fn(lms(1)+1:lms(2)-1);
    runnum = str2double(fn(lms(2)+1:lms(3)-1));
    
    targetfolder = sbxRunDir(mouse, date, runnum, 'nasquatch');
    
    if ~exist(targetfolder, 'dir')
        msgbox(sprintf('%i %s: No target folder', i, fn));
        return;
    end
    
    flag = copyfile(fullfile(fps{i},fn), fullfile(targetfolder,fn));
    if flag == 0
        msgbox(sprintf('%i %s: Failed to copy', i, fn));
        return;
    end
    
    fprintf('%i %s rewinded.\n', i, fn);
end