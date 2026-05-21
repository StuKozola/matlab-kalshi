function items = headerCellsToItems(headers)
%headerCellsToItems Convert N-by-2 header cells into JSON-friendly structs.

    items = repmat(struct("name", "", "value", ""), size(headers, 1), 1);
    for k = 1:size(headers, 1)
        items(k).name = string(headers{k, 1});
        items(k).value = string(headers{k, 2});
    end
end
