classdef PagedOrdersTransport < handle
    %PagedOrdersTransport Test double for paginated order responses.

    properties
        Requests = {}
    end

    methods
        function response = handleRequest(obj, request)
            obj.Requests{end + 1} = request;

            if contains(request.Url, "cursor=next")
                response = struct( ...
                    "orders", struct( ...
                        "order_id", "order-2", ...
                        "client_order_id", "client-2"), ...
                    "cursor", "");
            else
                response = struct( ...
                    "orders", struct( ...
                        "order_id", "order-1", ...
                        "client_order_id", "client-1"), ...
                    "cursor", "next");
            end
        end
    end
end
