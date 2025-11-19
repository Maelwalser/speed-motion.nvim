local M = {}

-- Seed the random number generator for non-deterministic snippet selection
math.randomseed(os.time())

-- Store all loaded snippets here
local ALL_SNIPPETS = {}

--- @brief Loads all snippets from the data file.
local function load_snippets()
  -- Use pcall for robust, failure-tolerant loading
  local ok, snippets = pcall(require, 'speed-motion.snippets') -- Adjust path if needed
  
  if not ok or type(snippets) ~= 'table' then
    vim.notify(
      "Failed to load typing snippets. Check 'speed-motion/snippets.lua'.", 
      vim.log.levels.ERROR
    )
    -- Provide a critical fallback for empirical stability
    return { 
      { "Error loading data. Check source file structure." } 
    }
  end
  return snippets
end

-- Initialize snippets on module load
ALL_SNIPPETS = load_snippets()

--- @brief Selects a random multi-line target text.
--- @return table<string> The selected snippet, where each element is a line of code.
function M.get_random_target_text()
  local num_snippets = #ALL_SNIPPETS
  
  if num_snippets == 0 then
    -- Acknowledge data failure and provide a reliable default
    return { "No valid snippets found in the data file." }
  end
  
  -- Use math.random() to ensure non-deterministic selection
  local random_index = math.random(1, num_snippets)
  
  return ALL_SNIPPETS[random_index]
end

return M
