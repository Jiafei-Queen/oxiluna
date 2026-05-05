local G = {}
local unix = not os.getenv("USERPROFILE")

local function sh_quote(path)
    return "'" .. tostring(path):gsub("'", [['"'"']]) .. "'"
end

local function exec_ok(cmd)
    local ok, why, code = os.execute(cmd)
    if ok == true then
        return true
    end

    if type(ok) == "number" then
        return ok == 0
    end

    return why == "exit" and code == 0
end

local function win_quote(path)
    return '"' .. tostring(path):gsub('"', '""') .. '"'
end

local function shell_quote(path)
    if unix then
        return sh_quote(path)
    end
    return win_quote(path)
end

local function wrap_cmd(cmd)
    if unix then
        return cmd
    end
    return "cmd /d /c " .. win_quote(cmd)
end

local function exec(cmd)
    return exec_ok(wrap_cmd(cmd))
end

local function popen(cmd)
    return assert(io.popen(wrap_cmd(cmd)))
end

--- [ 获得工作目录 ] ---
function G.cwd()
    local cmd = unix and "pwd" or "cd"
    local handle = popen(cmd)
    local result = handle:read("*a"):gsub("[\r\n]+$", "")
    handle:close()
    return result
end

--- [ 等同于 `ls -A` ] ---
function G.ls(path)
    path = path or "."
    local cmd
    if unix then
        cmd = "ls -A " .. shell_quote(path)
    else
        cmd = "dir " .. shell_quote(path) .. " /b /a"
    end

    local files = {}
    for file in popen(cmd):lines() do
        table.insert(files, file)
    end

    return files
end

--- [ 检测路径是 **可读文件** 还是 **目录** 或是 **不存在或没有权限** ] ---
function G.test(path)
    local is_dir
    if unix then
        is_dir = exec("test -d " .. shell_quote(path))
    else
        -- Windows 下用 `path\NUL` 判断目录是否存在。
        -- 这里必须把 `\NUL` 放在引号内部，避免空格路径被 cmd 错误拆分。
        is_dir = exec("if exist " .. shell_quote(path .. "\\NUL") .. " (exit /b 0) else (exit /b 1)")
    end

    if is_dir then
        return "dir"
    end

    local f = io.open(path, "r")
    if f then
        f:close()
        return "file"
    end
end

--- [ 拼接路径 ] ---
function G.join(...)
    local arg = {...}
    local sep = unix and "/" or "\\"
    local res = table.concat(arg, sep)

    res = res:gsub("[\\/]+", sep)

    -- 针对 Windows UNC 路径还原开头的双斜杠
    if not unix and res:sub(1, 1) == "\\" then
        local original_start = table.concat(arg):sub(1, 2)
        if original_start == "\\\\" or original_start == "//" then
            res = "\\" .. res
        end
    end

    return res
end

--- [ 等同于 `mkdir -p` ] ---
function G.mkdir(path)
    if unix then
        return os.execute("mkdir -p " .. shell_quote(path))
    else
        -- cmd 的 mkdir 本身支持递归创建中间目录。
        return os.execute(wrap_cmd("mkdir " .. shell_quote(path) .. " 2>nul"))
    end
end

--- [ 等同于 `rm -rf` ] ---
function G.rm(path)
-- 没有读取权限，一般也没有权限删除
    local mode = G.test(path)
    if not mode then return false end

    local cmd
    if unix then
        cmd = "rm -rf " .. shell_quote(path)
    else
        if mode == "dir" then
            cmd = "rd /s /q " .. shell_quote(path)
        else
            cmd = "del /f /q " .. shell_quote(path)
        end
    end

    return exec(cmd)
end

--- [ 等同于 `cp -r` ] ---
--- @param src string 源路径
--- @param dst string 目标路径
function G.cp(src, dst)
    local mode = G.test(src)
    if not mode then return false, "Source does not exist" end

    local cmd
    if unix then
        cmd = "cp -r " .. shell_quote(src) .. " " .. shell_quote(dst)
    else
        if mode == "dir" then
            -- 目录复制显式追加 `\`，避免 xcopy 把目标误判成文件名。
            cmd = "xcopy "
                .. shell_quote(src .. "\\")
                .. " "
                .. shell_quote(dst .. "\\")
                .. " /E /I /Y >nul"
        else
            cmd = "copy /y " .. shell_quote(src) .. " " .. shell_quote(dst) .. " >nul"
        end
    end

    return exec(cmd)
end

--- [ 构造切换目录的命令前缀 ] ---
function G.cd(path)
    if not path or path == "" then return "" end

    -- 处理 Windows 盘符切换问题
    -- 在 Windows 中，单纯的 cd 无法跨盘符，需要 /d 参数
    local cmd
    if unix then
        cmd = "cd " .. shell_quote(path)
    else
        -- /d 确保可以从 C: 切换到 D:
        cmd = "cd /d " .. shell_quote(path)
    end

    return cmd
end

--- [ 等同于 `mv` ] ---
--- @param src string 源路径
--- @param dst string 目标路径
function G.mv(src, dst)
-- 1. 首先尝试使用 Lua 的原生函数 (原子操作，速度最快)
-- 注意：这在跨分区/跨硬盘移动时可能会失败
    local success = os.rename(src, dst)
    if success then return true end

    -- 2. 如果原生失败，则调用系统命令行
    local cmd
    if unix then
        cmd = "mv " .. shell_quote(src) .. " " .. shell_quote(dst)
    else
        local mode = G.test(src)
        if not mode then return false, "Source does not exist" end

        if mode == "dir" then
            -- move 命令在 Windows 跨盘符移动目录时表现很差。
            -- 这里退化成 copy + rm，保证跨盘可用。
            if G.cp(src, dst) then
                return G.rm(src)
            else
                return false
            end
        else
            cmd = "move /y " .. shell_quote(src) .. " " .. shell_quote(dst) .. " >nul"
        end
    end

    return exec(cmd)
end

return G
