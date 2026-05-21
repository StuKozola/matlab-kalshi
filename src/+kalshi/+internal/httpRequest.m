function data = httpRequest(request)
%httpRequest Execute a Kalshi HTTP request using matlab.net.http.

    import matlab.net.URI
    import matlab.net.http.HeaderField
    import matlab.net.http.HTTPOptions
    import matlab.net.http.MessageBody
    import matlab.net.http.RequestMessage
    import matlab.net.http.RequestMethod

    method = upper(string(request.Method));
    headers = makeHeaderFields(request.Headers);
    body = [];

    if isfield(request, "Body") && ~isempty(request.Body)
        headers(end + 1) = HeaderField("Content-Type", "application/json");
        body = MessageBody(jsonencode(request.Body));
    end

    response = RequestMessage(methodEnum(method), headers, body).send( ...
        URI(char(request.Url)), ...
        HTTPOptions(ConnectTimeout=request.Timeout));

    statusCode = double(response.StatusCode);
    if statusCode >= 400
        kalshi.ApiError.throw(statusCode, method, request.Url, response.Body.Data);
    end

    data = response.Body.Data;
end

function headers = makeHeaderFields(headerCells)
    import matlab.net.http.HeaderField

    headers = HeaderField.empty();
    if isempty(headerCells)
        return
    end

    for k = 1:size(headerCells, 1)
        headers(end + 1) = HeaderField(headerCells{k, 1}, headerCells{k, 2}); %#ok<AGROW>
    end
end

function method = methodEnum(value)
    import matlab.net.http.RequestMethod

    switch upper(value)
        case "GET"
            method = RequestMethod.GET;
        case "POST"
            method = RequestMethod.POST;
        case "PUT"
            method = RequestMethod.PUT;
        case "PATCH"
            method = RequestMethod.PATCH;
        case "DELETE"
            method = RequestMethod.DELETE;
        otherwise
            error("kalshi:Http:UnsupportedMethod", ...
                "Unsupported HTTP method: %s", value);
    end
end
