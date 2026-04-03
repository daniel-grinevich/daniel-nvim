local telescope = require("telescope")
local builtin = require("telescope.builtin")
local sorters = require("telescope.sorters")

-- Wrap a base sorter to boost files in high-value directories
local function boosted_sorter(base)
	local priority_dirs = {
		"models", "views", "controllers", "templates",
		"forms", "serializers", "schemas", "routes",
		"services", "middleware", "migrations",
	}

	return sorters.Sorter:new({
		scoring_function = function(_, prompt, line, entry)
			local base_score = base:scoring_function(prompt, line, entry)
			if base_score < 0 then return -1 end

			local path = entry.ordinal or ""
			for _, dir in ipairs(priority_dirs) do
				if path:match("/" .. dir .. "/") or path:match("^" .. dir .. "/") then
					return base_score * 0.9
				end
			end
			return base_score
		end,
		highlighter = base.highlighter and function(_, prompt, display)
			return base:highlighter(prompt, display)
		end or nil,
	})
end

telescope.setup({
	defaults = {
		file_sorter = function() return boosted_sorter(sorters.get_fuzzy_file()) end,
		generic_sorter = function() return boosted_sorter(sorters.get_generic_fuzzy_sorter()) end,
	},
})

vim.keymap.set("n", "<leader>pf", builtin.find_files, { desc = "Find files" })
vim.keymap.set("n", "<leader>ps", builtin.live_grep, { desc = "Project search (grep)" })
vim.keymap.set("n", "<leader>pd", function()
	vim.ui.input({ prompt = "Grep in directory: ", completion = "dir" }, function(dir)
		if dir and dir ~= "" then
			builtin.live_grep({ search_dirs = { dir } })
		end
	end)
end, { desc = "Grep in specific directory" })
vim.keymap.set("n", "<leader>pb", builtin.buffers, { desc = "Project buffers" })
vim.keymap.set("n", "<leader>pws", builtin.grep_string, { desc = "Search word under cursor" })
