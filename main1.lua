
local Database = require("database")
local bcrypt = require("lua-bcrypt")

print("===== CLASSIC ROBLOX DATABASE =====")

-- Register a test player
local username = "EarhBlocks1"
local password = "ExamplePassword123"

local hash = bcrypt.digest(password, 12)

local success, result =
    Database.createAccount(username, hash)

if success then
    print("Account created!")
    print("Player ID:", result)
else
    print("Could not create account:", result)
end

-- Find the player
local player = Database.findAccount(username)

if player then
    print("Player found:", player.username)

    -- Check password
    if bcrypt.verify(password, player.password_hash) then
        print("Login successful!")
    else
        print("Incorrect password!")
    end
else
    print("Player does not exist.")
end

print("===== ALL PLAYERS =====")

Database.listAccounts()

Database.close()
