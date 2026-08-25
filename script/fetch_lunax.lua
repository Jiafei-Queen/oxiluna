local URL = 'https://github.com/Jiafei-Queen/lunax'
local CWD = os.getenv('OXILUNA_HOME')
local ok, version = pcall(dofile, CWD..'/lunax/version.lua')

if not ok then
    print('[INF]: Clone the dep repo')

    local tmp = os.tmpname(); os.remove(tmp)
    local res = os.execute(('git clone %q %s'):format(URL, tmp))
    if res ~= true and res ~= 0 then
        io.stderr:write('[ERR]: Failed to download the dep (lunax) via git\n')
        os.exit(1)
    end

    local fs = dofile(tmp..'/lunax/fs.lua')
    fs.mv(fs.join(tmp, 'lunax'), CWD..'/lunax')
    fs.rm(tmp)
else
    print((':: Lunax v%s'):format(version))
end
