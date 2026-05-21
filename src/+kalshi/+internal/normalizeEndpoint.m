function endpoint = normalizeEndpoint(endpoint)
%normalizeEndpoint Normalize a relative Kalshi API endpoint.

    endpoint = string(endpoint);
    endpoint = regexprep(endpoint, "^https?://[^/]+/trade-api/v2", "");
    endpoint = regexprep(endpoint, "^/trade-api/v2", "");

    if ~startsWith(endpoint, "/")
        endpoint = "/" + endpoint;
    end
end
