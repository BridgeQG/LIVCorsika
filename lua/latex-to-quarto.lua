local function normalize_label(lbl)
  -- Swap colons for hyphens and fix table prefixes
  return lbl:gsub(":", "-")
            :gsub("^tab%-", "tbl-")
            :gsub("^table%-", "tbl-")
end

-- 1. EQUATIONS
function Math(el)
  if el.mathtype == 'DisplayMath' then
    -- Quarto natively handles \label{} inside Math nodes in .qmd files!
    -- We just need to correct the label format inside the math string.
    el.text = el.text:gsub("\\label{([^}]+)}", function(lbl)
      local q_label = normalize_label(lbl)
      if not q_label:match("^eq%-") then q_label = "eq-" .. q_label end
      return "\\label{" .. q_label .. "}"
    end)
  end
  return el
end

-- 2. INLINE REFERENCES
function RawInline(el)
  if el.format == 'tex' or el.format == 'latex' then
    local text = el.text

    -- \eqref{eq:label} or \ref{eq:label} -> @eq-label
    local ref_lbl = text:match("^\\eqref{([^}]+)}%s*$") or text:match("^\\ref{([^}]+)}%s*$")
    if ref_lbl then
      local q_label = normalize_label(ref_lbl)
      if text:match("^\\eqref") and not q_label:match("^eq%-") then 
        q_label = "eq-" .. q_label 
      end
      
      -- Let Quarto natively generate the "Eq. X" or "Figure Y" formatting
      local doc = pandoc.read("@" .. q_label, 'markdown')
      return doc.blocks[1].content
    end

    -- \cite{...} -> [@cite]
    local cite_lbl = text:match("^\\cite{([^}]+)}%s*$")
    if cite_lbl then
      local q_cites = cite_lbl:gsub("%s+", ""):gsub(",", "; @")
      local doc = pandoc.read("[@" .. q_cites .. "]", 'markdown')
      return doc.blocks[1].content
    end
  end
  return el
end

-- 3. LATEX BLOCKS (Figures, Tables)
function RawBlock(el)
  if el.format == 'tex' or el.format == 'latex' then
    -- Fix any labels buried in raw LaTeX environments
    el.text = el.text:gsub("\\label{([^}]+)}", function(lbl)
      return "\\label{" .. normalize_label(lbl) .. "}"
    end)
  end
  return el
end