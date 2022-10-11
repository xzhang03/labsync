%% Initialize (yoav from anastasia to nasquatch)
% clear
% 
% % Paths
% fp1 = 'F:\2p\yoav\'; % Presumed larger folder
% fp2 = 'E:\2p\yoav\'; % Presumed smaller folder
% 
% % Mouse folder name convention
% mousefolder = '\\[A-Z][A-Z][0-9]';
% mousefolder2 = '\yoav\';

% labfpmatch = true;
% sizematch = true;
%% Initialize (yoav from nasquatch to R)
% clear
% 
% % Paths
% fp1 = 'R:\Andermann_Lab_Archive\active\2photon\yoav'; % Presumed larger folder
% fp2 = 'F:\2p\yoav'; % Presumed smaller folder
% 
% % Mouse folder name convention
% mousefolder = '\\[A-Z][A-Z][0-9]';
% mousefolder2 = '\yoav\';
% 
% reportfp = 'D:\User\Stephen\File matching\yoav from nasquatch to R';

% labfpmatch = true;
% sizematch = true;
%% Initialize (Liang from anastasia to R)
clear

% Paths
fp1 = 'R:\Andermann_Lab_Archive\active\2photon\liang'; % Presumed larger folder
fp2 = 'E:\2p\liang'; % Presumed smaller folder

% Mouse folder name convention
mousefolder = '\\[A-Z][A-Z][0-9]';
mousefolder2 = '\liang\';

reportfp = 'D:\User Folders\Stephen\File matching\liang from anastasia to R';

labfpmatch = false;
sizematch = false;

%% Report
reportfn = sprintf('Redundancy report %s.txt', datestr(now,29));
matfn = sprintf('Redundancy report %s.mat', datestr(now,29));

freport = fopen(fullfile(reportfp, reportfn), 'w');
fwrite(freport, sprintf('Redundancy report %s\n', datestr(now)));
fwrite(freport, sprintf('Folder 1: %s\n', fp1));
fwrite(freport, sprintf('Folder 2: %s\n', fp2));
fwrite(freport, sprintf('============================================\n'));
fclose(freport);

%% Target folders
% Scan
tic;
fl1 = dir(fullfile(fp1,'**','*.*'));
fl2 = dir(fullfile(fp2,'**','*.*'));
t = round(toc);

freport = fopen(fullfile(reportfp, reportfn), 'a');
fwrite(freport, sprintf('Dir done. Elapsed time = %i seconds.\n', t));
fclose(freport);

% Remove folders
fl1 = fl1(~[fl1.isdir]);
fl2 = fl2(~[fl2.isdir]);

% Remove thumbs
isthumb = strcmp({fl1(:).name}, 'Thumbs.db');
fl1 = fl1(~isthumb);
isthumb = strcmp({fl2(:).name}, 'Thumbs.db');
fl2 = fl2(~isthumb);

% Remove DS_store
isdsstore = strcmp({fl1(:).name}, '.DS_Store');
fl1 = fl1(~isdsstore);
isdsstore = strcmp({fl2(:).name}, '.DS_Store');
fl2 = fl2(~isdsstore);

% Number of files
n1 = length(fl1);
n2 = length(fl2);

% Hasher
sha256hasher = System.Security.Cryptography.SHA256Managed;
% sha256hasher = System.Security.Cryptography.SHA512Managed;

tic
% Loop to find fullnames in fl1
hwait = waitbar(0, 'Scanning Folder 1');
for i = 1 : n1
    if mod(i, 100) == 0
        waitbar(i/n1, hwait, sprintf('Scanning Folder 1: %i/%i', i, n1));
    end
    
    % Find when mouse folder starts
    mousefolderstart = regexp(fl1(i).folder, mousefolder);
    if length(mousefolderstart) > 1
        mousefolderstart = mousefolderstart(1);
    elseif isempty(mousefolderstart)
        mousefolderstart = regexp(fl1(i).folder, mousefolder2);
        if isempty(mousefolderstart)
            mousefolderstart = 1;
        end
    end
    
    % Generate standard lab path starting with mouse folder
    fl1(i).labfp = fullfile(fl1(i).folder(mousefolderstart:end), fl1(i).name);
    
    % Hash first 100 byte of data, if the file is more than 1GB large
    % (i.e., likely imaging data)
    if fl1(i).bytes >= 10^9
        fo = fopen(fullfile(fl1(i).folder, fl1(i).name));
        data100 = fread(fo, 100);
        fclose(fo);
        sha256 = uint8(sha256hasher.ComputeHash(uint8(data100)));
        hash = dec2hex(sha256);
        fl1(i).hash = hash(:)';
    else
        fl1(i).hash = 'filetoosmall';
    end
