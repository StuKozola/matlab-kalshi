function response = normalizeResponseList(response, fieldName)
%normalizeResponseList Normalize a response list field when present.

    if isstruct(response) && isfield(response, fieldName)
        response.(fieldName) = kalshi.normalizeList(response.(fieldName));
    end
end
