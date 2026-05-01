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
	lua.load(replace_shebang(include_str!("lua/fs.lua"))).exec()?;
	lua.load(replace_shebang(include_str!("lua/test.lua"))).exec()?;

    Ok(())
}