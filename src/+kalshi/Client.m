classdef Client < handle
    %Client MATLAB client for the Kalshi Trade API.

    properties (SetAccess = private)
        Config (1, 1) kalshi.Config
    end

    properties
        Signer = []
        Transport = []
    end

    methods
        function obj = Client(config, options)
            arguments
                config (1, 1) kalshi.Config = kalshi.Config.demo()
                options.Signer = []
                options.Transport = []
            end

            obj.Config = config;
            obj.Signer = options.Signer;

            if isempty(options.Transport)
                obj.Transport = @kalshi.internal.httpRequest;
            else
                obj.Transport = options.Transport;
            end
        end

        function data = get(obj, endpoint, options)
            %get Issue a GET request against a relative Kalshi endpoint.
            arguments
                obj (1, 1) kalshi.Client
                endpoint (1, 1) string
                options.Query struct = struct()
                options.Authenticated (1, 1) logical = false
            end

            data = obj.request("GET", endpoint, options.Query, [], options.Authenticated);
        end

        function data = post(obj, endpoint, body, options)
            %post Issue a JSON POST request against a relative Kalshi endpoint.
            arguments
                obj (1, 1) kalshi.Client
                endpoint (1, 1) string
                body = struct()
                options.Query struct = struct()
                options.Authenticated (1, 1) logical = true
            end

            data = obj.request("POST", endpoint, options.Query, body, options.Authenticated);
        end

        function data = delete(obj, endpoint, options)
            %delete Issue a DELETE request against a relative Kalshi endpoint.
            arguments
                obj (1, 1) kalshi.Client
                endpoint (1, 1) string
                options.Query struct = struct()
                options.Body = []
                options.Authenticated (1, 1) logical = true
            end

            data = obj.request("DELETE", endpoint, options.Query, options.Body, options.Authenticated);
        end

        function items = getAll(obj, endpoint, collectionField, options)
            %getAll Retrieve all pages from a cursor-paginated list endpoint.
            arguments
                obj (1, 1) kalshi.Client
                endpoint (1, 1) string
                collectionField (1, 1) string
                options.Query struct = struct()
                options.Authenticated (1, 1) logical = false
                options.MaxPages (1, 1) double {mustBeInteger, mustBePositive} = 100
            end

            query = options.Query;
            items = [];

            for page = 1:options.MaxPages
                response = obj.get(endpoint, Query=query, Authenticated=options.Authenticated);
                if isfield(response, collectionField)
                    items = appendItems(items, response.(collectionField));
                end

                if ~isfield(response, "cursor") || strlength(string(response.cursor)) == 0
                    return
                end

                query.cursor = string(response.cursor);
            end

            error("kalshi:Client:PaginationLimitExceeded", ...
                "Pagination limit exceeded for endpoint %s.", endpoint);
        end

        function data = getSeries(obj, seriesTicker)
            arguments
                obj (1, 1) kalshi.Client
                seriesTicker (1, 1) string
            end

            data = obj.get("/series/" + seriesTicker);
        end

        function data = getSeriesList(obj, options)
            arguments
                obj (1, 1) kalshi.Client
                options.Query struct = struct()
            end

            data = obj.get("/series", Query=options.Query);
        end

        function data = getEvents(obj, options)
            arguments
                obj (1, 1) kalshi.Client
                options.Query struct = struct()
            end

            data = obj.get("/events", Query=options.Query);
        end

        function data = getEvent(obj, eventTicker)
            arguments
                obj (1, 1) kalshi.Client
                eventTicker (1, 1) string
            end

            data = obj.get("/events/" + eventTicker);
        end

        function data = getMarkets(obj, options)
            arguments
                obj (1, 1) kalshi.Client
                options.SeriesTicker (1, 1) string = ""
                options.Status (1, 1) string = ""
                options.Limit double = []
                options.Cursor (1, 1) string = ""
                options.Query struct = struct()
            end

            query = options.Query;
            query.series_ticker = options.SeriesTicker;
            query.status = options.Status;
            query.limit = options.Limit;
            query.cursor = options.Cursor;
            data = obj.get("/markets", Query=kalshi.internal.dropEmptyFields(query));
        end

        function data = getMarket(obj, ticker)
            arguments
                obj (1, 1) kalshi.Client
                ticker (1, 1) string
            end

            data = obj.get("/markets/" + ticker);
        end

        function data = getOrderbook(obj, ticker, options)
            arguments
                obj (1, 1) kalshi.Client
                ticker (1, 1) string
                options.Depth double = []
            end

            query = struct("depth", options.Depth);
            data = obj.get("/markets/" + ticker + "/orderbook", ...
                Query=kalshi.internal.dropEmptyFields(query));
        end

        function data = getTrades(obj, options)
            arguments
                obj (1, 1) kalshi.Client
                options.Query struct = struct()
            end

            data = obj.get("/markets/trades", Query=options.Query);
        end

        function data = getBalance(obj)
            data = obj.get("/portfolio/balance", Authenticated=true);
        end

        function data = getPositions(obj, options)
            arguments
                obj (1, 1) kalshi.Client
                options.Query struct = struct()
            end

            data = obj.get("/portfolio/positions", Query=options.Query, Authenticated=true);
        end

        function data = getOrders(obj, options)
            arguments
                obj (1, 1) kalshi.Client
                options.Query struct = struct()
            end

            data = obj.get("/portfolio/orders", Query=options.Query, Authenticated=true);
        end

        function data = getFills(obj, options)
            arguments
                obj (1, 1) kalshi.Client
                options.Query struct = struct()
            end

            data = obj.get("/portfolio/fills", Query=options.Query, Authenticated=true);
        end

        function data = getApiLimits(obj)
            data = obj.get("/account/api_limits", Authenticated=true);
        end

        function data = createOrder(obj, ticker, clientOrderId, side, count, price, options)
            %createOrder Submit an event-market order using Kalshi's V2 endpoint.
            arguments
                obj (1, 1) kalshi.Client
                ticker (1, 1) string
                clientOrderId (1, 1) string
                side (1, 1) string {mustBeMember(side, ["bid", "ask"])}
                count
                price
                options.TimeInForce (1, 1) string {mustBeMember(options.TimeInForce, ["fill_or_kill", "good_till_canceled", "immediate_or_cancel"])} = "good_till_canceled"
                options.SelfTradePreventionType (1, 1) string {mustBeMember(options.SelfTradePreventionType, ["taker_at_cross", "maker"])} = "taker_at_cross"
                options.ExpirationTime double = []
                options.PostOnly (1, 1) logical = false
                options.CancelOrderOnPause (1, 1) logical = true
                options.ReduceOnly (1, 1) logical = false
                options.Subaccount (1, 1) double {mustBeInteger, mustBeNonnegative} = 0
                options.OrderGroupId (1, 1) string = ""
            end

            obj.assertTradingAllowed();

            body = struct( ...
                "ticker", ticker, ...
                "client_order_id", clientOrderId, ...
                "side", side, ...
                "count", kalshi.formatCount(count), ...
                "price", kalshi.formatPrice(price), ...
                "time_in_force", options.TimeInForce, ...
                "self_trade_prevention_type", options.SelfTradePreventionType, ...
                "expiration_time", options.ExpirationTime, ...
                "post_only", options.PostOnly, ...
                "cancel_order_on_pause", options.CancelOrderOnPause, ...
                "reduce_only", options.ReduceOnly, ...
                "subaccount", options.Subaccount, ...
                "order_group_id", options.OrderGroupId);
            data = obj.post("/portfolio/events/orders", ...
                kalshi.internal.dropEmptyFields(body), Authenticated=true);
        end

        function data = cancelOrder(obj, orderId)
            arguments
                obj (1, 1) kalshi.Client
                orderId (1, 1) string
            end

            obj.assertTradingAllowed();
            data = obj.delete("/portfolio/events/orders/" + orderId, Authenticated=true);
        end
    end

    methods (Access = private)
        function data = request(obj, method, endpoint, query, body, authenticated)
            url = kalshi.internal.buildUrl(obj.Config.BaseUrl, endpoint, query);
            headers = {};

            if authenticated
                signPath = kalshi.AuthSigner.requestPath(obj.Config.BaseUrl, endpoint);
                headers = obj.ensureSigner().createHeaders(method, signPath);
            end

            requestData = struct( ...
                "Method", upper(method), ...
                "Url", url, ...
                "Endpoint", kalshi.internal.normalizeEndpoint(endpoint), ...
                "Query", query, ...
                "Headers", {headers}, ...
                "Body", body, ...
                "Timeout", obj.Config.Timeout, ...
                "Authenticated", authenticated);

            data = obj.Transport(requestData);
        end

        function signer = ensureSigner(obj)
            if isempty(obj.Signer)
                obj.Signer = kalshi.AuthSigner.fromConfig(obj.Config);
            end

            signer = obj.Signer;
        end

        function assertTradingAllowed(obj)
            if obj.Config.Environment == "prod" && ~obj.Config.EnableProductionTrading
                error("kalshi:Client:ProductionTradingDisabled", ...
                    "Production trading requires Config.EnableProductionTrading=true.");
            end
        end
    end
end

function items = appendItems(items, newItems)
    if isempty(items)
        items = newItems;
        return
    end

    items = [items; newItems(:)];
end
