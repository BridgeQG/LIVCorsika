-- =======================================================================
-- 1. CONFIGURATION TABLES (Add new rules here!)
-- =======================================================================

local section_rules = {
    section = 1,
    subsection = 2,
    subsubsection = 3
}

local inline_rules = {
    { pattern = "\\textbf{([^}]+)}", replace = "**%1**" },
    { pattern = "\\textit{([^}]+)}", replace = "*%1*" },
    { pattern = "\\href{([^}]+)}{([^}]+)}", replace = "[%2](%1)" },
    { pattern = "\\cite{([^}]+)}", replace = function(cites)
        local cite_str = ""
        for ref in string.gmatch(cites, "[^,%s]+") do
            if cite_str == "" then cite_str = "[@" .. ref
            else cite_str = cite_str .. "; @" .. ref end
        end
        return cite_str .. "]"
    end},
    { pattern = "\\ref{([^}]+)}", replace = function(ref)
        ref = string.gsub(ref, "^eq:", "eq-")
        ref = string.gsub(ref, "^sec:", "sec-")
        return "[-@" .. ref .. "]"
    end},
    { pattern = "\\eqref{([^}]+)}", replace = function(eqref)
        eqref = string.gsub(eqref, "^eq:", "eq-")
        return "([-@" .. eqref .. "])"
    end}
}

-- THIS IS HOW YOU GENERALIZE ENVIRONMENTS
-- Key = environment name. Value = function that builds the markdown block.
local environment_rules = {
    equation = function(content, label)
        local md = "$$\n" .. content .. "\n$$"
        if label then
            -- Safely normalize Quarto label prefixes
            local q_label = string.gsub(label, "^eq:", "eq-")
            if not string.match(q_label, "^eq%-") then q_label = "eq-" .. q_label end
            md = md .. " {#" .. q_label .. "}"
        end
        return md
    end
    
    -- Example for the future: If you wanted to add a quote environment:
    -- quote = function(content, label)
    --     return "> " .. string.gsub(content, "\n", "\n> ")
    -- end
}

-- =======================================================================
-- 2. THE TRANSLATOR ENGINE
-- =======================================================================

local function apply_rules(text)
    local original_text = text

    -- A. Check Environments (Produces a Block)
    for env_name, env_func in pairs(environment_rules) do
        -- Matches \begin{env} ... \end{env} (handles optional * like equation*)
        local env_pattern = "\\begin{" .. env_name .. "%*?}(.-)\\end{" .. env_name .. "%*?}"
        local content = string.match(text, env_pattern)
        
        if content then
            local label = string.match(content, "\\label{([^}]+)}")
            if label then
                content = string.gsub(content, "\\label{[^}]+}", "")
            end
            
            content = content:match("^%s*(.-)%s*$") -- clean whitespace
            
            local md = env_func(content, label)
            return md, "block"
        end
    end

    -- B. Check Sections (Produces a Block)
    for cmd, level in pairs(section_rules) do
        local sec_pattern = "\\" .. cmd .. "{([^}]+)}"
        local title = string.match(text, sec_pattern)
        if title then
            local prefix = string.rep("#", level)
            return "\n" .. prefix .. " " .. title .. "\n", "block"
        end
    end

    -- C. Check Inlines (Produces Inline text)
    for _, rule in ipairs(inline_rules) do
        text = string.gsub(text, rule.pattern, rule.replace)
    end
    
    if text ~= original_text then
        return text, "inline"
    end

    return nil, nil
end

-- =======================================================================
-- 3. THE AST WALKER (Paragraph Splitter & AST Compiler)
-- =======================================================================

function Blocks(blocks)
    local new_blocks = pandoc.List()
    
    for _, block in ipairs(blocks) do
        -- If it's a Paragraph, we look inside for inline LaTeX that needs block splitting
        if block.t == "Para" or block.t == "Plain" then
            local current_inlines = pandoc.List()
            
            local function flush_inlines()
                if #current_inlines > 0 then
                    new_blocks:insert(pandoc.Para(current_inlines))
                    current_inlines = pandoc.List()
                end
            end

            for _, el in ipairs(block.content) do
                if el.t == "RawInline" and (el.format == "tex" or el.format == "latex") then
                    local md, result_type = apply_rules(el.text)
                    
                    if result_type == "block" then
                        -- Environment or Section found inside a paragraph!
                        flush_inlines() -- Close off the paragraph so far
                        
                        -- Re-compile the new block natively via pandoc.read
                        local doc = pandoc.read(md, "markdown")
                        for _, b in ipairs(doc.blocks) do
                            new_blocks:insert(b)
                        end
                        
                    elseif result_type == "inline" then
                        -- Standard inline replacement
                        local doc = pandoc.read(md, "markdown")
                        if doc.blocks[1] and doc.blocks[1].content then
                            for _, inline_el in ipairs(doc.blocks[1].content) do
                                current_inlines:insert(inline_el)
                            end
                        end
                    else
                        -- Not recognized, leave untouched
                        current_inlines:insert(el)
                    end
                else
                    -- Standard text
                    current_inlines:insert(el)
                end
            end
            flush_inlines() -- Final close off
            
        -- If it's an isolated RawBlock
        elseif block.t == "RawBlock" and (block.format == "tex" or block.format == "latex") then
            local md, result_type = apply_rules(block.text)
            if md then
                local doc = pandoc.read(md, "markdown")
                for _, b in ipairs(doc.blocks) do
                    new_blocks:insert(b)
                end
            else
                new_blocks:insert(block)
            end
        else
            -- Keep any other block (Headers, Tables, etc.) exactly as it is
            new_blocks:insert(block)
        end
    end
    
    return new_blocks
end