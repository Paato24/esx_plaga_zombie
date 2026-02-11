local function normalizeText(text)
    if not text then
        return ""
    end

    return text:gsub("^%s+", ""):gsub("%s+$", "")
end

return {
    normalizeText = normalizeText,
}
