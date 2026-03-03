-- Helper: Safely standardize labels
local function normalize_label(lbl)
  if not lbl then return "" end
  return lbl:gsub(":", "-"):gsub("^tab%-", "tbl-")
end

-- =====================================================================
-- THE UNIVERSAL TRANSLATOR: Only handles equations, refs, cites, and headers
-- =====================================================================
local function translate_to_quarto(text)
  
  -- 1. Equations
  if text:match("\\begin{equation}") then
    local label = text:match("\\label{([^}]+)}")
    local math = text:gsub("\\begin{equation%*?}", ""):gsub("\\end{equation%*?}", "")
                     :gsub("\\label{[^}]+}", "")
    math = math:gsub("^%s+", ""):gsub("%s+$", "")
    
    local md = "$$\n" .. math .. "\n$$"
    if label then
      local q_label = normalize_label(label)
      if not q_label:match("^eq%-") then q_label = "eq-" .. q_label end
      md = md .. " {#" .. q_label .. "}"
    end
    return md, "markdown" 
  end

  -- 2. Cross-References & Citations
  local eqref = text:match("^\\eqref{([^}]+)}")
  if eqref then 
    local q_label = normalize_label(eqref)
    if not q_label:match("^eq%-") then q_label = "eq-" .. q_label end
    return "([-@" .. q_label .. "])", "markdown" 
  end

  local ref = text:match("^\\ref{([^}]+)}")
  if ref then return "[-@" .. normalize_label(ref) .. "]", "markdown" end

  local cite = text:match("^\\cite{([^}]+)}")
  if cite then return "[@" .. cite:gsub("%s+", ""):gsub(",", "; @") .. "]", "markdown" end

  -- 3. Sections
  local sec = text:match("^\\section{([^}]+)}")
  if sec then return "\n# " .. sec .. "\n", "markdown" end
  
  local subsec = text:match("^\\subsection{([^}]+)}")
  if subsec then return "\n## " .. subsec .. "\n", "markdown" end
  
  local subsubsec = text:match("^\\subsubsection{([^}]+)}")
  if subsubsec then return "\n### " .. subsubsec .. "\n", "markdown" end

  -- If it is anything else (figures, tables, random formatting), ignore it entirely.
  return nil, nil
end


-- =====================================================================
-- THE DELIVERY DRIVERS
-- =====================================================================

function RawInline(el)
  if el.format == "tex" or el.format == "latex" then
    local converted_text, format_type = translate_to_quarto(el.text)
    
    if format_type == "markdown" then
      local doc = pandoc.read(converted_text, "markdown")
      if doc.blocks[1] and doc.blocks[1].content then
        return doc.blocks[1].content
      end
    end
  end
  -- By returning nothing here, Pandoc leaves the original LaTeX completely untouched
end

function RawBlock(el)
  if el.format == "tex" or el.format == "latex" then
    local converted_text, format_type = translate_to_quarto(el.text)
    
    if format_type == "markdown" then
      return pandoc.read(converted_text, "markdown").blocks
    end
  end
  -- By returning nothing here, Pandoc leaves the original LaTeX completely untouched
end