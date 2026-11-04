
local socket = require("socket")
local luasql = require("luasql.sqlite3")

local env = luasql.sqlite3()
local db = env:connect("games.db")

local server = assert(socket.bind("127.0.0.1", 8080))

print("================================")
print(" MyPlatform Game Website")
print(" http://localhost:8080")
print("================================")

-- Database
db:execute([[
CREATE TABLE IF NOT EXISTS games (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    title TEXT NOT NULL,
    description TEXT,
    folder TEXT UNIQUE NOT NULL,
    thumbnail TEXT,
    created_at TEXT DEFAULT CURRENT_TIMESTAMP
)
]])

local function escape_html(value)
    value = tostring(value or "")
    value = value:gsub("&", "&amp;")
    value = value:gsub("<", "&lt;")
    value = value:gsub(">", "&gt;")
    value = value:gsub('"', "&quot;")
    value = value:gsub("'", "&#39;")
    return value
end

local function sql_quote(value)
    return "'" .. tostring(value or ""):gsub("'", "''") .. "'"
end

local function url_decode(value)
    value = value:gsub("+", " ")
    value = value:gsub("%%(%x%x)", function(hex)
        return string.char(tonumber(hex, 16))
    end)
    return value
end

local function parse_form(body)
    local result = {}

    for key, value in body:gmatch("([^&=]+)=([^&]*)") do
        result[url_decode(key)] = url_decode(value)
    end

    return result
end

local function read_file(path)
    local file = io.open(path, "rb")
    if not file then
        return nil
    end

    local content = file:read("*a")
    file:close()
    return content
end

local function response(client, status, content, content_type)
    content = content or ""

    client:send(
        "HTTP/1.1 " .. status .. "\r\n" ..
        "Content-Type: " .. (content_type or "text/html") .. "\r\n" ..
        "Content-Length: " .. #content .. "\r\n" ..
        "Connection: close\r\n" ..
        "X-Content-Type-Options: nosniff\r\n" ..
        "\r\n" ..
        content
    )
end

local function redirect(client, location)
    client:send(
        "HTTP/1.1 303 See Other\r\n" ..
        "Location: " .. location .. "\r\n" ..
        "Content-Length: 0\r\n" ..
        "Connection: close\r\n\r\n"
    )
end

local function page(title, content)
    return [[
<!DOCTYPE html>
<html>
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1">
    <title>]] .. escape_html(title) .. [[ - MyPlatform</title>
    <link rel="stylesheet" href="/style.css">
</head>
<body>

<header>
    <h1>MyPlatform</h1>
    <nav>
        <a href="/">Home</a>
        <a href="/">Games</a>
        <a href="/publish">Publish Game</a>
    </nav>
</header>

<main>
]] .. content .. [[
</main>

<footer>MyPlatform - Create and Play Games</footer>

</body>
</html>
]]
end

