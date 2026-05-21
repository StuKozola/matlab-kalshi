classdef ApiError
    %ApiError Error helpers for Kalshi HTTP responses.

    methods (Static)
        function throw(statusCode, method, url, body)
            %throw Raise a normalized API error with status and response body.
            arguments
                statusCode (1, 1) double
                method (1, 1) string
                url (1, 1) string
                body = []
            end

            details = kalshi.ApiError.bodyToText(body);
            error("kalshi:ApiError", ...
                "Kalshi API request failed (%d) for %s %s: %s", ...
                statusCode, upper(method), url, details);
        end
    end

    methods (Static, Access = private)
        function text = bodyToText(body)
            if isempty(body)
                text = "";
                return
            end

            if ischar(body) || isstring(body)
                text = string(body);
                return
            end

            try
                text = string(jsonencode(body));
            catch
                text = string(evalc("disp(body)"));
            end
        end
    end
end
