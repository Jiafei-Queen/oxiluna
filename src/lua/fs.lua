local G = {}
local unix = not os.getenv("USERPROFILE")

--- [ 获得工作目录 ] ---
function G.cwd()
    local cmd = unix and "pwd" or "cd"
    local handle = io.popen(cmd)
    local result = handle:read("*a"):gsub("\n$", "")
    handle:close()
    return result
end

--- [ 等同于 `ls -A` ] ---
function G.ls(path)
    path = path or "."
    local cmd = unix and "ls -A %q" or "dir %q /b /a"

    local files = {}
    for file in io.popen(cmd:format(path)):lines() do
        table.insert(files, file)
    end

    return files
end

--- [ 检测路径是 **可读文件** 还是 **目录** 或是 **不存在或没有权限** ] ---
function G.test(path)
    local is_dir = os.execute(unix and ("test -d %q"):format(path)
    or ("if exist %q\\ exit 0 else exit 1"):format(path))

    if is_dir == 0 or is_dir == true then
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
        return os.execute(('mkdir -p %q'):format(path))
    else
    -- Windows 直接用引号包裹路径即可
    -- 加上双引号是为了处理路径中的空格
        return os.execute(('mkdir %q 2>nul'):format(path))
    end
end

--- [ 等同于 `rm -rf` ] ---
function G.rm(path)
-- 没有读取权限，一般也没有权限删除
    local mode = G.test(path)
    if not mode then return false end

    local cmd
    if unix then
        cmd = ("rm -rf %q"):format(path)
    else
        if mode == "dir" then
            cmd = ("rd /s /q %q"):format(path)
        else
            cmd = ("del /f /q %q"):format(path)
        end
    end

    local ok, _, code = os.execute(cmd)
    return ok == 0 or ok == true
end

--- [ 等同于 `cp -r` ] ---
--- @param src string 源路径
--- @param dst string 目标路径
function G.cp(src, dst)
    local mode = G.test(src)
    if not mode then return false, "Source does not exist" end

    local cmd
    if unix then
    -- Unix: 直接使用 cp -r
        cmd = ("cp -r %q %q"):format(src, dst)
    else
    -- Windows:
        if mode == "dir" then
        -- /E 复制目录和子目录（包括空目录）
        -- /I 如果目标不存在且在复制多个文件，则假定目标必须是目录
        -- /Y 取消覆盖确认
            cmd = ("xcopy %q %q /E /I /Y >nul"):format(src, dst)
        else
        -- 如果是单个文件，使用 copy /y
            cmd = ("copy /y %q %q >nul"):format(src, dst)
        end
    end

    local ok, _, code = os.execute(cmd)
    return ok == 0 or ok == true
end

--- [ 构造切换目录的命令前缀 ] ---
function G.cd(path)
    if not path or path == "" then return "" end

    -- 处理 Windows 盘符切换问题
    -- 在 Windows 中，单纯的 cd 无法跨盘符，需要 /d 参数
    local cmd
    if unix then
        cmd = ("cd %q"):format(path)
    else
    -- /d 确保可以从 C: 切换到 D:
        cmd = ("cd /d %q"):format(path)
    end

    return cmd
end

--- [ 等同于 `mv` ] ---
--- @param src string 源路径
--- @param dst string 目标路径
function G.mv(src, dst)
-- 1. 首先尝试使用 Lua 的原生函数 (原子操作，速度最快)
-- 注意：这在跨分区/跨硬盘移动时可能会失败
    local success, err = os.rename(src, dst)
    if success then return true end

    -- 2. 如果原生失败，则调用系统命令行
    local cmd
    if unix then
    -- Unix: mv 默认支持跨分区移动
        cmd = ("mv %q %q"):format(src, dst)
    else
    -- Windows:
        local mode = G.test(src)
        if not mode then return false, "Source does not exist" end

        if mode == "dir" then
        -- move 命令在 Windows 跨盘符移动目录时表现很差
        -- 稳妥做法：先复制再删除 (模拟 mv 的跨盘行为)
            if G.cp(src, dst) then
                return G.remove(src)
            else
                return false
            end
        else
        -- 移动文件使用 move /y (覆盖模式)
            cmd = ("move /y %q %q >nul"):format(src, dst)
        end
    end

    local ok, _, code = os.execute(cmd)
    return ok == 0 or ok == true
end

return G

