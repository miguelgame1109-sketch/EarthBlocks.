local config = require("lapis.config")

config("development", {
    port = 8080,

    secret = "change-this-to-a-long-random-secret",

    sqlite = {
        database = "website.sqlite"
    }
})