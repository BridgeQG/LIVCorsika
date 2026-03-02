-- latex-to-quarto.lua

local function normalize_label(lbl)
  -- Swap colons for hyphens and normalize table prefixes
  return lbl:gsub(":", "-")
            :gsub("^tab%-", "tbl-")
            :gsub("^table%-", "tbl-")
end

return {
  -- 1. EQUATIONS: Intercept the Paragraph containing the Math
  {
    Para = function(el)
      if #el.content >= 1 and el.content[1].t == 'Math' and el.content[1].mathtype == 'DisplayMath' then
        local text = el.content[1].text
        local label = text:match("\\label{([^}]+)}")
        
        if label then
          -- Strip the label and the wrapper environments
          local clean_math = text:gsub("\\label{[^}]+}", "")
          clean_math = clean_math:gsub("\\begin{equation%*?}%s*", "")
                                 :gsub("\\end{equation%*?}%s*", "")
                                 :gsub("\\begin{align%*?}", "\\begin{aligned}")
                                 :gsub("\\end{align%*?}", "\\end{aligned}")
          
          local q_label = normalize_label(label)
          if not q_label:match("^eq%-") then q_label = "eq-" .. q_label end
          
          -- Rebuild the Para to exactly match Quarto's native crossref AST:
          -- [Math Node] + [Space] + [Str Node with {#eq-label}]
          return pandoc.Para({
            pandoc.Math('DisplayMath', clean_math),
            pandoc.Space(),
            pandoc.Str("{#" .. q_label .. "}")
          })
        end
      end
      return nil
    end
  },
  
  -- 2. BLOCKS: Figures, Tables, Sections
  {
    RawBlock = function(el)
      if el.format == 'tex' or el.format == 'latex' then
        local text = el.text

        -- Figures
        if text:match("\\begin{figure}") then
          local caption = text:match("\\caption{([^}]+)}") or ""
          local label = text:match("\\label{([^}]+)}") or ""
          
          local args, path = text:match("\\includegraphics%[([^%]]+)%]{([^}]+)}")
          if not path then
            path = text:match("\\includegraphics{([^}]+)}")
            args = ""
          end

          local q_label = normalize_label(label)
          if q_label ~= "" and not q_label:match("^fig%-") then 
             q_label = "fig-" .. q_label 
          end
          
          local md_str = "![" .. caption .. "](" .. path .. ")"
          if q_label ~= "" then
             md_str = md_str .. "{#" .. q_label .. "}"
          end
          return pandoc.read(md_str, 'markdown').blocks
        end

        -- Headers / Sections
        local sec_title = text:match("\\section{([^}]+)}")
        if sec_title then return pandoc.Header(1, sec_title) end
        
        local subsec_title = text:match("\\subsection{([^}]+)}")
        if subsec_title then return pandoc.Header(2, subsec_title) end

        local subsubsec_title = text:match("\\subsubsection{([^}]+)}")
        if subsubsec_title then return pandoc.Header(3, subsubsec_title) end
      end
      return nil
    end
  },

  -- 3. INLINES: Cross-refs, Citations, Formatting
  {
    RawInline = function(el)
      if el.format == 'tex' or el.format == 'latex' then
        local text = el.text

        -- \eqref{} or \ref{}
        local is_eqref = text:match("^\\eqref")
        local ref_lbl = text:match("^\\eqref{([^}]+)}") or text:match("^\\ref{([^}]+)}")
        if ref_lbl then
          local q_label = normalize_label(ref_lbl)
          -- Ensure equations have the eq- prefix so Quarto formats them as "Eq. X"
          if is_eqref and not q_label:match("^eq%-") then q_label = "eq-" .. q_label end
          
          local md_str = "@" .. q_label
          return pandoc.read(md_str, 'markdown').blocks[1].content
        end

        -- \cite{}
        local cite_lbl = text:match("^\\cite{([^}]+)}")
        if cite_lbl then
          local q_cites = cite_lbl:gsub("%s+", ""):gsub(",", "; @")
          return pandoc.read("[@" .. q_cites .. "]", 'markdown').blocks[1].content
        end

        -- \textbf{} and \textit{}
        local bold_text = text:match("^\\textbf{([^}]+)}")
        if bold_text then return pandoc.Strong({pandoc.Str(bold_text)}) end

        local italic_text = text:match("^\\textit{([^}]+)}")
        if italic_text then return pandoc.Emph({pandoc.Str(italic_text)}) end
      end
      return nil
    end
  }
}