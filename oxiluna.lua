#!/usr/bin/env lua
local fs = dofile("fs.lua")
local unix = not os.getenv("USERPROFILE")

local CWD = os.getenv("OXILUNA_HOME")
if not CWD then
	local hint = unix and
	"export OXILUNA_HOME=/path/to/oxiluna" or
	"set OXILUNA_HOME=C:\\path\\to\\oxiluna"

	io.stderr:write("Error: OXILUNA_HOME environment variable is not set.\n")
	io.stderr:write("Please set it to the root directory of the oxiluna project.\n")
	io.stderr:write("Example: " .. hint .. "\n")
	os.exit(1)
end

local LUA_PATH = fs.join(CWD, "src", "lua")
local RS_PATH = fs.join(CWD, "src", "main.rs")

local USAGE = [[
Usage: oxiluna.lua <script.lua> [module.lua...] [-o <output>] [-t <target>]"
Example: ./oxiluna.lua test.lua fs.lua
]]

local args = {...}
if #args == 0 then
	print(USAGE)
	return
end

local main = args[1]
-- 检验输入文件是否存在
if fs.test(main) ~= "file" then
	io.stderr:write(("oxiluna: So such main file: %s\n"):format(main))
	return
end

local modules = {}
local output
local target

local skip = true
for i,v in ipairs(args) do
	if skip then
		skip = false
		goto continue
	end

	if v == "-o" then
		if not output then
			output = args[i+1]
			skip = true
		else
			print(USAGE)
			return
		end
	elseif v == "-t" then
		if not target then
			target = args[i+1]
			skip = true
		else
			print(USAGE)
			return
		end
	else
		-- 检验模块文件
		if fs.test(v) == "file" then
			table.insert(modules, {path = v, modname = v:match("[^/\\]+$"):gsub('%.lua$', '')})
		else
			io.stderr:write(("oxiluna: no such module file: %s\n"):format(v))
			return
		end
	end

	:: continue ::
end

output = output or main:gsub("%.[^%.]+$", unix and "" or ".exe")

--[[
print(main)
print(table.concat(modules, ", "))
print(output)
]]--

-- 检验输出文件路径
if fs.test(output) == "dir" then
	io.stderr:write(('oxiluna: output is a dir: %s\n'):format(output))
end

--- [ 自动检测 require 语句 ] ---

local function parse_requires(source)
	local requires = {}
	for mod in source:gmatch('require%s*%("([^"]+)"%)') do
		requires[mod] = true
	end
	for mod in source:gmatch("require%s*%('([^']+)'%)") do
		requires[mod] = true
	end
	return requires
end

local function dotted_path(name)
	return name:gsub("%.", unix and "/" or "\\")
end

local function search_module(modname, search_paths)
	local path_part = dotted_path(modname)
	for pattern in search_paths:gmatch("[^;]+") do
		local filepath = pattern:gsub("%?", path_part)
		if fs.test(filepath) == "file" then
			return filepath
		end
	end
	return nil
end

-- 递归发现所有依赖的 Lua 模块
local discovered = {}
local c_warnings = {}
local scanned = {}
local queue = {main}

for _, mod in ipairs(modules) do
	queue[#queue + 1] = mod.path
end

while #queue > 0 do
	local fp = table.remove(queue)
	if scanned[fp] then goto skip end
	scanned[fp] = true

	local f = io.open(fp, "r")
	if not f then goto skip end
	local source = f:read("*a")
	f:close()

	for modname, _ in pairs(parse_requires(source)) do
		if not discovered[modname] then
			local lua_file = search_module(modname, package.path)
			if lua_file then
				discovered[modname] = lua_file
				queue[#queue + 1] = lua_file
			else
				local c_file = search_module(modname, package.cpath)
				if c_file then
					c_warnings[modname] = c_file
				end
			end
		end
	end
	:: skip ::
end

for modname, filepath in pairs(c_warnings) do
	io.stderr:write(("oxiluna: warning: '%s' requires C dynamic library (%s), cannot embed\n"):format(modname, filepath))
end

-- 将自动发现的模块加入构建
local existing_modnames = {}
for _, mod in ipairs(modules) do
	existing_modnames[mod.modname] = true
end

for modname, filepath in pairs(discovered) do
	if not existing_modnames[modname] then
		table.insert(modules, {path = filepath, modname = modname})
		io.stderr:write(("oxiluna: auto-included module '%s'\n"):format(modname))
	end
end

--- [ 拼接并写入 Rust 代码 ] ---
local TEMPLATE = [[
use mlua::Lua;

fn replace_shebang(code: &str) -> &str {
    if code.starts_with("#!") {
        return if let Some(pos) = code.find('\n') {
            &code[pos..]
        } else {
            ""
        }
    }
    code
}

fn main() -> mlua::Result<()> {
    let lua = Lua::new();

%s
    Ok(())
}]]

local MODULE_SENTENCE = [[
    preload.set(
        "%s", lua.load(
            replace_shebang(include_str!("lua/%s"))
        ).into_function()?
    )?;

]]

local MAIN_SENTENCE = [[
    lua.load(replace_shebang(include_str!("lua/%s"))).exec()?;
]]

local sentences

if #modules == 0 then
	sentences = ""
else
sentences = [[
    let globals = lua.globals();
    let package: mlua::Table = globals.get("package")?;
    let preload: mlua::Table = package.get("preload")?;

]]
end

for _, mod in ipairs(modules) do
	local relpath = mod.modname:gsub("%.", unix and "/" or "\\") .. ".lua"
	sentences = sentences .. MODULE_SENTENCE:format(mod.modname, relpath)
end

sentences = sentences..MAIN_SENTENCE:format(main:match("[^/\\]+$"))

local RS_PATH = fs.join(CWD, "/src/main.rs")
local rs = TEMPLATE:format(sentences)

local handle = io.open(RS_PATH, "w")
if handle then
	handle:write(rs)
	handle:close()
else
	io.stderr:write(("oxiluna: cannot write rs file: %s\n"):format(RS_PATH))
	return
end

--- [ 拷贝主与模块文件 ] ---
fs.rm(LUA_PATH)
fs.mkdir(LUA_PATH)

fs.cp(main, fs.join(LUA_PATH, main:match("[^/\\]+$")))
for _, mod in ipairs(modules) do
	local relpath = mod.modname:gsub("%.", unix and "/" or "\\") .. ".lua"
	local dst = fs.join(LUA_PATH, relpath)
	local dir = dst:match("^(.*[/\\])")
	if dir then fs.mkdir(dir) end
	fs.cp(mod.path, dst)
end

local target_option = ""
if target then
	target_option = "--target "..target
end

local ok = os.execute(
	('%s && cargo build --release %s'):format(fs.cd(CWD), target_option)
)

local release_dir
if target then
	release_dir = fs.join(CWD, "/target/", target, "/release")
else
	release_dir = fs.join(CWD, "/target", "/release")
end

local release
for _,v in ipairs(fs.ls(release_dir)) do
	if v == "oxiluna" or v == "oxiluna.exe" then
		release = fs.join(release_dir, v)
		break
	end
end

if not release then
	io.stderr:write(('oxiluna: release not found at `%s`\n'):format(release_dir))
	return
end

if ok then
	fs.cp(release, fs.join(fs.cwd(), output))
end
