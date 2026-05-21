function url = buildUrl(baseUrl, endpoint, query)
%buildUrl Build a Kalshi REST URL with encoded query parameters.

    arguments
        baseUrl (1, 1) string
        endpoint (1, 1) string
        query struct = struct()
    end

    [endpoint, endpointQuery] = splitEndpoint(endpoint);
    query = mergeStructs(endpointQuery, query);
    url = regexprep(baseUrl, "/+$", "") + kalshi.internal.normalizeEndpoint(endpoint);
    queryText = kalshi.internal.encodeQuery(query);

    if strlength(queryText) > 0
        url = url + "?" + queryText;
    end
end

function [endpoint, query] = splitEndpoint(endpoint)
    pieces = split(string(endpoint), "?");
    endpoint = pieces(1);
    query = struct();

    if numel(pieces) < 2 || strlength(pieces(2)) == 0
        return
    end

    pairs = split(pieces(2), "&");
    for k = 1:numel(pairs)
        nameValue = split(pairs(k), "=");
        if numel(nameValue) >= 2
            query.(matlab.lang.makeValidName(nameValue(1))) = nameValue(2);
        end
    end
end

function out = mergeStructs(primary, secondary)
    out = primary;
    names = fieldnames(secondary);
    for k = 1:numel(names)
        out.(names{k}) = secondary.(names{k});
    end
end
