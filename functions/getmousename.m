function name = getmousename ( str, nameformats)
%getmousename parses mouse name from file name or folder name

if iscell(nameformats)
    % Multiple input name formats
    done = false;
    ind = 0;
    n = length(nameformats);
    while ~done
        ind = ind + 1;
        
        % Find expression
        [m1, m2] = regexp(str, nameformats{ind});
        l = length(m1);
        
        if l > 1
            % Multiple matches
            m1 = m1(1);
            m2 = m2(1);
            name = str(m1:m2);
            done = true;
        elseif l == 1
            % Single match
            name = str(m1:m2);
            done = true;
        end
        
        % No match
        if ~done && ind == n
            name = 'unknown';
            done = true;
        end
    end
else
    % Single possible name
    % Find expression
    [m1, m2] = regexp(str, nameformats);
    
    l = length(m1);
    if l > 1
        % Multiple matches
        m1 = m1(1);
        m2 = m2(1);
        name = str(m1:m2);
    elseif l == 1
        % Single match
        name = str(m1:m2);
    else
        % No match
        name = 'unknown';
    end
end
                
end