end
close(hwait);
t = round(toc);

% Report
freport = fopen(fullfile(reportfp, reportfn), 'a');
fwrite(freport, sprintf('Folder 1 scanning done. Elapsed time = %i seconds.\n', t));
fclose(freport);

% Loop to find fullnames in fl2
tic;
hwait = waitbar(0, 'Scanning Folder 2');
for i = 1 : n2
    if mod(i, 100) == 0
        waitbar(i/n2, hwait, sprintf('Scanning Folder 2: %i/%i', i, n2));
    end
    
    % Find when mouse folder starts
    mousefolderstart = regexp(fl2(i).folder, mousefolder);
    if length(mousefolderstart) > 1
        mousefolderstart = mousefolderstart(1);
    elseif isempty(mousefolderstart)
        mousefolderstart = regexp(fl2(i).folder, mousefolder2);
        if isempty(mousefolderstart)
            mousefolderstart = 1;
        end
    end
    
    % Generate standard lab path starting with mouse folder
    fl2(i).labfp = fullfile(fl2(i).folder(mousefolderstart:end), fl2(i).name);
    
    % Hash first 100 byte of data
    if fl2(i).bytes >= 10^9
        fo = fopen(fullfile(fl2(i).folder, fl2(i).name));
        data100 = fread(fo, 100);
        fclose(fo);
        sha256 = uint8(sha256hasher.ComputeHash(uint8(data100)));
        hash = dec2hex(sha256);
        fl2(i).hash = hash(:)';
    else
        fl2(i).hash = 'filetoosmall';
    end
end
close(hwait);
t = round(toc);

% Report
freport = fopen(fullfile(reportfp, reportfn), 'a');
fwrite(freport, sprintf('Folder 2 scanning done. Elapsed time = %i seconds.\n', t));
fclose(freport);

%% Compare (name, size, hash)
% Initialize
fp1_vec = zeros(n1,1);
fp2_vec = zeros(n2,1);

% Log double matching events
dmatch = cell(n1,1);
tic;

% Report
freport = fopen(fullfile(reportfp, reportfn), 'a');

% Report
fwrite(freport, sprintf('The following files matched the paths of more than 1 files, using the first one:\n'));
fprintf('The following files matched the paths of more than 1 files, using the first one:\n');            
            
% Lab fp cell
if labfpmatch
    fl2_lapfp_cell = {fl2(:).labfp};
else
    fl2_lapfp_cell = {fl2(:).name};
end

% Loop n1
hwait = waitbar(0, 'Scanning Folder 2');
for i = 1 : n1
    if mod(i, 100) == 0
        waitbar(i/n2, hwait, sprintf('Matching folders: %i/%i', i, n1));
    end
    
    % Check fp
    if labfpmatch
        fppass = strcmp(fl1(i).labfp, fl2_lapfp_cell);
    else
        fppass = strcmp(fl1(i).name, fl2_lapfp_cell);
    end
    
    
    if any(fppass)
        % Assume it's 1 to 1 at this point
        i2 = find(fppass);
        
        if length(i2) > 1
            fprintf('%i: %s.\n', i, fl1(i).labfp);
            dmatch{i} = i2;
            i2 = i2(1);
            
            % Report
            fwrite(freport, sprintf('%i: %s.\n', i, fl1(i).labfp));
            
        end
        
        % Check size
        szpass = fl1(i).bytes == fl2(i2).bytes;
        
        % Check hash
        hashpass = strcmp(fl1(i).hash, fl2(i2).hash);
        
        % Mark files as identical if all 3 checks passed
        if szpass && hashpass
            fp1_vec(i) = 1;
            fp2_vec(i2) = 1;
        end
    end
