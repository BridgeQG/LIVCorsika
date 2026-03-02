local function normalize_label(lbl)
  return lbl:gsub("^eq:", "eq-")
            :gsub("^fig:", "fig-")
            :gsub("^tab:", "tbl-")
            :gsub("^sec:", "sec-")
end

function Math(el)
  if el.mathtype == 'DisplayMath' then
    local label = el.text:match("\\label{([^}]+)}")
    if label then
      local clean_math = el.text:gsub("\\label{[^}]+}%s*", "")
      local q_label = normalize_label(label)
      if not q_label:match("^eq%-") then q_label = "eq-" .. q_label end
      
      -- Create the Markdown string, then force Pandoc to parse it into AST nodes
      local md_text = "$$\n" .. clean_math .. "\n$$ {#" .. q_label .. "}"
      local doc = pandoc.read(md_text, 'markdown')
      
      if doc.blocks and #doc.blocks > 0 and doc.blocks[1].t == "Para" then
        return doc.blocks[1].content
      end
    end
  end
  return el
end

function RawInline(el)
  if el.format == 'tex' or el.format == 'latex' then
    local text = el.text

    -- A. \eqref{...} -> Renders as (1)
    local eqref_lbl = text:match("^\\eqref{([^}]+)}%s*$")
    if eqref_lbl then
      local q_label = normalize_label(eqref_lbl)
      if not q_label:match("^eq%-") then q_label = "eq-" .. q_label end
      local doc = pandoc.read("([-@" .. q_label .. "])", 'markdown')
      return doc.blocks[1].content
    end

    -- B. \ref{...} -> Renders as 1
    local ref_lbl = text:match("^\\ref{([^}]+)}%s*$")
    if ref_lbl then
      local q_label = normalize_label(ref_lbl)
      local doc = pandoc.read("[-@" .. q_label .. "]", 'markdown')
      return doc.blocks[1].content
    end

    -- C. \cite{...} -> Renders citations
    local cite_lbl = text:match("^\\cite{([^}]+)}%s*$")
    if cite_lbl then
      local q_cites = cite_lbl:gsub("%s+", ""):gsub(",", "; @")
      local doc = pandoc.read("[@" .. q_cites .. "]", 'markdown')
      return doc.blocks[1].content
    end

    -- D. Pass other inline LaTeX to standard reader
    local doc = pandoc.read(text, 'latex')
    if doc.blocks and #doc.blocks > 0 and doc.blocks[1].t == "Para" then
      return doc.blocks[1].content
    end
  end
  return el
end

function RawBlock(el)
  if el.format == 'tex' or el.format == 'latex' then
    -- Normalize labels inside LaTeX blocks (like \begin{figure}) before reading
    local clean_tex = el.text:gsub("\\label{([^}]+)}", function(lbl)
      return "\\label{" .. normalize_label(lbl) .. "}"
    end)
    local doc = pandoc.read(clean_tex, 'latex')
    return doc.blocks
  end
  return el
end