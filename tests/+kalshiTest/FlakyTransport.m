classdef FlakyTransport < handle
    %FlakyTransport Test double that fails before returning a request.

    properties
        FailuresBeforeSuccess (1, 1) double {mustBeInteger, mustBeNonnegative} = 1
        ErrorIdentifier (1, 1) string = "kalshi:ApiError:Status429"
        Attempts (1, 1) double {mustBeInteger, mustBeNonnegative} = 0
    end

    methods
        function obj = FlakyTransport(options)
            arguments
                options.FailuresBeforeSuccess (1, 1) double {mustBeInteger, mustBeNonnegative} = 1
                options.ErrorIdentifier (1, 1) string = "kalshi:ApiError:Status429"
            end

            obj.FailuresBeforeSuccess = options.FailuresBeforeSuccess;
            obj.ErrorIdentifier = options.ErrorIdentifier;
        end

        function response = handleRequest(obj, request)
            obj.Attempts = obj.Attempts + 1;

            if obj.Attempts <= obj.FailuresBeforeSuccess
                error(obj.ErrorIdentifier, "Simulated retryable HTTP failure.");
            end

            response = request;
            response.Attempts = obj.Attempts;
        end
    end
end
