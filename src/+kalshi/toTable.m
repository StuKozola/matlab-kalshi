function value = toTable(items)
%toTable Convert a Kalshi struct/cell response list into a table.

    items = kalshi.normalizeList(items);
    fieldNames = collectFieldNames(items);
    value = table();

    for k = 1:numel(fieldNames)
        name = fieldNames(k);
        column = collectColumn(items, name);
        value.(name) = normalizeColumn(column);
    end
end

function fieldNames = collectFieldNames(items)
    fieldNames = strings(0, 1);

    for k = 1:numel(items)
        if isstruct(items{k})
            fieldNames = union(fieldNames, string(fieldnames(items{k})), "stable");
        end
    end
end

function column = collectColumn(items, name)
    column = cell(numel(items), 1);

    for k = 1:numel(items)
        item = items{k};
        if isstruct(item) && isfield(item, name)
            column{k} = item.(name);
        else
            column{k} = [];
        end
    end
end

function column = normalizeColumn(values)
    if all(cellfun(@isStringScalarLike, values))
        column = strings(numel(values), 1);
        for k = 1:numel(values)
            if isempty(values{k})
                column(k) = missing;
            else
                column(k) = string(values{k});
            end
        end
    elseif all(cellfun(@isNumericScalarLike, values))
        column = NaN(numel(values), 1);
        for k = 1:numel(values)
            if ~isempty(values{k})
                column(k) = double(values{k});
            end
        end
    elseif all(cellfun(@isLogicalScalarLike, values))
        column = false(numel(values), 1);
        for k = 1:numel(values)
            if ~isempty(values{k})
                column(k) = logical(values{k});
            end
        end
    else
        column = values;
    end
end

function tf = isStringScalarLike(value)
    tf = isempty(value) || ischar(value) || (isstring(value) && isscalar(value));
end

function tf = isNumericScalarLike(value)
    tf = isempty(value) || (isnumeric(value) && isscalar(value));
end

function tf = isLogicalScalarLike(value)
    tf = isempty(value) || (islogical(value) && isscalar(value));
end