-- Homepage
local function homepage()
    local cursor = db:execute(
        "SELECT * FROM games ORDER BY id DESC"
    )

    local cards = ""

    if cursor then
        local row = cursor:fetch({}, "a")

        while row do
            cards = cards .. [[
<div class="game-card">
    <img src="/images/]] .. escape_html(row.thumbnail) .. [[" alt="Game thumbnail">

    <h3>]] .. escape_html(row.title) .. [[</h3>

    <p>]] .. escape_html(row.description) .. [[</p>

    <a class="play-button" href="/play?id=]] ..
                row.id .. [[">Play</a>
</div>
]]

            row = cursor:fetch(row, "a")
        end

        cursor:close()
    end

    if cards == "" then
        cards = "<p>No games published yet. Be the first creator!</p>"
    end

    return page("Home", [[
<h2>Welcome to MyPlatform!</h2>
<p>Discover games created by our community.</p>

<h2>Games</h2>

<div class="games-grid">
]] .. cards .. [[
</div>
]])
end

-- Publish page
local function publish_page()
    local content = read_file("public/publish.html")

    if content then
        return content
    end

    return page("Publish", "<h2>Publish page missing.</h2>")
end

-- Game player page
local function play_game(id)
    id = tonumber(id)

    if not id then
        return page("Error", "<h2>Invalid game ID.</h2>")
    end

    local cursor = db:execute(
        "SELECT * FROM games WHERE id = " .. math.floor(id)
    )

    if not cursor then
        return page("Error", "<h2>Database error.</h2>")
    end

    local game = cursor:fetch({}, "a")
    cursor:close()

    if not game then
        return page("Error", "<h2>Game not found.</h2>")
    end

    return page(game.title, [[
<h2>]] .. escape_html(game.title) .. [[</h2>

<p>]] .. escape_html(game.description) .. [[</p>

<div class="game-player">
    <iframe
        src="/games/]] .. escape_html(game.folder) .. [[/index.html"
        allow="fullscreen; autoplay"
        allowfullscreen>
    </iframe>
</div>

<p><a href="/">Back to Games</a></p>
]])
end

-- Publish game information
local function publish_game(client, body)
    local form = parse_form(body)

    local title = form.title or ""
    local description = form.description or ""
    local folder = form.folder or ""
    local thumbnail = form.thumbnail or "default.svg"

    if #title < 1 or #title > 80 then
        return response(client, "400 Bad Request",
            "Game title must be 1 to 80 characters.")
    end

    if #description > 500 then
        return response(client, "400 Bad Request",
            "Description is too long.")
    end

    if not folder:match("^[a-z0-9_-]+$") then
        return response(client, "400 Bad Request",
            "Folder must use lowercase letters, numbers, - or _.")
    end

    if #folder > 50 then
        return response(client, "400 Bad Request",
            "Folder name is too long.")
    end

    if not thumbnail:match("^[%w_.-]+$") then
        return response(client, "400 Bad Request",
            "Invalid thumbnail filename.")
    end

    if not read_file("public/games/" .. folder .. "/index.html") then
        return response(client, "400 Bad Request",
            "Godot game export not found. Export it first.")
    end

    if not read_file("public/images/" .. thumbnail) then
        return response(client, "400 Bad Request",
            "Thumbnail not found in public/images.")
    end

    local query = [[
INSERT INTO games (title, description, folder, thumbnail)
VALUES (
]] .. sql_quote(title) .. ", " ..
       sql_quote(description) .. ", " ..
       sql_quote(folder) .. ", " ..
       sql_quote(thumbnail) .. ")"

    local result, err = db:execute(query)

    if not result then
        print("Publish error: " .. tostring(err))

        return response(client, "400 Bad Request",
            "Could not publish. Check whether this folder was already published.")
    end

    redirect(client, "/")
end

-- Static files
local function static_file(client, path)
    path = url_decode(path)

    if path:find("\\", 1, true)
        or path:find("..", 1, true)
        or path:find("%z") then
        return response(client, "403 Forbidden", "Forbidden")
    end

    local allowed =
        path == "/style.css"
        or path:match("^/images/[%w_./-]+$")
        or path:match("^/games/[%w_./-]+$")

    if not allowed then
        return response(client, "404 Not Found", "Not found")
    end

    local types = {
        html = "text/html",
        css = "text/css",
        js = "application/javascript",
        wasm = "application/wasm",
        pck = "application/octet-stream",
        png = "image/png",
        jpg = "image/jpeg",
        jpeg = "image/jpeg",
        svg = "image/svg+xml",
        ico = "image/x-icon"
    }

    local extension = path:match("%.([%w]+)$")
    local mime = types[extension or ""] or "application/octet-stream"

    local content = read_file("public" .. path)

    if not content then
        return response(client, "404 Not Found", "File not found")
    end

    response(client, "200 OK", content, mime)
end

-- HTTP request handler
local function handle(client)
    client:settimeout(5)

    local request = client:receive("*l")

    if not request then
        return
    end

    local method, path = request:match("^(%S+)%s+(%S+)%s+HTTP")

    if not method or not path then
        return response(client, "400 Bad Request", "Invalid request")
    end

    local headers = {}

    while true do
        local line = client:receive("*l")

        if not line or line == "" then
            break
        end

        local key, value = line:match("^([^:]+):%s*(.*)$")

        if key then
            headers[key:lower()] = value
        end
    end

    local body = ""
    local length = tonumber(headers["content-length"]) or 0

    if length > 16000 then
        return response(client, "413 Content Too Large", "Request too large")
    end

    if length > 0 then
        local data, err, partial = client:receive(length)
        body = data or partial or ""

        if #body ~= length then
            return response(client, "400 Bad Request", "Incomplete request")
        end
    end

    local route, query = path:match("^([^?]*)%??(.*)$")

    if method == "GET" and route == "/" then
        return response(client, "200 OK", homepage())

    elseif method == "GET" and route == "/publish" then
        return response(client, "200 OK", publish_page())

    elseif method == "POST" and route == "/publish" then
        if headers["content-type"]
            and not headers["content-type"]:match(
                "^application/x%-www%-form%-urlencoded"
            ) then
            return response(client, "415 Unsupported Media Type",
                "Expected a form submission.")
        end

        return publish_game(client, body)

    elseif method == "GET" and route == "/play" then
        local id = query:match("[?&]?id=(%d+)")

        return response(client, "200 OK", play_game(id))

    elseif method == "GET" then
        return static_file(client, route)
    end

    response(client, "404 Not Found", "Page not found")
end

while true do
    local client = server:accept()

    if client then
        local ok, err = pcall(handle, client)

        if not ok then
            print("Request error: " .. tostring(err))
            response(client, "500 Internal Server Error",
                "Server error. Check the terminal.")
        end

        client:close()
    end
end
