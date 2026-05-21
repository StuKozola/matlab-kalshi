function clientOrderId = makeClientOrderId(prefix)
%makeClientOrderId Create a unique client order ID.

    arguments
        prefix (1, 1) string = "matlab"
    end

    uuid = string(java.util.UUID.randomUUID());
    clientOrderId = prefix + "-" + uuid;
end
