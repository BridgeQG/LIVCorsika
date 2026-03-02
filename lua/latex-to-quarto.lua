function Math(el)
  -- 1. Check if it is a display equation (not inline $math$)
  if el.mathtype == 'DisplayMath' then
    
    -- 2. Look for the label inside the LaTeX
    local label = el.text:match('\\label{([^}]+)}')
    
    if label then
      -- 3. Strip out the LaTeX wrapper and the label to isolate the math string
      local inner_math = el.text:gsub('\\begin{equation%*?}', '')
                                :gsub('\\end{equation%*?}', '')
                                :gsub('\\label{[^}]+}', '')
      
      -- Clean up any extra empty lines
      inner_math = inner_math:gsub("^\n+", ""):gsub("\n+$", "")
      
      -- 4. Format the label for Quarto
      local q_label = label:gsub(':', '-')
      if not q_label:match('^eq%-') then
        q_label = 'eq-' .. q_label
      end
      
      -- 5. Return the exact AST sequence Quarto's crossref engine looks for:
      -- [Math Node] + [Space] + [{#label} String]
      return {
        pandoc.Math('DisplayMath', inner_math),
        pandoc.Space(),
        pandoc.Str('{#' .. q_label .. '}')
      }
    end
  end
  
  -- Leave other math untouched
  return nil
end