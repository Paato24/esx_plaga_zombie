local Demo = {}

local config = {
    mode = "test",
    prefix = "BK",
}

function Demo.greet(playerName)
    if not playerName or playerName == "" then
        return "Hola, invitado"
    end

    return ("Hola, %s"):format(playerName)
end

function Demo.buildCode(playerName)
    local safeName = playerName or "invitado"
    return ("%s-%s"):format(config.prefix, safeName:upper())
end

function Demo.summary(playerName)
    return {
        greeting = Demo.greet(playerName),
        code = Demo.buildCode(playerName),
        mode = config.mode,
    }
end

return Demo
