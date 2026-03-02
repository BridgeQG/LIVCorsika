-- Helper function to standardize labels (e.g., eq:1 -> eq-1)
local function normalize_label(lbl)
  return lbl:gsub(":", "-"):gsub("^tab%-", "tbl-"):gsub("^table%-", "tbl-")
end

-- 1. EQUATIONS (Intercepted at the Paragraph level)
function Para(el)
  if #el.content == 1 and el.content[1].t == "RawInline" then
    local raw = el.content[1]
    if raw.format == "tex" or raw.format == "latex" then
      local text = raw.text
      if text:match("\\begin{equation}") or text:match("\\begin{align}") then
        local label = text:match("\\label{([^}]+)}")
        local math_content = text:gsub("\\begin{equation%*?}", ""):gsub("\\end{equation%*?}", "")
                                 :gsub("\\begin{align%*?}", "\\begin{aligned}"):gsub("\\end{align%*?}", "\\end{aligned}")
                                 :gsub("\\label{[^}]+}", "")
        math_content = math_content:gsub("^%s+", ""):gsub("%s+$", "")
        
        if label then
          local q_label = normalize_label(label)
          if not q_label:match("^eq%-") then q_label = "eq-" .. q_label end
          return pandoc.Para({
            pandoc.Math('DisplayMath', math_content),
            pandoc.Space(),
            pandoc.Str("{#" .. q_label .. "}")
          })
        else
          return pandoc.Para({ pandoc.Math('DisplayMath', math_content) })
        end
      end
    end
  end
end

-- 2. STRUCTURAL BLOCKS (Sections, Lists, Figures)
function RawBlock(el)
  if el.format == "tex" or el.format == "latex" then
    local text = el.text

    -- Sections
    local sec = text:match("^\\section{([^}]+)}")
    if sec then return pandoc.Header(1, {pandoc.Str(sec)}) end
    
    local subsec = text:match("^\\subsection{([^}]+)}")
    if subsec then return pandoc.Header(2, {pandoc.Str(subsec)}) end
    
    local subsubsec = text:match("^\\subsubsection{([^}]+)}")
    if subsubsec then return pandoc.Header(3, {pandoc.Str(subsubsec)}) end

    -- Figures
    if text:match("\\begin{figure}") then
      local caption = text:match("\\caption{([^}]+)}") or ""
      local label = text:match("\\label{([^}]+)}")
      local args, path = text:match("\\includegraphics%[([^%]]+)%]{([^}]+)}")
      if not path then
        path = text:match("\\includegraphics{([^}]+)}")
        args = ""
      end

      local q_label = ""
      if label then
        q_label = normalize_label(label)
        if not q_label:match("^fig%-") then q_label = "fig-" .. q_label end
      end

      local q_args = ""
      if args and args ~= "" then
        q_args = args:gsub("([%w_]+)=([^,%s]+)", '%1="%2"')
      end

      local md_str = "![" .. caption .. "](" .. path .. ")"
      if q_label ~= "" or q_args ~= "" then
        md_str = md_str .. "{#" .. q_label .. " " .. q_args .. "}"
      end
      return pandoc.read(md_str, 'markdown').blocks
    end

    -- Lists (\begin{itemize}, \begin{enumerate})
    -- Pandoc natively converts standard LaTeX lists perfectly, so we just hand it off
    if text:match("\\begin{itemize}") or text:match("\\begin{enumerate}") then
      return pandoc.read(text, 'latex').blocks
    end
  end
end

-- 3. INLINE ELEMENTS (Bold, Italics, Refs, Cites, Links)
function RawInline(el)
  if el.format == "tex" or el.format == "latex" then
    local text = el.text

    -- Formatting
    local bold = text:match("^\\textbf{([^}]+)}")
    if bold then return pandoc.Strong({pandoc.Str(bold)}) end

    local italic = text:match("^\\textit{([^}]+)}")
    if italic then return pandoc.Emph({pandoc.Str(italic)}) end

    -- Hyperlinks
    local url, link_text = text:match("^\\href{([^}]+)}{([^}]+)}")
    if url and link_text then return pandoc.Link({pandoc.Str(link_text)}, url) end

    -- Cross References
    local eqref = text:match("^\\eqref{([^}]+)}")
    if eqref then
      local q_label = normalize_label(eqref)
      if not q_label:match("^eq%-") then q_label = "eq-" .. q_label end
      return pandoc.read("([-@" .. q_label .. "])", 'markdown').blocks[1].content
    end

    local ref = text:match("^\\ref{([^}]+)}")
    if ref then
      local q_label = normalize_label(ref)
      return pandoc.read("[-@" .. q_label .. "]", 'markdown').blocks[1].content
    end

    -- Citations
    local cite = text:match("^\\cite{([^}]+)}")
    if cite then
      local q_cites = cite:gsub("%s+", ""):gsub(",", "; @")
      return pandoc.read("[@" .. q_cites .. "]", 'markdown').blocks[1].content
    end
  end
end