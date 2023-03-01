% Get previous report
clear
reportfp = 'D:\User Folders\Stephen\File matching\stephen sync\';
[fn, fp] = uigetfile(fullfile(reportfp, '*.mat'));
load(fullfile(fp, fn), 'fl1', 'fl2', 'fl3');

%% Comparing
items = {'twop', 'photometry', 'histology', 'videos', 'ephys'};
% items = {'histology'};
for ii = 4 : length(items)
    
    % Loading
    fl1_temp = fl1.(items{ii});
    fl2_temp = fl2.(items{ii});
    fl3_temp = fl3.(items{ii});
    
    n1 = length(fl1_temp);
    n2 = length(fl2_temp);
    n3 = length(fl3_temp);
    
    
    % Generating short fp
    fnl1 = length(setup.fp1.(items{ii}));
    fnl2 = length(setup.fp2.(items{ii}));
    fnl3 = length(setup.fp3.(items{ii}));
    
    % Hashing folder 1
    hwait = waitbar(0, 'Hashing Folder 1');
    for i = 1 : n1
        if mod(i, 1000) == 0
            waitbar(i/n1, hwait, sprintf('%s: Hashing Folder 1: %i/%i', items{ii}, i, n1));
        end
        fl1_temp(i).fpshort = fl1_temp(i).folder(fnl1+1:end);
        tohash = sprintf('%s%s', fl1_temp(i).fpshort, fl1_temp(i).name);
        fl1_temp(i).md5 = mMD5(tohash);
    end
    MD5_1 = {fl1_temp(:).md5};
    close(hwait);
    
    % Hashing folder 2
    if n2 > 0
        hwait = waitbar(0, 'Hashing Folder 2');
        for i = 1 : n2
            if mod(i, 1000) == 0
                waitbar(i/n2, hwait, sprintf('%s: Hashing Folder 2: %i/%i', items{ii}, i, n2));
            end
            fl2_temp(i).fpshort = fl2_temp(i).folder(fnl2+1:end);
            tohash = sprintf('%s%s', fl2_temp(i).fpshort, fl2_temp(i).name);
            fl2_temp(i).md5 = mMD5(tohash);
        end
        MD5_2 = {fl2_temp(:).md5};
        close(hwait);
    end
    
    % Hashing folder 3
    if n3 > 0
        hwait = waitbar(0, 'Hashing Folder 3');
        for i = 1 : n3
            if mod(i, 1000) == 0
                waitbar(i/n3, hwait, sprintf('%s: Hashing Folder 3: %i/%i', items{ii}, i, n3));
            end
            fl3_temp(i).fpshort = fl3_temp(i).folder(fnl3+1:end);
            tohash = sprintf('%s%s', fl3_temp(i).fpshort, fl3_temp(i).name);
            fl3_temp(i).md5 = mMD5(tohash);
        end
        MD5_3 = {fl3_temp(:).md5};
        close(hwait);
    end
    
    tic;
    % Reverse match folder 2
    if n2 > 0
        hwait = waitbar(0, 'Reverse matching Folder 2');
        rev2 = zeros(n2, 1);
        matched = 0;
        for i = 1 : n2
            if mod(i, 100) == 0
                waitbar(i/n2, hwait, sprintf('Rmatching folder 2 %s: %i/%i, matched %i/%i', items{ii}, i, n2, matched, i));
            end
            ind = strcmp(MD5_2{i},MD5_1);
            if any(ind)
                % It's a match
                rev2(i) = 1;
                MD5_1(ind) = [];
                matched = matched + 1;
            end
        end
        fl2_left.(items{ii}) = fl2_temp(rev2 == 0);
        close(hwait);
    end
    
    % Reverse match folder 3
    if n3 > 0
        hwait = waitbar(0, 'Reverse matching Folder 3');
        rev3 = zeros(n3, 1);
        matched = 0;
        for i = 1 : n3
            if mod(i, 100) == 0
                waitbar(i/n3, hwait, sprintf('Rmatching folder 3 %s: %i/%i, matched %i/%i', items{ii}, i, n3, matched, i));
            end
            ind = strcmp(MD5_3{i},MD5_1);
            if any(ind)
                % It's a match
                rev3(i) = 1;
                MD5_1(ind) = [];
                matched = matched + 1;
            end
        end
        fl3_left.(items{ii}) = fl3_temp(rev3 == 0);
        close(hwait);
    end
    
    t = round(toc);
    fprintf('%s: Reverse matching done. Elapsed time = %i seconds.\n', items{ii}, t);
end

%% Save
tic
save(fullfile(fp, 'Remove_extra.mat'), 'fl2_left', 'fl3_left', '-v7.3');
t = toc;
fprintf('Saving done. Elapsed time = %i seconds.\n', round(t))

%% Report
reportfn = sprintf('Remove extra.txt');
freport = fopen(fullfile(fp, reportfn), 'w');

fwrite(freport, sprintf('===================== Folder 2 =====================\n'));
for ii = 1 : length(items)
    if ~isfield(fl2_left, items{ii})
        continue;
    end
    if isempty(fl2_left.(items{ii}))
        continue;
    end
    
    fl2_temp = fl2_left.(items{ii});
    n2 = length(fl2_temp);
    
    fwrite(freport, sprintf('\n======================================\n'));
    fwrite(freport, sprintf('%s: The following files should be removed:\n', items{ii}));
    
    lastfolder = '';
    % Loop through
    for i = 1 : n2
        cfolder = fl2_temp(i).folder;
        cfile = fl2_temp(i).name;
        
        if ~strcmpi(cfolder, lastfolder)
            fwrite(freport, sprintf('\n%s\n', cfolder));
            lastfolder = cfolder;
        end
        fwrite(freport, sprintf('%s\n', cfile));
    end
    
end

fwrite(freport, sprintf('\n===================== Folder 3 =====================\n'));
for ii = 1 : length(items)
    if ~isfield(fl3_left, items{ii})
        continue;
    end
    
    if isempty(fl3_left.(items{ii}))
        continue;
    end
    
    fl3_temp = fl3_left.(items{ii});
    n3 = length(fl3_temp);
    
    fwrite(freport, sprintf('\n======================================\n'));
    fwrite(freport, sprintf('%s: The following files should be removed:\n', items{ii}));
    
    lastfolder = '';
    % Loop through
    for i = 1 : n3
        cfolder = fl3_temp(i).folder;
        cfile = fl3_temp(i).name;
        
        if ~strcmpi(cfolder, lastfolder)
            fwrite(freport, sprintf('\n%s\n', cfolder));
            lastfolder = cfolder;
        end
        fwrite(freport, sprintf('%s\n', cfile));
    end
    
end
fclose(freport);