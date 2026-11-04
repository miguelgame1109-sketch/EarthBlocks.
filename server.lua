
if path == "/login" and method == "POST" then

    local form = parseForm(body)

    local username = form.username or ""
    local password = form.password or ""

    local sql = string.format(
        "SELECT username FROM accounts WHERE username='' AND password='%s'",
        sqlEscape(username),
        sqlEscape(password)
    )

    local cursor = database:execute(sql)

    if cursor then
        local row = cursor:fetch({}, "a")
        cursor:close()

        if row then
            print("Login successful: " .. row.username)

            -- Continue to create the login session
        else
            print("Incorrect username or password!")
        end
    end
end
