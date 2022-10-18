function foldersync(varargin)
% Sync folders between servers. This function only does scanning and does
% not move anything. It will however create a substantial r/w load on the
% hard drites. Use it during off hours.
%
% Matching is done by comparing 1) file name, 2) file size, 3) mouse name,
% 4) hash value for larger files.
%
% Whitelist/Blacklist
% 1. Whitelisted = keep
% 2. Blacklisted = toss
% 3. Not listed = tossed but please add them to black to make the code run
% faster
% 4. Blactlisted and whitelisted = toss, please fix.


if nargin < 1
    varargin  = {};
end

%% Parse
p = inputParser;

% Rescan
addOptional(p, 'newscan', false); % Rescan source folders only
addOptional(p, 'rescan_source', false); % Rescan source folders only
addOptional(p, 'rescan_target', false); % Rescan target folders only

% Json names
addOptional(p, 'setupjson', 'setup.json');
addOptional(p, 'whitelistjson', 'whitelist.json');
addOptional(p, 'blacklistjson', 'blacklist.json');

% Hashing
addOptional(p, 'hashthresh', 10e9); % Default hashing 1GB files or larger
addOptional(p, 'hashbytes', 100); % Default hashing the first 100 bytes (noise in 2p/video data).

% Prepare for auto move
addOptional(p, 'automoveprep', true); % Generate potential target folder names so one could auto move

% File size considerations
addOptional(p, 'removedate', true);

% Unpack if needed
if iscell(varargin) && size(varargin,1) * size(varargin,2) == 1
    varargin = varargin{:};
end

parse(p, varargin{:});
p = p.Results;

%% Fix input errors
% Define a scan type
if ~p.newscan && ~p.rescan_source && ~p.rescan_target
    todo = questdlg('What type of scan?', 'Scan type', 'New scan','Rescan source',...
        'Rescan target', 'New scan');
    switch todo
        case 'New scan'
            p.newscan = true;
        case 'Rescan source'
            p.rescan_source = true;
        case 'Rescan target'
            p.rescan_target = true;
    end
end

%% Hashing algorithms
% Hasher (long hashing)
sha256hasher = System.Security.Cryptography.SHA256Managed;

% MD5 (short hashing)
if ~exist('mMD5.mexw64', 'file')
    warning('No mMD5 mex file found.');
    return;
end

%% Json parsing
setup = loadsyncsetup(p.setupjson);
whitelist = loadsyncsetup(p.whitelistjson);
blacklist = loadsyncsetup(p.blacklistjson);

% items
items = setup.items;

% Diable disenabled folders
if ~setup.fp2.enable
    fl2 = {};
end
if ~setup.fp3.enable
    fl3 = {};
end

%% IO report paths
if p.rescan_target
    % Target rescan only
    % Load previous mat
    [fn, fp] = uigetfile(fullfile(setup.reportfp, '*.mat'));
    load(fullfile(fp, fn), 'fl1_left');
    fout = 'report_rescan_target.mat';
    freport = 'report_rescan_target.txt';
    fautosync = 'autosync_rescan_target.txt';

elseif p.rescan_source
    
    % Source rescan only
    [fn, fp] = uigetfile(fullfile(setup.reportfp, '*.mat'));
    
    % Load previous mat
    if setup.fp2.enable && setup.fp3.enable
        load(fullfile(fp, fn), 'fl2', 'fl3');
    elseif setup.fp2.enable
        load(fullfile(fp, fn), 'fl2');
    elseif setup.fp3.enable
        load(fullfile(fp, fn), 'fl3');
    end
    
    fout = 'report_rescan_source.mat';
    freport = 'report_rescan_source.txt';
    fautosync = 'autosync_rescan_source.txt';
else
    % New scan
    folder = datestr(now,29);
    fp = fullfile(setup.reportfp, folder);
    if ~exist(fp, 'dir')
       mkdir(fp);
    end
    fout = 'report.mat';
    freport = 'report.txt';
    fautosync = 'autosync.txt';
end

