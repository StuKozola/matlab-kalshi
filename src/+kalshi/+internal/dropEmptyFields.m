function value = dropEmptyFields(value)
%dropEmptyFields Remove empty fields from a scalar struct.

    names = fieldnames(value);
    for k = 1:numel(names)
        fieldValue = value.(names{k});
        if isempty(fieldValue) || ...
                ((isstring(fieldValue) || ischar(fieldValue)) && strlength(string(fieldValue)) == 0)
            value = rmfield(value, names{k});
        end
    end
end
