-- Helper function to process the text and return the correct Quarto AST
local function process_equation(text)
  -- 1. Check if the text actually contains the equation environment
  if not text:find("\\begin{equation}") then return nil end

  -- 2. Extract the label
  local label = text:match("\\label{([^}]+)}")
  local q_label = ""
  if label then
    q_label = label:gsub(":", "-")
    if not q_label:match("^eq%-") then q_label = "eq-" .. q_label end
  end

  -- 3. Strip the LaTeX wrappers to get the raw math string
  local clean_math = text:gsub("\\begin{equation%*?}", "")
                         :gsub("\\end{equation%*?}", "")
                         :gsub("\\label{[^}]+}", "")
                         :gsub("^%s+", "") -- trim leading whitespace
                         :gsub("%s+$", "") -- trim trailing whitespace

  -- 4. Return the exact AST sequence Quarto uses for numbered equations
  if q_label ~= "" then
    return pandoc.Para({
      pandoc.Math('DisplayMath', clean_math),
      pandoc.Space(),
      pandoc.Str("{#" .. q_label .. "}")
    })
  else
    return pandoc.Para({ pandoc.Math('DisplayMath', clean_math) })
  end
end

-- Target 1: Pandoc thinks it's a raw LaTeX block
function RawBlock(el)
  if el.format:match("tex") or el.format:match("latex") then
    local new_ast = process_equation(el.text)
    if new_ast then return new_ast end
  end
end

-- Target 2: Pandoc thinks it's a standard paragraph containing text/raw inlines
function Para(el)
  -- pandoc.utils.stringify flattens the paragraph into plain text
  local text = pandoc.utils.stringify(el)
  if text:find("\\begin{equation}") then
    local new_ast = process_equation(text)
    if new_ast then return new_ast end
  end
end