%% Scan
% This part has load on hard drive. It will take a while
hwait = waitbar(0);
for ii = 1 : length(items)
    % Skip target rescan if the source is already sync'ed
    if p.rescan_target && isempty(fl1_left.(items{ii}))
        continue;
    end

    tic;
    
    % =================== FP1 ===================
    % Source scan (skip if rescan target ony)
    waitbar(ii/length(items), hwait, ['Scanning ', items{ii}, ', folder 1']);
    if ~p.rescan_target
        % Scan, takes a while
        fl1_temp = dir(fullfile(setup.fp1.(items{ii}),'**','*.*'));
        
        % Remove folders
        fl1_temp = fl1_temp(~[fl1_temp.isdir]);
        
        % Remove thumbs
        isthumb = strcmp({fl1_temp(:).name}, 'Thumbs.db');
        fl1_temp = fl1_temp(~isthumb);
        
        % Remove DS_store
        isdsstore = strcmp({fl1_temp(:).name}, '.DS_Store');
        fl1_temp = fl1_temp(~isdsstore);
        
        % For photometry keep my mice only
        if strcmp(items{ii}, 'photometry')
            ismyphotometry = regexp({fl1_temp(:).name}, setup.fp1.micename);
            ismyphotometry = cellfun(@mean, ismyphotometry) == 1;
            fl1_temp = fl1_temp(ismyphotometry);
        end
        
        % Remove date to make report file smaller
        if p.removedate
            fl1_temp = rmfield(fl1_temp, 'date');
            fl1_temp = rmfield(fl1_temp, 'datenum');
        end
        
        % Saving
        fl1.(items{ii}) = fl1_temp;
    end
    
    % =================== FP2 ===================
    % Target scan (skip if rescan source ony)
    % Skip if not enabled
    waitbar(ii/length(items), hwait, ['Scanning ', items{ii}, ', folder 2']);
    if ~p.rescan_source && setup.fp2.enable
        % Scan, takes a while
        fl2_temp = dir(fullfile(setup.fp2.(items{ii}),'**','*.*'));
        
        % Remove folders
        fl2_temp = fl2_temp(~[fl2_temp.isdir]);
        
        % Remove thumbs
        isthumb = strcmp({fl2_temp(:).name}, 'Thumbs.db');
        fl2_temp = fl2_temp(~isthumb);
        
        % Remove DS_store
        isdsstore = strcmp({fl2_temp(:).name}, '.DS_Store');
        fl2_temp = fl2_temp(~isdsstore);
        
        % For photometry keep my mice only
        if strcmp(items{ii}, 'photometry')
            ismyphotometry = regexp({fl2_temp(:).name}, fp2.micename);
            ismyphotometry = cellfun(@mean, ismyphotometry) == 1;
            fl2_temp = fl2_temp(ismyphotometry);
        end
        
        % Remove date to make report file smaller
        if p.removedate
            fl2_temp = rmfield(fl2_temp, 'date');
            fl2_temp = rmfield(fl2_temp, 'datenum');
        end
        
        % Saving
        fl2.(items{ii}) = fl2_temp;
    end
    
    % =================== FP3 ===================
    % Target scan (skip if rescan source ony)
    % Skip if not enabled
    waitbar(ii/length(items), hwait, ['Scanning ', items{ii}, ', folder 3']);
    if ~p.rescan_source && setup.fp3.enable
        % Scan, takes a while
        fl3_temp = dir(fullfile(setup.fp3.(items{ii}),'**','*.*'));
        
        % Remove folders
        fl3_temp = fl3_temp(~[fl3_temp.isdir]);
        
        % Remove thumbs
        isthumb = strcmp({fl3_temp(:).name}, 'Thumbs.db');
        fl3_temp = fl3_temp(~isthumb);

        % Remove DS_store
        isdsstore = strcmp({fl3_temp(:).name}, '.DS_Store');
        fl3_temp = fl3_temp(~isdsstore);
        
        % For photometry keep my mice only
        if strcmp(items{ii}, 'photometry')
            ismyphotometry = regexp({fl3_temp(:).name}, fp3.micename);
            ismyphotometry = cellfun(@mean, ismyphotometry) == 1;
            fl3_temp = fl3_temp(ismyphotometry);
        end
        
        % Remove date to make report file smaller
        if p.removedate
            fl3_temp = rmfield(fl3_temp, 'date');
            fl3_temp = rmfield(fl3_temp, 'datenum');
        end
        
        % Saving
        fl3.(items{ii}) = fl3_temp;
    end
    
    % Time
    t = toc;
    fprintf('Dir %s done. Elapsed time = %i seconds.\n', items{ii}, round(t))
end
close(hwait)

% Saving paths
tic
save(fullfile(fp, fout), 'setup', 'whitelist', 'blacklist', '-v7.3');
t = toc;
fprintf('Saving done. Elapsed time = %i seconds.\n', round(t))

%% Parsing mouse names and black/white listign mice
% This part doesn't caus any hard drive load

% Mice that are not in white or black list
% Initialize a cell to save these mice
unlisted_mice = cell(100,1);
ulm_ind = 0;

