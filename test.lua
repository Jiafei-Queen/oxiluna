#!/usr/bin/env lua
local fs = require("fs")
print(table.concat(fs.ls("."), "\n"))
