function items = normalizeList(value)
%normalizeList Normalize heterogeneous JSON arrays to an N-by-1 cell array.

    if nargin == 0 || isempty(value)
        items = cell(0, 1);
    elseif iscell(value)
        items = value(:);
    elseif isstruct(value)
        items = num2cell(value(:));
    else
        items = {value};
    end
end
