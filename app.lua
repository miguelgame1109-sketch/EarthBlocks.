
local lapis = require("lapis")
local csrf = require("lapis.csrf")
local bcrypt = require("Lua_bcrypt")

local Database = require("database")
local Users = Database.Users

local app = lapis.Application()

app:enable("etlua")
app.layout = "layout"

local function initialize()
    Database.initialize()
end

local function get_user(self)
    if not self.session.user_id then
        return nil
    end

    return Users:find(self.session.user_id)
end

local function prepare_form(self)
    self.csrf_token = csrf.generate_token(self)
end

-- HOMEPAGE
app:get("/", function(self)
    initialize()

    self.user = get_user(self)
    prepare_form(self)

    return {
        render = "home"
    }
end)

-- REGISTER PAGE
app:get("/register", function(self)
    initialize()

    self.message = nil
    prepare_form(self)

    return {
        render = "register"
    }
end)

-- CREATE ACCOUNT
app:post("/register", function(self)
    initialize()
    csrf.assert_token(self)

    local username = self.params.username or ""
    local password = self.params.password or ""
    local confirm = self.params.confirm_password or ""

    if #username < 3 or #username > 20
        or not username:match("^[A-Za-z0-9_]+$") then

        self.message = "Username must be 3-20 letters, numbers or underscores."
        prepare_form(self)
        return { render = "register" }
    end

    if #password < 8 or #password > 72 then
        self.message = "Password must be 8-72 bytes."
        prepare_form(self)
        return { render = "register" }
    end

    if password ~= confirm then
        self.message = "Passwords do not match."
        prepare_form(self)
        return { render = "register" }
    end

    if Users:find({ username = username }) then
        self.message = "That username is already taken."
        prepare_form(self)
        return { render = "register" }
    end

    local hash_ok, password_hash = pcall(
        bcrypt.digest,
        password,
        12
    )

    if not hash_ok or not password_hash then
        self.message = "Account creation failed. Please try again."
        prepare_form(self)
        return { render = "register" }
    end

    local create_ok, user = pcall(function()
        return Users:create({
            username = username,
            password_hash = password_hash
        })
    end)

    if not create_ok or not user then
        self.message = "Could not create account. Try another username."
        prepare_form(self)
        return { render = "register" }
    end

    self.session.user_id = user.id

    return {
        redirect_to = "/"
    }
end)

-- LOGIN PAGE
app:get("/login", function(self)
    initialize()

    self.message = nil
    prepare_form(self)

    return {
        render = "login"
    }
end)

-- LOGIN ACCOUNT
app:post("/login", function(self)
    initialize()
    csrf.assert_token(self)

    local username = self.params.username or ""
    local password = self.params.password or ""

    local user = Users:find({
        username = username
    })

    local password_ok = false

    if user and #password <= 72 then
        local ok, result = pcall(
            bcrypt.verify,
            password,
            user.password_hash
        )

        password_ok = ok and result == true
    end

    if not password_ok then
        self.message = "Incorrect username or password."
        prepare_form(self)

        return {
            render = "login"
        }
    end

    self.session.user_id = user.id

    return {
        redirect_to = "/"
    }
end)

-- LOGOUT
app:post("/logout", function(self)
    csrf.assert_token(self)

    self.session.user_id = nil

    return {
        redirect_to = "/"
    }
end)

return app
