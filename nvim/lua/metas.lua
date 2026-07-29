-- just overwrite a bunch of functions and create some commands if
-- in sapling repository
local root = vim.fn.systemlist("sl root 2>/dev/null")[1] or ""
if root == "" then return end

-- --------------------------------------------------------------------------------
-- FINDERS with QFLIST
-- --------------------------------------------------------------------------------
-- this is great no plugin usage, the only problem is it pollutes old files list
--    Qf populates quickfix.
--    Quickfix creates hidden buffers for every filename.
--    fzf-lua oldfiles/picker sees named buffers from current session.
--    Those quickfix ghost buffers now look like recent/old files.
-- we could do some extra work to avoid it
-- local home = vim.fn.expand("~")
-- local qf_efm = "%f|%l col %c|%m,%f:%l:%c:%m,%f:%l:%m"
--
-- local function join(dir, path) return path:sub(1, 1) == "/" and path or dir .. "/" .. path end
--
-- local function current_sl_root() return vim.fn.systemlist("sl root 2>/dev/null")[1] or vim.fn.getcwd() end
--
-- vim.api.nvim_create_user_command("Qf", function(opts)
--         local cmd = opts.args
--         local lines = vim.fn.systemlist(cmd)
--
--         if cmd:match("^myles%s") then
--                 local items = {}
--                 local search_root = current_sl_root()
--                 for _, line in ipairs(lines) do
--                         if line ~= "" then table.insert(items, { filename = join(search_root, line) }) end
--                 end
--                 vim.fn.setqflist({}, "r", { title = cmd, items = items })
--         else
--                 for i, line in ipairs(lines) do
--                         lines[i] = line:gsub("^([^/|:][^|:]*)", home .. "/%1", 1)
--                 end
--                 vim.fn.setqflist({}, "r", { title = cmd, lines = lines, efm = qf_efm })
--         end
--         vim.cmd("botright copen")
-- end, { nargs = "+" })
-- vim.keymap.set("n", "<leader>sf", ":Qf myles --list -n 50 ", { desc = "Search files (myles)" })
-- vim.keymap.set("n", "<leader>sg", ':Qf zbgr --exclude "www|test|json|\\.php$|\\.md$|\\.pyi$" ', { desc = "[s]earch [g]rep" })

vim.api.nvim_create_user_command("Bg", function(opts)
        require("fzf-lua").grep({
                raw_cmd = opts.args, -- raw_cmd, NOT cmd → no input box
                cwd = vim.fn.expand("~"),
                winopts = { preview = { layout = "vertical", vertical = "down:45%" } },
        })
end, { nargs = "+" })
vim.keymap.set("n", "<leader>sg", [[:Bg zbgr -i --exclude "www|test|json|\.php$|\.md$|\.pyi$" ]], { desc = "Search grep" })
vim.keymap.set("n", "<leader>sf", [[:Bg zbgf -i ]], { desc = "Search files (myles)" })
-- TODO: in visual mode, just sg for the selected part

-- --------------------------------------------------------------------------------
-- LSP INTEGRATIONS
-- --------------------------------------------------------------------------------
-- TODO: eventually we would like to remove this plugin?
vim.pack.add({ "https://github.com/neovim/nvim-lspconfig" })
vim.opt.rtp:prepend("/usr/share/fb-editor-support/nvim")
vim.lsp.enable({
        "pyrefly@meta", -- Pyrefly type checker
        "rust-analyzer@meta", -- Rust - Run :RustAnalyzerReload on TARGETS changes
        -- "fb-pyright-ls@meta", -- Python
        -- "pyre@meta", -- Python type checking
        "thriftlsp@meta", -- Thrift
        "cppls@meta", -- C++
        -- "buckls@meta", -- Buck (disabled: sends boolean diagnosticProvider, crashes nvim 0.12 vim/lsp/diagnostic.lua:396)
        "buck2@meta", -- Buck/Starlark
        "gopls@meta", -- Golang
        "flow@meta", -- JavaScript/Flow
        "hhvm", -- Hack
        "linttool@meta", -- Linting and formatting
        "ids@meta",
})

