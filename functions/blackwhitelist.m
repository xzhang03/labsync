function [filelist, unlisted] = blackwhitelist(filelist, blacklist, whitelist)
%blackwhitelist applies black and white list to filelists
% White list = keep, black list = throw, unlisted mice are also thrown 
% Black list takes priority if conflict, 


% White list all
if whitelist.whitelist_all
    unlisted = {};
    return;
end

%% By mice
mice = {filelist(:).mouse};
wind = ismember(mice, whitelist.mice);
bind = ismember(mice, blacklist.mice);

% Output list
filelist = filelist(wind & ~bind);

% Find mice that are missing from both lists
umice = unique(mice);
uwind = ismember(umice, whitelist.mice);
ubind = ismember(umice, blacklist.mice);
unlisted = umice(~uwind & ~ubind);

end

