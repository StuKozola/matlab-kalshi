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
            data = kalshi.internal.normalizeResponseList(data, "markets");
        end

        function data = getMarketsTable(obj, options)
            %getMarketsTable Return market list results as a MATLAB table.
            arguments
                obj (1, 1) kalshi.Client
                options.SeriesTicker (1, 1) string = ""
                options.Status (1, 1) string = ""
                options.Limit double = []
                options.Cursor (1, 1) string = ""
                options.Query struct = struct()
            end

            response = obj.getMarkets( ...
                SeriesTicker=options.SeriesTicker, ...
                Status=options.Status, ...
                Limit=options.Limit, ...
                Cursor=options.Cursor, ...
                Query=options.Query);
            data = kalshi.toTable(response.markets);
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

        function data = getOrder(obj, orderId)
            %getOrder Retrieve a single order by exchange order ID.
            arguments
                obj (1, 1) kalshi.Client
                orderId (1, 1) string
            end

            data = obj.get("/portfolio/orders/" + orderId, Authenticated=true);
        end

        function order = getOrderByClientOrderId(obj, clientOrderId, options)
            %getOrderByClientOrderId Find an order by locally generated client order ID.
            arguments
                obj (1, 1) kalshi.Client
                clientOrderId (1, 1) string
                options.Status (1, 1) string = ""
                options.Ticker (1, 1) string = ""
                options.Limit (1, 1) double {mustBeInteger, mustBePositive} = 100
                options.MaxPages (1, 1) double {mustBeInteger, mustBePositive} = 20
            end

            query = struct( ...
                "status", options.Status, ...
                "ticker", options.Ticker, ...
                "limit", options.Limit);
            orders = obj.getAll("/portfolio/orders", "orders", ...
                Query=kalshi.internal.dropEmptyFields(query), ...
                Authenticated=true, ...
                MaxPages=options.MaxPages);
            orders = kalshi.normalizeList(orders);
            order = [];

            for k = 1:numel(orders)
                candidate = orders{k};
                if isfield(candidate, "client_order_id") && string(candidate.client_order_id) == clientOrderId
                    order = candidate;
                    return
                end
            end
        end

        function data = getOrderQueuePosition(obj, orderId)
            %getOrderQueuePosition Retrieve price-time queue position for one resting order.
            arguments
                obj (1, 1) kalshi.Client
                orderId (1, 1) string
            end

            data = obj.get("/portfolio/orders/" + orderId + "/queue_position", Authenticated=true);
        end

        function data = getQueuePositions(obj, options)
            %getQueuePositions Retrieve queue positions for resting orders.
            arguments
                obj (1, 1) kalshi.Client
                options.MarketTickers string = strings(0, 1)
                options.EventTicker (1, 1) string = ""
                options.Subaccount double = []
            end

            query = struct( ...
                "market_tickers", strjoin(options.MarketTickers(:)', ","), ...
                "event_ticker", options.EventTicker, ...
                "subaccount", options.Subaccount);
            data = obj.get("/portfolio/orders/queue_positions", ...
                Query=kalshi.internal.dropEmptyFields(query), Authenticated=true);
            data = kalshi.internal.normalizeResponseList(data, "queue_positions");
        end

        function data = getPositions(obj, options)
            arguments
                obj (1, 1) kalshi.Client
                options.Query struct = struct()
            end

            data = obj.get("/portfolio/positions", Query=options.Query, Authenticated=true);
            data = kalshi.internal.normalizeResponseList(data, "market_positions");
            data = kalshi.internal.normalizeResponseList(data, "event_positions");
        end

        function data = getPositionsTable(obj, options)
            %getPositionsTable Return market position results as a MATLAB table.
            arguments
                obj (1, 1) kalshi.Client
                options.Query struct = struct()
            end

            response = obj.getPositions(Query=options.Query);
            if isfield(response, "market_positions")
                data = kalshi.toTable(response.market_positions);
            else
                data = table();
            end
        end

        function data = getOrders(obj, options)
            arguments
                obj (1, 1) kalshi.Client
                options.Query struct = struct()
            end

            data = obj.get("/portfolio/orders", Query=options.Query, Authenticated=true);
            data = kalshi.internal.normalizeResponseList(data, "orders");
        end

        function data = getOrdersTable(obj, options)
            %getOrdersTable Return order list results as a MATLAB table.
            arguments
                obj (1, 1) kalshi.Client
                options.Query struct = struct()
            end

            response = obj.getOrders(Query=options.Query);
            data = kalshi.toTable(response.orders);
        end

        function data = getFills(obj, options)
            arguments
                obj (1, 1) kalshi.Client
                options.Query struct = struct()
            end

            data = obj.get("/portfolio/fills", Query=options.Query, Authenticated=true);
            data = kalshi.internal.normalizeResponseList(data, "fills");
        end

        function data = getFillsTable(obj, options)
            %getFillsTable Return fill list results as a MATLAB table.
            arguments
                obj (1, 1) kalshi.Client
                options.Query struct = struct()
            end

            response = obj.getFills(Query=options.Query);
            data = kalshi.toTable(response.fills);
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
                options.ExchangeIndex (1, 1) double {mustBeInteger, mustBeNonnegative} = 0
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
                "order_group_id", options.OrderGroupId, ...
                "exchange_index", options.ExchangeIndex);
            data = obj.post("/portfolio/events/orders", ...
                kalshi.internal.dropEmptyFields(body), Authenticated=true);
        end

        function data = cancelOrder(obj, orderId, options)
            arguments
                obj (1, 1) kalshi.Client
                orderId (1, 1) string
                options.Subaccount double = []
                options.ExchangeIndex double = []
            end

            obj.assertTradingAllowed();
            query = struct( ...
                "subaccount", options.Subaccount, ...
                "exchange_index", options.ExchangeIndex);
            data = obj.delete("/portfolio/events/orders/" + orderId, ...
                Query=kalshi.internal.dropEmptyFields(query), Authenticated=true);
        end

        function data = batchCancelOrders(obj, orderIds, options)
            %batchCancelOrders Cancel multiple event-market orders through the V2 endpoint.
            arguments
                obj (1, 1) kalshi.Client
                orderIds string
                options.Subaccount (1, 1) double {mustBeInteger, mustBeNonnegative} = 0
                options.ExchangeIndex (1, 1) double {mustBeInteger, mustBeNonnegative} = 0
            end

            obj.assertTradingAllowed();
            orderIds = orderIds(:);
            orders = repmat(struct( ...
                "order_id", "", ...
                "subaccount", options.Subaccount, ...
                "exchange_index", options.ExchangeIndex), numel(orderIds), 1);

            for k = 1:numel(orderIds)
                orders(k).order_id = orderIds(k);
            end

            body = struct("orders", orders);
            data = obj.delete("/portfolio/events/orders/batched", ...
                Body=body, Authenticated=true);
            data = kalshi.internal.normalizeResponseList(data, "orders");
        end

        function data = cancelAllOrders(obj, options)
            %cancelAllOrders Cancel all resting orders matching the supplied filters.
            arguments
                obj (1, 1) kalshi.Client
                options.Ticker (1, 1) string = ""
                options.Limit (1, 1) double {mustBeInteger, mustBePositive} = 100
                options.MaxPages (1, 1) double {mustBeInteger, mustBePositive} = 20
                options.Subaccount (1, 1) double {mustBeInteger, mustBeNonnegative} = 0
                options.ExchangeIndex (1, 1) double {mustBeInteger, mustBeNonnegative} = 0
            end

            obj.assertTradingAllowed();
            query = struct("status", "resting", "ticker", options.Ticker, "limit", options.Limit);
            orders = obj.getAll("/portfolio/orders", "orders", ...
                Query=kalshi.internal.dropEmptyFields(query), ...
                Authenticated=true, ...
                MaxPages=options.MaxPages);
            orders = kalshi.normalizeList(orders);
            orderIds = strings(0, 1);

            for k = 1:numel(orders)
                order = orders{k};
                if isfield(order, "order_id")
                    orderIds(end + 1, 1) = string(order.order_id); %#ok<AGROW>
                end
            end

            if isempty(orderIds)
                data = struct("orders", {cell(0, 1)});
                return
            end

            data = obj.batchCancelOrders(orderIds, ...
                Subaccount=options.Subaccount, ...
                ExchangeIndex=options.ExchangeIndex);
        end
    end

    methods (Access = private)
        function data = request(obj, method, endpoint, query, body, authenticated)
            maxAttempts = obj.Config.MaxRetries + 1;

            for attempt = 1:maxAttempts
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
                    "Authenticated", authenticated, ...
                    "Attempt", attempt);

                try
                    data = obj.Transport(requestData);
                    return
                catch exception
                    if attempt >= maxAttempts || ~isRetryableException(exception, method)
                        rethrow(exception)
                    end

                    delay = retryDelay(obj.Config, attempt);
                    if delay > 0
                        pause(delay);
                    end
                end
            end
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

function tf = isRetryableException(exception, method)
    statusCode = statusCodeFromException(exception);
    retryableGetStatus = [429 500 502 503 504];

    if upper(method) == "GET"
        tf = any(statusCode == retryableGetStatus);
    else
        tf = statusCode == 429;
    end
end

function statusCode = statusCodeFromException(exception)
    tokens = regexp(exception.identifier, "kalshi:ApiError:Status(?<statusCode>\d+)$", "names");
    if isempty(tokens)
        statusCode = NaN;
    else
        statusCode = str2double(tokens.statusCode);
    end
end

function delay = retryDelay(config, attempt)
    delay = config.RetryBaseDelay * 2^(attempt - 1);
    delay = min(delay, config.RetryMaxDelay);
end
