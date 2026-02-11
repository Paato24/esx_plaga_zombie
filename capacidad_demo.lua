local Demo = {}

local config = {
    mode = "test",
    retries = 3,
}

function Demo.greet(playerName)
    if not playerName or playerName == "" then
        return "Hola, invitado"
    end

    return ("Hola, %s"):format(playerName)
end

function Demo.multiply(a, b)
    return a * b
end

function Demo.summary(playerName)
    return {
        greeting = Demo.greet(playerName),
        value = Demo.multiply(4, 5),
        mode = config.mode,
        retries = config.retries,
    }
end

return Demo
