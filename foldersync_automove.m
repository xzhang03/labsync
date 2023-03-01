% Get previoud report
clear
reportfp = 'D:\User Folders\Stephen\File matching\stephen sync\';
[fn, fp] = uigetfile(fullfile(reportfp, '*.mat'));
load(fullfile(fp, fn), 'fl1_left');

%% Basic
items = {'twop', 'photometry', 'histology', 'videos', 'ephys'};
% items = {'histology'};
for ii = 1 : length(items)
    if isempty(fl1_left.(items{ii}))
        continue;
    end
    
    % Loading
    fl1_temp = fl1_left.(items{ii});
    matvec = [fl1_temp(:).matched];
    repvec = [fl1_temp(:).replace];
    movvec = [fl1_temp(:).move];
    resvec = ~(matvec | repvec | movvec);
    
    % Replace and mov
    fl1_temp_rep = fl1_temp(repvec);
    nrep = length(fl1_temp_rep);
    fl1_temp_mov = fl1_temp(movvec);
    nmov = length(fl1_temp_mov);
    fl1_temp_res = fl1_temp(resvec);
    
    % Replace
    hwait = waitbar(0, 'Replacing');
    for i = 1 : nrep
        if mod(i, 20) == 0
            waitbar(i/nrep, hwait, sprintf('Replacing %s: %i/%i', items{ii}, i, nrep));
        end
            
        fn = fl1_temp_rep(i).name;
        fpold = fl1_temp_rep(i).folder;
        fpnew = fl1_temp_rep(i).replacefp;
        
        if ~exist(fullfile(fpold,fn), 'file')
            flag = 2;
        elseif ~exist(fullfile(fpnew,fn), 'file')
            flag = 3;
        else
            flag = copyfile(fullfile(fpold,fn), fullfile(fpnew,fn));
        end
        
        switch flag
            case 0
                fprintf('Failed to replace:\n');
                fprintf('%s %i: %s\n', items{ii}, i, fullfile(fpold,fn));
                fprintf('>> %s\n', fullfile(fpnew,fn));
            case 2
                fprintf('Source file does not exist:\n');
                fprintf('%s %i: %s\n', items{ii}, i, fullfile(fpold,fn));
            case 3
                fprintf('To be replaced file does not exist:\n');
                fprintf('%s %i: %s\n', items{ii}, i, fullfile(fpnew,fn));
        end
    end
    close(hwait);
    
    % Move
    hwait = waitbar(0, 'Moving');
    for i = 1 : nmov
        if mod(i, 20) == 0
            waitbar(i/nmov, hwait, sprintf('Moving %s: %i/%i', items{ii}, i, nmov));
        end
        
        fn = fl1_temp_mov(i).name;
        fpold = fl1_temp_mov(i).folder;
        fpnew = fl1_temp_mov(i).movefp;
        
        if ~exist(fullfile(fpold,fn), 'file')
            flag = 2;
        elseif exist(fullfile(fpnew,fn), 'file')
            flag = 3;
        else
            flag = copyfile(fullfile(fpold,fn), fullfile(fpnew,fn));
        end
        
        switch flag
            case 0
                fprintf('Failed to replace:\n');
                fprintf('%s %i: %s\n', items{ii}, i, fullfile(fpold,fn));
                fprintf('>> %s\n', fullfile(fpnew,fn));
            case 2
                fprintf('Source file does not exist:\n');
                fprintf('%s %i: %s\n', items{ii}, i, fullfile(fpold,fn));
            case 3
                fprintf('To be moved file already exists:\n');
                fprintf('%s %i: %s\n', items{ii}, i, fullfile(fpnew,fn));
        end
    end
    close(hwait);
    
    % Load residual
    fl1_left.(items{ii}) = fl1_temp_res;
end

tic
save(fullfile(fp, 'automove_report.mat'), 'fl1_left', '-v7.3');
t = toc;
fprintf('Saving done. Elapsed time = %i seconds.\n', round(t))
    
%% Report
reportfn = sprintf('Automove report.txt');

freport = fopen(fullfile(fp, reportfn), 'w');

for ii = 1 : length(items)
    if isempty(fl1_left.(items{ii}))
        continue;
    end
    
    % Loading
    fl1_temp = fl1_left.(items{ii});
    foldersleft = {fl1_temp(:).folder};
    foldersleft = unique(foldersleft);
    miceleft = {fl1_temp(:).mouse};
    miceleft = miceleft(~cellfun('isempty', miceleft));
    miceleft = unique(miceleft);

    fwrite(freport, sprintf('======================================\n'));
    fwrite(freport, sprintf('%s: The following mice are not auto-moved:\n', items{ii}));
    for i = 1 : length(miceleft)
        fwrite(freport, sprintf('%s: %s\n', items{ii}, miceleft{i}));
    end

    fwrite(freport, sprintf('%s: The following folders are not auto-moved:\n', items{ii}));
    for i = 1 : length(foldersleft)
        fwrite(freport, sprintf('%s: %s\n', items{ii}, foldersleft{i}));
    end
end
fclose(freport)