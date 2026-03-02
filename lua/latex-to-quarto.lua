-- Helper: Standardize labels
local function normalize_label(lbl)
  if not lbl then return "" end
  return lbl:gsub(":", "-"):gsub("^tab%-", "tbl-"):gsub("^table%-", "tbl-")
end

-- =====================================================================
-- THE UNIVERSAL TRANSLATOR
-- =====================================================================
local function translate_to_quarto(text)
  
  -- 1. Equations
  if text:match("\\begin{equation}") or text:match("\\begin{align}") then
    -- ... (Equation extraction logic remains exactly the same)
    
    local md = "$$\n" .. math .. "\n$$"
    if label then
      md = md .. " {#" .. q_label .. "}"
    end
    -- RETURN AS RAW MARKDOWN BLOCK
    return pandoc.RawBlock("markdown", md) 
  end

  -- 2. Figures
  if text:match("\\begin{figure}") then
    local caption = text:match("\\caption{([^}]+)}") or ""
    local label = text:match("\\label{([^}]+)}")
    local args, path = text:match("\\includegraphics%[([^%]]+)%]{([^}]+)}")
    if not path then path = text:match("\\includegraphics{([^}]+)}"); args = "" end

    if path then
      local q_label = ""
      if label then
        q_label = normalize_label(label)
        if not q_label:match("^fig%-") then q_label = "fig-" .. q_label end
      end
      
      local q_args = ""
      if args and args ~= "" then 
        -- Convert width=4cm to width="4cm"
        q_args = args:gsub("([%w_]+)=([^,%s]+)", '%1="%2"') 
      end

      local md = "![" .. caption .. "](" .. path .. ")"
      if q_label ~= "" or q_args ~= "" then 
        md = md .. "{#" .. q_label .. " " .. q_args .. "}" 
      end
      
      -- RETURN AS RAW MARKDOWN BLOCK
      return pandoc.RawBlock("markdown", md)
    end
  end

  -- ... (Rest of the formatting rules) ...

  -- 5. THE CATCH-ALL FALLBACK (Tables, unsupported macros)
  local clean_text = text:gsub("\\label{([^}]+)}", function(lbl)
    return "\\label{" .. normalize_label(lbl) .. "}"
  end)
  -- RETURN AS RAW LATEX BLOCK
  return pandoc.RawBlock("tex", clean_text)
end


-- =====================================================================
-- THE DELIVERY DRIVERS: Inject the translated code back into the AST
-- =====================================================================

function RawInline(el)
  if el.format == "tex" or el.format == "latex" then
    return translate_to_quarto(el.text)
  end
end

function RawBlock(el)
  if el.format == "tex" or el.format == "latex" then
    return translate_to_quarto(el.text)
  end
end