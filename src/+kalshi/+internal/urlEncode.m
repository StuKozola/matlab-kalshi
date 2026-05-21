function encoded = urlEncode(value)
%urlEncode Percent-encode a string for URL query use.

    encoded = string(java.net.URLEncoder.encode(char(string(value)), "UTF-8"));
    encoded = replace(encoded, "+", "%20");
end