-- TypeScript: use the vendored server in fbsource (npm installs are blocked on devvm)
local ts_cli = vim.fn.expand("~") .. "/fbsource/fbcode/jest_e2e/framework/node_modules/typescript-language-server/lib/cli.mjs"
if vim.fn.filereadable(ts_cli) == 1 then
        vim.lsp.config["ts_ls"] = {
                cmd = { "node", ts_cli, "--stdio" },
                filetypes = { "typescript", "typescriptreact", "javascript", "javascriptreact" },
                root_markers = { "tsconfig.json", "jsconfig.json", "package.json", ".git" },
        }
        vim.lsp.enable("ts_ls")
end

-- disable native integrations to avoid both being turned on
vim.lsp.enable("clangd", false)
vim.lsp.enable("pyrefly", false)
vim.lsp.enable("rust_analyzer", false)

-- --------------------------------------------------------------------------------
-- LSP IGNORES
-- --------------------------------------------------------------------------------
-- meta's clangd or cppls issues
local notify_once = vim.notify_once
vim.notify_once = function(msg, level, opts)
        if type(msg) == "string" and msg:match("^cppls@meta: %-32603 Error thrown from handling the auto completion response") then return end
        return notify_once(msg, level, opts)
end

-- --------------------------------------------------------------------------------
-- GIT GUTTER INTEGRATIONS
-- --------------------------------------------------------------------------------
function VCS_DIFF_FILE(file)
        -- insert mode: diff against working-copy parent (uncommitted changes only)
        -- normal mode: diff against parent commit (committed + uncommitted)
        local rev = vim.api.nvim_get_mode().mode:sub(1, 1) == "i" and "." or ".^"
        return { "sl", "cat", "-r", rev, file }
end
function VCS_DIFF_FILES() return { "sl", "status" } end
function VCS_HUNKS()
        return { "sl", "diff", "-U0" } -- adding '--change .' would give committed changes
end

-- --------------------------------------------------------------------------------
-- CODEHUB
-- --------------------------------------------------------------------------------
-- /data/users/shah256/configerator/source/ti/slb/feature_rollout.cconf:5-36
-- https://www.internalfb.com/code/configerator/[b6bafa496b10eebdbc9834d7d66912b152403ba8]/source/ti/slb/feature_rollout.cconf?lines=3-36
vim.api.nvim_create_user_command("CodeHub", function(opts)
        local abs = vim.fn.expand("%:p")
        local file_root = vim.fn.systemlist({ "sl", "--cwd", vim.fn.expand("%:p:h"), "root" })[1] or ""
        if file_root == "" or abs:sub(1, #file_root) ~= file_root then
                vim.notify("CodeHub: file not in a sapling repo: " .. abs, vim.log.levels.ERROR)
                return
        end
        local rel = abs:sub(#file_root + 2) -- strip root + '/'
        local repo = vim.fn.fnamemodify(file_root, ":t")
        local commit = vim.fn.systemlist({ "sl", "--cwd", file_root, "log", "-r", ".", "-T", "{node}\n" })[1]
        local path = "https://www.internalfb.com/code/" .. repo .. "/[" .. commit .. "]/" .. rel

        if opts.range > 0 then
                if opts.line1 == opts.line2 then
                        path = path .. "?lines=" .. opts.line1
                else
                        path = path .. "?lines=" .. opts.line1 .. "-" .. opts.line2
                end
        end
        vim.fn.setreg("+", path)
        vim.notify("Copied: " .. path)
end, { range = true })
vim.keymap.set("n", "<leader>ch", "<cmd>CodeHub<cr>", { desc = "Copy CodeHub url" })
vim.keymap.set("v", "<leader>ch", ":CodeHub<cr>", { desc = "Copy CodeHub url with lines" })

-- --------------------------------------------------------------------------------
-- EXTRAS
-- --------------------------------------------------------------------------------
-- Configerator/CINC is Python-like; use Python parser/decorators/folds/etc.
vim.treesitter.language.register("python", "configerator")
vim.api.nvim_create_autocmd("FileType", {
        pattern = "configerator",
        callback = function()
                vim.opt_local.foldmethod = "expr"
                vim.opt_local.foldexpr = "v:lua.vim.treesitter.foldexpr()"
                vim.opt_local.foldlevel = 99 -- keep folds open by default
                vim.opt_local.foldenable = true
        end,
})
-- overrides
local fmt = require("format")
fmt.inplace_fmt_ft.configerator = { "arc", "f" }

-- --------------------------------------------------------------------------------
-- meta's internal packages
-- --------------------------------------------------------------------------------
-- inline blame off by default
require("meta.hg").setup({ line_blame = { enable = false } })
require("meta.buck").setup()
