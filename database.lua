
local db = require("lapis.db")
local Model = require("lapis.db.model").Model

local Users = Model:extend("users")

local Database = {}

local initialized = false

function Database.initialize()
    if initialized then
        return
    end

    db.query([[
        CREATE TABLE IF NOT EXISTS users (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            username TEXT NOT NULL COLLATE NOCASE UNIQUE,
            password_hash TEXT NOT NULL,
            created_at TEXT NOT NULL DEFAULT CURRENT_TIMESTAMP
        )
    ]])

    initialized = true
end

Database.Users = Users

return Database