% This part does not scan hard drive
for ii = 1 : length(items)
    % Skip target rescan if the source is already sync'ed
    if p.rescan_target && isempty(fl1_left.(items{ii}))
        continue;
    end
    
    % Figure out where to get the mouse name: file name or folder name
    % This part is a bit messy because different file types have different
    % naming schemes
    if strcmp(items{ii},'twop') || strcmp(items{ii},'photometry')
        calculatemouse = true; % Get the actual mouse name
    else
        calculatemouse = false; % Use parent folder as mouse name
        if strcmp(items{ii},'histology')
            calculatemousefrompath = true;
        else
            calculatemousefrompath = false;
        end
    end

    if strcmp(items{ii},'twop')
        fixmousename = true;
    else
        fixmousename = false;
    end
    
    % =================== FP1 ===================
    % Loading item
    if ~p.rescan_target
        fl1_temp = fl1.(items{ii});
        n1 = length(fl1_temp);
    end
    
    % Folder 1
    if ~p.rescan_target
        tic
        % Loop to find fullnames in fl1
        hwait = waitbar(0, 'Parsing folder 1');
        for i = 1 : n1
            if mod(i, 100) == 0
                waitbar(i/n1, hwait, sprintf('%s: Parsing Folder 1: %i/%i', items{ii}, i, n1));
            end

            % Find when mouse folder starts
            if calculatemouse
                fl1_temp(i).mouse = getmousename(fl1_temp(i).name, setup.mousefolder);
            elseif calculatemousefrompath
                fl1_temp(i).mouse = getmousename(fl1_temp(i).folder, setup.mousefolder);
            else
                % Just the parent folder
                m1 = strfind(fl1_temp(i).folder,'\');
                m1 = m1(end);
                fl1_temp(i).mouse = fl1_temp(i).folder(m1+1:end);
            end

            if (length(fl1_temp(i).mouse) > 6) && (fixmousename)
                if strcmp(fl1_temp(i).mouse, '1')
                    fl1_temp(i).mouse = fl1_temp(i).mouse(1:6);
                else
                    fl1_temp(i).mouse = fl1_temp(i).mouse(1:5);
                end
            end
        end
        close(hwait);
        t = round(toc);
        fprintf('%s: Folder 1 parsing done. Elapsed time = %i seconds.\n', items{ii}, t);
        
        % White/black list
        tic
        [fl1_temp, unlisted] = blackwhitelist(fl1_temp, blacklist, whitelist);
        
        % Document mice  that are not in black or white list
        unlisted_mice(ulm_ind+1 : ulm_ind+length(unlisted)) = unlisted;
        ulm_ind = ulm_ind + length(unlisted);
        t = round(toc);
        fprintf('%s: Folder 1 black/white listing done. Elapsed time = %i seconds.\n', items{ii},t);
        
        % Save
        fl1.(items{ii}) = fl1_temp;
    end
    
    % =================== FP2 ===================
    % Loading item
    if ~p.rescan_source && setup.fp2.enable
        fl2_temp = fl2.(items{ii});
        n2 = length(fl2_temp);
    end
    
    % Folder 2
    if ~p.rescan_source && setup.fp2.enable
        tic
        % Loop to find fullnames in fl2
        hwait = waitbar(0, 'Parsing Folder 2');
        for i = 1 : n2
            if mod(i, 100) == 0
                waitbar(i/n2, hwait, sprintf('%s: Parsing Folder 2: %i/%i', items{ii}, i, n2));
            end

            % Find when mouse folder starts
            if calculatemouse
                [m1, m2] = regexp(fl2_temp(i).name, setup.mousefolder);

                if ~isempty(m1)
                    % If regex returns a cell even though the output is a
                    % single lement get convert the values to a numberic
                    if length(m1) == 1
                        m1 = cell2mat(m1);
                        m2 = cell2mat(m2);
                    end
                    fl2_temp(i).mouse = fl2_temp(i).name(m1:m2);
                else
                    fl2_temp(i).mouse = 'unknown';
                end
            elseif calculatemousefrompath
                [m1, m2] = regexp(fl2_temp(i).folder, setup.mousefolder);
                if ~isempty(m1)
                    if length(m1) > 1
                        m1 = m1(1);
                        m2 = m2(1);
                    end
                    fl2_temp(i).mouse = fl2_temp(i).folder(m1:m2);
                else
                    fl2_temp(i).mouse = 'unknown';
                end

            else
                % Just the parent folder
                m1 = strfind(fl2_temp(i).folder,'\');
                m1 = m1(end);
                fl2_temp(i).mouse = fl2_temp(i).folder(m1+1:end);
            end

            if (length(fl2_temp(i).mouse) > 6) && (fixmousename)
                if strcmp(fl2_temp(i).mouse, '1')
                    fl2_temp(i).mouse = fl2_temp(i).mouse(1:6);
                else
                    fl2_temp(i).mouse = fl2_temp(i).mouse(1:5);
                end
            end
        end
        
        close(hwait);
        t = round(toc);
        fprintf('%s: Folder 2 parsing done. Elapsed time = %i seconds.\n', items{ii}, t);
        
        % White/black list
        tic
        [fl2_temp, unlisted] = blackwhitelist(fl2_temp, blacklist, whitelist);
        
        % Document mice  that are not in black or white list
        unlisted_mice(ulm_ind+1 : ulm_ind+length(unlisted)) = unlisted;
        ulm_ind = ulm_ind + length(unlisted);
        t = round(toc);
        fprintf('%s: Folder 2 black/white listing done. Elapsed time = %i seconds.\n', items{ii},t);
        
        fl2.(items{ii}) = fl2_temp;
    end
    
    % =================== FP3 ===================
    % Loading item
    if ~p.rescan_source && setup.fp3.enable
        fl3_temp = fl3.(items{ii});
        n3 = length(fl3_temp);
    end
    
    % Folder 3
    if ~p.rescan_source && setup.fp3.enable
        tic
        % Loop to find fullnames in fl3
        hwait = waitbar(0, 'Parsing Folder 3');
        for i = 1 : n3
            if mod(i, 100) == 0
                waitbar(i/n3, hwait, sprintf('%s: Parsing Folder 3: %i/%i', items{ii}, i, n3));
            end

            % Find when mouse folder starts
            if calculatemouse
                [m1, m2] = regexp(fl3_temp(i).name, setup.mousefolder);

                if ~isempty(m1)
                    fl3_temp(i).mouse = fl3_temp(i).name(m1:m2);
                else
                    fl3_temp(i).mouse = 'unknown';
                end
            elseif calculatemousefrompath
                [m1, m2] = regexp(fl3_temp(i).folder, setup.mousefolder);
                if ~isempty(m1)
                    if length(m1) > 1
                        m1 = m1(end);
                        m2 = m2(end);
                    end
                    fl3_temp(i).mouse = fl3_temp(i).folder(m1:m2);
                else
                    fl3_temp(i).mouse = 'unknown';
                end

            else
                % Just the parent folder
                m1 = strfind(fl3_temp(i).folder,'\');
                m1 = m1(end);
                fl3_temp(i).mouse = fl3_temp(i).folder(m1+1:end);
            end

            if (length(fl3_temp(i).mouse) > 6) && (fixmousename)
                if strcmp(fl3_temp(i).mouse, '1')
                    fl3_temp(i).mouse = fl3_temp(i).mouse(1:6);
                else
                    fl3_temp(i).mouse = fl3_temp(i).mouse(1:5);
                end
            end

        end
        close(hwait);
        t = round(toc);
        fprintf('%s: Folder 3 parsing done. Elapsed time = %i seconds.\n', items{ii}, t);
        
        % White/black list
        tic
        [fl3_temp, unlisted] = blackwhitelist(fl3_temp, blacklist, whitelist);
        
        % Document mice  that are not in black or white list
        unlisted_mice(ulm_ind+1 : ulm_ind+length(unlisted)) = unlisted;
        ulm_ind = ulm_ind + length(unlisted);
        t = round(toc);
        fprintf('%s: Folder 1 black/white listing done. Elapsed time = %i seconds.\n', items{ii},t);
        
        fl3.(items{ii}) = fl3_temp;
    end
end

unlisted_mice = unlisted_mice(1 : ulm_ind);



%% Hashing and MD5
% This part will read from hard drives, but the load is light until the end
% Saving the mat file will probably take ~5 min depending on your file
% numbers

for ii = 1 : length(items)
    if p.rescan_target && isempty(fl1_left.(items{ii}))
        continue;
    end
    
    % =================== FP1 ===================
    % Loading item
    if ~p.rescan_target
        fl1_temp = fl1.(items{ii});
        n1 = length(fl1_temp);
    end
    
    % Folder 1
    if ~p.rescan_target
        tic;
        hwait = waitbar(0, 'Hashing Folder 1');
        for i = 1 : n1
            if mod(i, 1000) == 0
                waitbar(i/n1, hwait, sprintf('%s: Hashing Folder 1: %i/%i', items{ii}, i, n1));
            end
            
            % Hash first 100 byte of data, if the file is more than 1GB large
            % (i.e., likely imaging data)
            if fl1_temp(i).bytes >= p.hashthresh
                fo = fopen(fullfile(fl1_temp(i).folder, fl1_temp(i).name));
                data100 = fread(fo, p.hashbytes);
                fclose(fo);
                sha256 = uint8(sha256hasher.ComputeHash(uint8(data100)));
                hash = dec2hex(sha256);
                fl1_temp(i).hash = hash(:)';
            else
                fl1_temp(i).hash = 'filetoosmall';
            end
            
            % MD5
            tohash = sprintf('%s%s%s%s', fl1_temp(i).name, fl1_temp(i).bytes, fl1_temp(i).mouse, fl1_temp(i).hash);
            fl1_temp(i).md5 = mMD5(tohash);
        end
        close(hwait);
        t = round(toc);
        fprintf('%s: Folder 1 hashing done. Elapsed time = %i seconds.\n', items{ii}, t);
        fl1.(items{ii}) = fl1_temp;
    end
    
    % =================== FP2 ===================
    % Loading item
    if ~p.rescan_source && setup.fp2.enable
        fl2_temp = fl2.(items{ii});
        n2 = length(fl2_temp);
    end
    
    % Folder 2
    if ~p.rescan_source &&setup.fp2.enable
        tic;
        hwait = waitbar(0, 'Hashing Folder 2');
        for i = 1 : n2
            if mod(i, 1000) == 0
                waitbar(i/n2, hwait, sprintf('%s: Hashing Folder 2: %i/%i', items{ii}, i, n2));
            end

            % Hash first 100 byte of data, if the file is more than 1GB large
            % (i.e., likely imaging data)
            if fl2_temp(i).bytes >= p.hashthresh
                fo = fopen(fullfile(fl2_temp(i).folder, fl2_temp(i).name));
                data100 = fread(fo, p.hashbytes);
                fclose(fo);
                sha256 = uint8(sha256hasher.ComputeHash(uint8(data100)));
                hash = dec2hex(sha256);
                fl2_temp(i).hash = hash(:)';
            else
                fl2_temp(i).hash = 'filetoosmall';
            end

            tohash = sprintf('%s%s%s%s', fl2_temp(i).name, fl2_temp(i).bytes, fl2_temp(i).mouse, fl2_temp(i).hash);
            fl2_temp(i).md5 = mMD5(tohash);
        end
        close(hwait);
        t = round(toc);
        fprintf('%s: Folder 2 hashing done. Elapsed time = %i seconds.\n', items{ii}, t);
        fl2.(items{ii}) = fl2_temp;
    end
    
    % =================== FP3 ===================
    % Loading item
    if ~p.rescan_source && setup.fp3.enable
        fl3_temp = fl3.(items{ii});
        n3 = length(fl3_temp);
    end
    
    
    % Folder 3
    if ~p.rescan_source && setup.fp3.enable
        tic;
        hwait = waitbar(0, 'Hashing Folder 3');
        for i = 1 : n3
            if mod(i, 1000) == 0
                waitbar(i/n3, hwait, sprintf('%s: Hashing Folder 3: %i/%i', items{ii}, i, n3));
            end

            % Hash first 100 byte of data, if the file is more than 1GB large
            % (i.e., likely imaging data)
            if fl3_temp(i).bytes >= p.hashthresh
                fo = fopen(fullfile(fl3_temp(i).folder, fl3_temp(i).name));
                data100 = fread(fo, p.hashbytes);
                fclose(fo);
                sha256 = uint8(sha256hasher.ComputeHash(uint8(data100)));
                hash = dec2hex(sha256);
                fl3_temp(i).hash = hash(:)';
            else
                fl3_temp(i).hash = 'filetoosmall';
            end

            tohash = sprintf('%s%s%s%s', fl3_temp(i).name, fl3_temp(i).bytes, fl3_temp(i).mouse, fl3_temp(i).hash);
            fl3_temp(i).md5 = mMD5(tohash);
        end
        close(hwait);
        t = round(toc);
        fprintf('%s: Folder 3 hashing done. Elapsed time = %i seconds.\n', items{ii}, t);
        fl3.(items{ii}) = fl3_temp;
    end
end


tic
if p.rescan_target
    save(fullfile(fp, fout), 'fl1_left', 'fl2', 'fl3', 'unlisted_mice', '-append');
elseif p.rescan_source || p.newscan
    save(fullfile(fp, fout), 'fl1', 'fl2', 'fl3', 'unlisted_mice', '-append');
end
t = toc;
fprintf('Saving done. Elapsed time = %i seconds.\n', round(t))

%% Matching
% In non-target-rescan mode, matching is done by loop through folders 2 and
% 3, and compare them to folder 1
% This part will take a while and it doesn't put any load on hard drive
% until the end
if ~p.rescan_target
    for ii = 1 : length(items)
        % Loading
        fl1_temp = fl1.(items{ii});
        fl2_temp = fl2.(items{ii});
        fl3_temp = fl3.(items{ii});

        n2 = length(fl2_temp);
        n3 = length(fl3_temp);

        % MD5
        MD5_1 = {fl1_temp(:).md5};
        if n2 > 0
            MD5_2 = {fl2_temp(:).md5};
        end
        if n3 > 0
            MD5_3 = {fl3_temp(:).md5};
        end

        % Tracking
        matched = 0;
        
        if setup.fp2.enable
            tic;
            hwait = waitbar(0, 'Matching');
            for i = 1 : n2
                if mod(i, 100) == 0
                    waitbar(i/n2, hwait, sprintf('Matching folder 2 %s: %i/%i, matched %i/%i', items{ii}, i, n2, matched, i));
                end
                imatch = strcmp(MD5_2{i},MD5_1);

                if ~isempty(imatch)
                    % If mathc remove fromm MD5 pool to accelerate future
                    % matching
                    MD5_1(imatch) = [];
                    fl1_temp(imatch) = [];
                    matched = matched + 1;
                end
            end
            close(hwait);
        end
        
        if setup.fp3.enable
            hwait = waitbar(0, 'Matching');
            for i = 1 : n3
                if mod(i, 100) == 0
                    waitbar(i/n3, hwait, sprintf('Matching folder 3 %s: %i/%i, matched %i/%i', items{ii}, i, n3, matched, i));
                end
                imatch = strcmp(MD5_3{i},MD5_1);

                if ~isempty(imatch)
                    % If mathc remove fromm MD5 pool to accelerate future
                    % matching
                    MD5_1(imatch) = [];
                    fl1_temp(imatch) = [];
                    matched = matched + 1;
                end
            end
            close(hwait);
        end
        
        t = round(toc);
        fprintf('%s: Matching done. Elapsed time = %i seconds.\n', items{ii}, t);
        fl1_left.(items{ii}) = fl1_temp;
    end

    tic
    save(fullfile(fp, fout), 'fl1_left', '-append');
    t = toc;
    fprintf('Saving done. Elapsed time = %i seconds.\n', round(t))
end

%% Automoveprep pre-match prep
% This part fills a short-hand path: mouse_folder\date_folder, which can be
% used to compare between files in different servers without being affected
% by root paths.
% The short-hand paths can be used to determine which folder that the file
% will be automatically moved to.

if p.automoveprep
    for ii = 1 : length(items)
        if p.rescan_target && isempty(fl1_left.(items{ii}))
            continue;
        end

        % Loading
        fl1_temp = fl1_left.(items{ii});
        fl2_temp = fl2.(items{ii});
        fl3_temp = fl3.(items{ii});

        n1 = length(fl1_temp);
        n2 = length(fl2_temp);
        n3 = length(fl3_temp);

        fnl1 = length(setup.fp1.(items{ii}));
        fnl2 = length(setup.fp2.(items{ii}));
        fnl3 = length(setup.fp3.(items{ii}));

        % Folder 1
        tic;
        for i = 1 : n1
            % Short hand path
            fl1_temp(i).fpshort = fl1_temp(i).folder(fnl1+1:end);
            
            % Short hand path + file name (used for replacements)
            fl1_temp(i).ffullshort = fullfile(fl1_temp(i).folder(fnl1+1:end), fl1_temp(i).name);
        end
        t = round(toc);
        fprintf('%s: Folder 1 automove preparing done. Elapsed time = %i seconds.\n', items{ii}, t);
        fl1_left.(items{ii}) = fl1_temp;

        % Folder 2
        if setup.fp2.enable
            tic;
            for i = 1 : n2
                % Short hand path
                fl2_temp(i).fpshort = fl2_temp(i).folder(fnl2+1:end);

                % Short hand path + file name (used for replacements)
                fl2_temp(i).ffullshort = fullfile(fl2_temp(i).folder(fnl2+1:end), fl2_temp(i).name);
            end
            t = round(toc);
            fprintf('%s: Folder 2 automove preparing done. Elapsed time = %i seconds.\n', items{ii}, t);
            fl2.(items{ii}) = fl2_temp;
        end
        
        % Folder 3
        if setup.fp3.enable
            tic;
            for i = 1 : n3
                % Short ahand path
                fl3_temp(i).fpshort = fl3_temp(i).folder(fnl3+1:end);

                % Short hand path + file name (used for replacements)
                fl3_temp(i).ffullshort = fullfile(fl3_temp(i).folder(fnl3+1:end), fl3_temp(i).name);
            end
            t = round(toc);
            fprintf('%s: Folder 3 automove preparing done. Elapsed time = %i seconds.\n', items{ii}, t);
            fl3.(items{ii}) = fl3_temp;
        end
    end
end

%% Rescan target and automove prep
% This part does two things:
% 1. In rescan-target mode, it loops through folder 1 (the remainder) and
% compares the content to folders 2 and 3
% 2. In automove prep mode, it will determines the target folders of
% existing files
% In new-scan mode or rescan_source mode, #1 is skipped. These two
% funcitons are only geother for historical reasons and should probably
% be dissociated in the future.

if p.rescan_target || p.automoveprep
    for ii = 1 : length(items)
        % Loading
        fl1_temp = fl1_left.(items{ii});
        n1 = length(fl1_temp);
        
        if setup.fp2.enable
            fl2_temp = fl2.(items{ii});
            n2 = length(fl2_temp);
        else
            n2 = 0;
        end
        
        if setup.fp3.enable
            fl3_temp = fl3.(items{ii});
            n3 = length(fl3_temp);
        else
            n3 = 0;
        end

        if n1 == 0
            continue;
        end

        % Load up MD5 (rescan target only)
        if p.rescan_target
            MD5_1 = {fl1_temp(:).md5};
            if n2 > 0
                MD5_2 = {fl2_temp(:).md5};
            else 
                MD5_2 = {};
            end
            if n3 > 0 
                MD5_3 = {fl3_temp(:).md5};
            else
                MD5_3 = {};
            end
        end
        
        % Load up fpshort ffullshort (short hand paths)
        fpshort_1 = {fl1_temp(:).fpshort};
        ffullshort_1 = {fl1_temp(:).ffullshort};
        
        if n2 > 0
            fpshort_2 = {fl2_temp(:).fpshort};
            ffullshort_2 = {fl2_temp(:).ffullshort};
        else
            fpshort_2 = {};
            ffullshort_2 = {};
            imatch_2 = false;
        end
        if n3 > 0
            fpshort_3 = {fl3_temp(:).fpshort};
            ffullshort_3 = {fl3_temp(:).ffullshort};
        else
            fpshort_3 = {};
            ffullshort_3 = {};
            imatch_3 = false;
        end
        
        % if not rescan target mode, set imatch to false (no MD5 matching
        % will be done here as it's aready done above).
        if ~p.rescan_target
            imatch_2 = false;
            imatch_3 = false;
        end
        
        % Tracking
        matched = 0;
        toreplace = 0;
        tomove = 0;

        tic;
        hwait = waitbar(0, 'Rematching');
        for i = 1 : n1
            if mod(i, 100) == 0
                waitbar(i/n1, hwait, sprintf('%s: %i/%i, Mat/Rep/Mov %i/%i/%i',...
                    items{ii}, i, n1, matched, toreplace, tomove));
            end

            % MD5
            if p.rescan_target
                imatch_2 = strcmp(MD5_2, MD5_1{i});
                imatch_3 = strcmp(MD5_3, MD5_1{i});
            end

            % ffull match (for moving files)
            imatchffull_2 = strcmp(ffullshort_2, ffullshort_1{i});
            imatchffull_3 = strcmp(ffullshort_3, ffullshort_1{i});

            % fpshort match (for replacingfiles)
            imatchfp_2 = strcmp(fpshort_2, fpshort_1{i});
            imatchfp_3 = strcmp(fpshort_3, fpshort_1{i});

            if any(imatch_2) || any(imatch_3)
                % There is a match
                fl1_temp(i).matched = true;
                fl1_temp(i).replace = false;
                fl1_temp(i).move = false;
                matched = matched + 1;
            else
                % No full match
                fl1_temp(i).matched = false;

                if any(imatchffull_2)
                    % Replace file in folder 2
                    fl1_temp(i).replace = true;
                    fl1_temp(i).move = false;
                    fl1_temp(i).replacefp = fl2_temp(imatchffull_2).folder;
                    toreplace = toreplace + 1;

                elseif any(imatchffull_3)
                    % Replace file in folder 3
                    fl1_temp(i).replace = true;
                    fl1_temp(i).move = false;
                    fl1_temp(i).replacefp = fl3_temp(imatchffull_3).folder;
                    toreplace = toreplace + 1;

                else
                    % Not replace
                    fl1_temp(i).replace = false;

                    if any(imatchfp_2)
                        % Moving to folder 2
                        fl1_temp(i).move = true;
                        fl1_temp(i).movefp = fl2_temp(imatchfp_2).folder;
                        tomove = tomove + 1;

                    elseif any(imatchfp_3)
                        % Moving to folder 3
                        fl1_temp(i).move = true;
                        fl1_temp(i).movefp = fl3_temp(imatchfp_3).folder;
                        tomove = tomove + 1;

                    else
                        fl1_temp(i).move = false;
                    end
                end
            end
        end
        fl1_left.(items{ii}) = fl1_temp;
        close (hwait)
    end

    tic
    save(fullfile(fp, fout), 'fl1_left', '-append');
    t = toc;
    fprintf('Saving done. Elapsed time = %i seconds.\n', round(t))
end

%% Report
fid = fopen(fullfile(fp, freport), 'w');

for ii = 1 : length(items)
    % Loading
    fl1_temp = fl1_left.(items{ii});
    
    % Remove matched in the rescan target mode
    if p.rescan_target
        fl1_temp = fl1_temp(~[fl1_temp(:).matched]);
    end
    
    foldersleft = {fl1_temp(:).folder};
    foldersleft = unique(foldersleft);
    miceleft = {fl1_temp(:).mouse};
    miceleft = miceleft(~cellfun('isempty', miceleft));
    miceleft = unique(miceleft);

    fwrite(fid, sprintf('======================================\n'));
    fwrite(fid, sprintf('%s: The following mice are not synced:\n', items{ii}));
    for i = 1 : length(miceleft)
        fwrite(fid, sprintf('%s: %s\n', items{ii}, miceleft{i}));
    end

    fwrite(fid, sprintf('%s: The following folders are not synced:\n', items{ii}));
    for i = 1 : length(foldersleft)
        fwrite(fid, sprintf('%s: %s\n', items{ii}, foldersleft{i}));
    end
    
    fwrite(fid, sprintf('======================================\n'));
    fwrite(fid, sprintf('%s: The following mice are not in black or white list:\n', items{ii}));
    for i = 1 : length(unlisted_mice)
        fwrite(fid, sprintf('%s\n', unlisted_mice{ii}));
    end
end

fclose(fid);

%% Auto move prep report
if p.automoveprep

    fid = fopen(fullfile(fp, fautosync), 'w');

    % Summary
    for ii = 1 : length(items)
        % Loading
        fl1_temp = fl1_left.(items{ii});

        % Numbers
        n1 = length(fl1_temp);

        if n1 == 0
            continue;
        end
        
        % Write report
        nmat = sum([fl1_temp(:).matched]);
        nrep = sum([fl1_temp(:).replace]);
        nmove = sum([fl1_temp(:).move]);

        fwrite(fid, sprintf('%s: Matched %i, To replace %i, To move %i, Residual: %i.\n',...
            items{ii}, nmat, nrep, nmove, n1-nmat-nrep-nmove));

    end

    % Replace
    fwrite(fid, sprintf('=================== Auto Replace ===================\n'));
    for ii = 1 : length(items)
        % Loading
        fl1_temp = fl1_left.(items{ii});

        % Numbers
        n1 = length(fl1_temp);

        if n1 == 0
            continue;
        end

        fl1_temp = fl1_temp([fl1_temp(:).replace] == 1);
        n1rep = length(fl1_temp);

        for i = 1 : n1rep
            fpold = fullfile(fl1_temp(i).folder, fl1_temp(i).name);
            fpnew = fullfile(fl1_temp(i).replacefp, fl1_temp(i).name);
            fwrite(fid, sprintf('%s: %s >> %s\n', items{ii}, fpold, fpnew));
        end
    end

    % Move
    fwrite(fid, sprintf('=================== Auto move ===================\n'));
    for ii = 1 : length(items)
        % Loading
        fl1_temp = fl1_left.(items{ii});

        % Numbers
        n1 = length(fl1_temp);

        if n1 == 0
            continue;
        end

        fl1_temp = fl1_temp([fl1_temp(:).move] == 1);
        n1rep = length(fl1_temp);

        for i = 1 : n1rep
            fpold = fullfile(fl1_temp(i).folder, fl1_temp(i).name);
            fpnew = fullfile(fl1_temp(i).movefp, fl1_temp(i).name);
            fwrite(fid, sprintf('%s: %s >> %s\n', items{ii}, fpold, fpnew));
        end
    end

    fclose(fid);
end
end