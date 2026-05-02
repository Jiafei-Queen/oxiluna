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
	io.stderr:write(("oxiluna: no such main file: %s\n"):format())
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
			table.insert(modules, v)
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

for _,v in ipairs(modules) do
	local filename = v:match("[^/\\]+$")
	sentences = sentences..MODULE_SENTENCE:format(filename:gsub('.lua', ''), filename)
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
end

--- [ 拷贝主与模块文件 ] ---
fs.rm(LUA_PATH)
fs.mkdir(LUA_PATH)

fs.cp(main, fs.join(LUA_PATH, main:match("[^/\\]+$")))
for _,v in ipairs(modules) do
	fs.cp(v, fs.join(LUA_PATH, v:match("[^/\\]+$")))
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

if release then
	if release:match("%.exe$") then
		output = output..".exe"
	end
else
	io.stderr:write(('oxiluna: release not found at `%s`\n'):format(release_dir))
	return
end

if ok then
	fs.cp(release, fs.join(fs.cwd(), output))
end
