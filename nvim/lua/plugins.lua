vim.pack.add({
        "https://github.com/ibhagwan/fzf-lua",
        "https://github.com/tpope/vim-fugitive",
        "https://github.com/nvim-orgmode/orgmode",
})

require("orgmode").setup({
        org_agenda_files = {
                "~/Desktop/p-notes/meta-plan.org",
                "~/Desktop/p-notes/bookmarks.org",
        },
        org_default_notes_file = "~/Desktop/p-notes/refile.org",
        org_startup_folded = 'showeverything', 
        mappings = {
                org = {
                        org_previous_visible_heading = false,
                        org_next_visible_heading = false,
                },
        },
})
vim.lsp.enable("org") -- Experimental LSP support

local fzf = require("fzf-lua")
fzf.setup({
        winopts = {
                fullscreen = true, -- Open in full screen by default
                border = "none", -- Optional: remove borders for a true full-screen feel
        },
})
vim.keymap.set({ "n", "t" }, "<leader><leader>", fzf.buffers, { desc = "Find in open buffers" })
vim.keymap.set({ "n", "t" }, "<leader>sf", fzf.files, { desc = "Find in open buffers" })
vim.keymap.set({ "n", "t" }, "<leader>sk", fzf.keymaps, { desc = "[s]earch [k]eymaps" })
vim.keymap.set({ "n", "t" }, "<leader>s.", function() require("fzf-lua").oldfiles({ cwd_only = true }) end, { desc = "[s]earch [o]ld buffers (cwd)" })
vim.keymap.set({ "n", "t" }, "<leader>sg", fzf.grep, { desc = "[s]earch [g]rep" })
vim.keymap.set({ "n", "t" }, "<leader>sj", fzf.jumps, { desc = "[s]earch [j]umps" })
vim.keymap.set({ "n", "t" }, "<leader>so", fzf.lsp_document_symbols, { desc = "[s]earch lsp [o]bjects" })
vim.keymap.set({ "n", "t" }, "<leader>sh", fzf.helptags, { desc = "[s]earch [h]elp tags" })
vim.keymap.set({ "n", "t" }, "<leader>sm", fzf.marks, { desc = "[s]earch [m]arks" })
vim.keymap.set({ "n", "t" }, "<leader>sb", fzf.blines, { desc = "[s]earch [b]uffer" })
vim.keymap.set({ "n", "t" }, "<leader>sr", fzf.resume, { desc = "[s]earch [r]esume" })
vim.keymap.set({ "n", "t" }, "<leader>sl", fzf.lines, { desc = "[s]earch [l]ines in open buffers" })
