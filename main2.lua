local lapis = require("lapis")
local app = lapis.Application()

app:enable("etlua")

app:get("/", function(self)
    return { redirect_to = "/register" }
end)

app:get("/register", function(self)
    return {
        render = "register"
    }
end)

app:post("/register", function(self)
    local username = self.params.username or ""
    local password = self.params.password or ""
    local confirm = self.params.confirm or ""

    if #username < 3 then
        self.message = "Username must have at least 3 characters."
        return { render = "register" }
    end

    if #password < 8 then
        self.message = "Password must have at least 8 characters."
        return { render = "register" }
    end

    if password ~= confirm then
        self.message = "Passwords do not match."
        return { render = "register" }
    end

    self.message = "Registration form accepted! Database saving comes next."
    return { render = "register" }
end)

return app