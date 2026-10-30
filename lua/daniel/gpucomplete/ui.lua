-- Ghost text: first line inline at the cursor, remaining lines as virtual lines below.
local M = {}

local ns = vim.api.nvim_create_namespace("gpucomplete")
local shown_buf

function M.clear()
  if shown_buf and vim.api.nvim_buf_is_valid(shown_buf) then
    vim.api.nvim_buf_clear_namespace(shown_buf, ns, 0, -1)
  end
  shown_buf = nil
end

local function display(s, buf)
  return (s:gsub("\t", string.rep(" ", vim.bo[buf].tabstop)))
end

--- row is 1-based, col is a 0-based byte column.
function M.show(buf, row, col, text)
  M.clear()
  local lines = vim.split(text, "\n", { plain = true })
  local virt_lines = {}
  for idx = 2, #lines do
    table.insert(virt_lines, { { display(lines[idx], buf), "GpuCompleteSuggestion" } })
  end
  vim.api.nvim_buf_set_extmark(buf, ns, row - 1, col, {
    virt_text = { { display(lines[1], buf), "GpuCompleteSuggestion" } },
    virt_text_pos = "inline",
    virt_lines = #virt_lines > 0 and virt_lines or nil,
    hl_mode = "combine",
  })
  shown_buf = buf
end

return M
