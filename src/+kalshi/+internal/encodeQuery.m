function queryText = encodeQuery(query)
%encodeQuery Encode a scalar struct as a URL query string.

    arguments
        query struct = struct()
    end

    names = fieldnames(query);
    parts = strings(0, 1);

    for k = 1:numel(names)
        value = query.(names{k});
        if shouldOmit(value)
            continue
        end

        values = normalizeValues(value);
        for n = 1:numel(values)
            parts(end + 1, 1) = kalshi.internal.urlEncode(names{k}) + "=" + ...
                kalshi.internal.urlEncode(values(n)); %#ok<AGROW>
        end
    end

    queryText = strjoin(parts, "&");
end

function tf = shouldOmit(value)
    tf = isempty(value) || ...
        ((isstring(value) || ischar(value)) && all(strlength(string(value)) == 0));
end

function values = normalizeValues(value)
    if isstring(value) || ischar(value)
        values = string(value);
    elseif isnumeric(value)
        values = string(value);
    elseif islogical(value)
        values = lower(string(value));
    elseif isdatetime(value)
        values = string(value, "yyyy-MM-dd'T'HH:mm:ssXXX");
    elseif iscell(value)
        values = string(value);
    else
        values = string(value);
    end

    values = values(:);
end
