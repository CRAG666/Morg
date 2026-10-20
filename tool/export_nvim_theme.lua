-- Uso: nvim --headless -c 'luafile tool/export_nvim_theme.lua' archivo.norg  (escribe <colorscheme>.json o $MORG_THEME_OUT)
local code_groups = {
  'Normal', 'Comment', 'Special',
  '@keyword', '@keyword.function', '@keyword.return', '@keyword.import', '@keyword.directive',
  '@string', '@string.escape', '@string.regexp', '@string.special', '@string.special.symbol', '@string.special.url',
  '@character', '@number', '@number.float', '@boolean', '@constant', '@constant.builtin',
  '@function', '@function.builtin', '@function.call', '@function.method', '@constructor',
  '@type', '@type.builtin', '@variable', '@variable.builtin', '@variable.parameter', '@variable.member',
  '@property', '@attribute', '@operator', '@punctuation', '@punctuation.bracket', '@punctuation.delimiter',
  '@module', '@label', '@tag', '@tag.attribute', '@comment', '@comment.documentation', '@markup.heading',
}

local function resolve(name)
  local hl = vim.api.nvim_get_hl(0, { name = name, link = false })
  local entry = vim.empty_dict()
  for _, key in ipairs({ 'fg', 'bg' }) do
    if hl[key] then entry[key] = string.format('#%06x', hl[key]) end
  end
  for _, key in ipairs({ 'bold', 'italic', 'underline', 'strikethrough' }) do
    if hl[key] then entry[key] = true end
  end
  return entry
end

local function dump()
  local groups = {}
  for name, _ in pairs(vim.api.nvim_get_hl(0, {})) do
    if name:match('^@neorg') then groups[name] = resolve(name) end
  end
  for _, name in ipairs(code_groups) do groups[name] = resolve(name) end
  return groups
end

vim.defer_fn(function()
  local variants = {}
  for _, background in ipairs({ 'dark', 'light' }) do
    vim.o.background = background
    vim.cmd.colorscheme(vim.g.colors_name)
    vim.cmd.doautocmd('ColorScheme')
    variants[background] = dump()
  end
  local file = io.open(vim.env.MORG_THEME_OUT or (vim.g.colors_name .. '.json'), 'w')
  file:write(vim.json.encode({ name = vim.g.colors_name, variants = variants }))
  file:close()
  vim.cmd('qa!')
end, 5000)