end
close(hwait);
t = round(toc);

% Report
fwrite(freport, sprintf('Matching done. Elapsed time = %i seconds.\n', t));
fclose(freport);

%% Scan the remainder of folder 2
% Remainder
fl2_rem_backscan = fl2(fp2_vec ~= 1);
n2_rem = length(fl2_rem_backscan);
fp2_vec_backscan = zeros(n2_rem, 1);

% Lab fp cellasdfgg
if labfpmatch
    fl1_lapfp_cell = {fl1(:).labfp};
else
    fl1_lapfp_cell = {fl1(:).name};
end

% Log double matching events
dmatch2 = cell(n2_rem,1);
tic;

% Report
freport = fopen(fullfile(reportfp, reportfn), 'a');

% Report
fwrite(freport, sprintf('The following files matched the paths of more than 1 files, using the first one:\n'));
fprintf('The following files matched the paths of more than 1 files, using the first one:\n');            

% Loop n1
hwait = waitbar(0, 'Scanning Folder 2');
for i = 1 : n2_rem
    if mod(i, 100) == 0
        waitbar(i/n2_rem, hwait, sprintf('Matching folders: %i/%i', i, n2_rem));
    end
    
    % Check fp
    if labfpmatch
        fppass = strcmp(fl2_rem_backscan(i).labfp, fl1_lapfp_cell);
    else
        fppass = strcmp(fl2_rem_backscan(i).name, fl1_lapfp_cell);
    end
    
    if any(fppass)
        % Assume it's 1 to 1 at this point
        i2 = find(fppass);
        
        if length(i2) > 1
            fprintf('Backscan %i: %s.\n', i, fl1(i).labfp);
            dmatch2{i} = i2;
            
            % Report
%             fwrite(freport, sprintf('Backscan %i: %s.\n', i, fl1(i).labfp));
            
            bytes = [fl1(i2).bytes];
            hash = {fl1(i2).hash};
        else
            bytes = fl1(i2).bytes;
            hash = fl1(i2).hash;
        end
        
        % Check size
        szpass = any(fl2_rem_backscan(i).bytes == bytes);
        
        % Check hash
        hashpass = any(strcmp(fl2_rem_backscan(i).hash, hash));
        
        % Mark files as identical if all 3 checks passed
        if szpass && hashpass
            fp2_vec_backscan(i) = 1;
            fp1_vec(i2) = 1;
        end
    end
end
close(hwait);
t = round(toc);

% Report
fwrite(freport, sprintf('Matching done. Elapsed time = %i seconds.\n', t));
fclose(freport);
%% Report
% Remainder
fl1_rem = fl1(fp1_vec ~= 1);
fl2_rem = fl2_rem_backscan(fp2_vec_backscan ~= 1);

% Open report
freport = fopen(fullfile(reportfp, reportfn), 'a');

% Write filepath 1 remainders
fwrite(freport, sprintf('============================================\n'));
fwrite(freport, sprintf('Unmatched files in folder 1: \n'));
for i = 1 : length(fl1_rem)
    fwrite(freport, sprintf('%s\\%s\n', fl1_rem(i).folder, fl1_rem(i).name));
end

% Write filepath 2 remainders
fwrite(freport, sprintf('============================================\n'));
fwrite(freport, sprintf('Unmatched files in folder 2: \n'));
for i = 1 : length(fl2_rem)
    fwrite(freport, sprintf('%s\\%s\n', fl2_rem(i).folder, fl2_rem(i).name));
end

% Done
fwrite(freport, sprintf('============================================\n'));
fwrite(freport, 'Done.')
fclose(freport);

save(fullfile(reportfp,matfn), 'dmatch', 'fl1_rem', 'fl2_rem', '-v7.3');