%% Check MD5 mex file
if exist('mMD5.mexw64', 'file')
    info = dir('mMD5.mexw64');
    fprintf('MD5 Mex file compiled on %s.\n', info.date);
    recompile = input('Recompile? (1 = yes, 0 = no): ') == 1;
else
    fprintf('MD5 Mex file not compiled.\n');
    recompile = true;
end
if recompile
    fprintf('Compiling MD5 Mex file... ');
    mex('mMD5.c');
    fprintf('Done.\n');
end

%% Check jsons
% Setup
if ~exist('setup.json', 'file')
    fprintf('Setup.json is not found.\n');
else
    fprintf('Setup.json is found');
    testjson = loadsyncsetup('setup.json');
    fprintf(' and tested.\n');
end

% whitelist
if ~exist('whitelist.json', 'file')
    fprintf('whitelist.json is not found.\n');
else
    fprintf('whitelist.json is found');
    testjson = loadsyncsetup('whitelist.json');
    fprintf(' and tested.\n');
end

% Blacklist
if ~exist('blacklist.json', 'file')
    fprintf('blacklist.json is not found.\n');
else
    fprintf('blacklist.json is found');
    testjson = loadsyncsetup('blacklist.json');
    fprintf(' and tested.\n');
end

%% Check setup
% Load setup
setup = loadsyncsetup();

% Items
items = setup.items;

for i = 1 : length(items)
    % Current item
    item_curr = items{i};
    
    % Check paths fp1
    pass = exist(setup.fp1.(item_curr), 'dir');
    if pass 
        fprintf('fp1.%s path found.\n', item_curr); 
    else
        fprintf('*fp1.%s path not found.*\n', item_curr)
    end
    
    % Check fp2
    if setup.fp2.enable
        pass = exist(setup.fp2.(item_curr), 'dir');
        if pass 
            fprintf('fp2.%s path found.\n', item_curr); 
        else
            fprintf('*fp2.%s path not found.*\n', item_curr)
        end
    end
    
    % Check fp3
    if setup.fp3.enable
        pass = exist(setup.fp3.(item_curr), 'dir');
        if pass 
            fprintf('fp3.%s path found.\n', item_curr); 
        else
            fprintf('*fp3.%s path not found.*\n', item_curr)
        end
    end
end
