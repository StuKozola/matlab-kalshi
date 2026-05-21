function value = formatCount(value)
%formatCount Format a Kalshi fixed-point contract count string.

    if isstring(value) || ischar(value)
        value = string(value);
        return
    end

    validateattributes(value, {'numeric'}, {'scalar', 'real', '>=', 0});
    value = string(compose("%.2f", value));
end
