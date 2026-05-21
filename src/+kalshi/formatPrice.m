function value = formatPrice(value)
%formatPrice Format a Kalshi fixed-point dollar price string.

    if isstring(value) || ischar(value)
        value = string(value);
        return
    end

    validateattributes(value, {'numeric'}, {'scalar', 'real', '>=', 0, '<=', 1});
    value = string(compose("%.4f", value));
end
