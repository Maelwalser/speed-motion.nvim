local M = {}

-- Seed the random number generator for non-deterministic snippet selection
math.randomseed(os.time())

-- Available languages and their display names
M.LANGUAGES = {
  { id = "golang", name = "Go", module = "speed-motion.snippets.golang" },
  { id = "java", name = "Java", module = "speed-motion.snippets.java" },
  { id = "rust", name = "Rust", module = "speed-motion.snippets.rust" },
}

-- Cache for loaded snippets per language
local snippet_cache = {}

--- @brief Loads snippets for a specific language.
--- @param language_id string The language identifier (e.g., "golang", "java", "rust")
--- @return table<table<string>> The snippets for the language
local function load_snippets(language_id)
  -- Check cache first
  if snippet_cache[language_id] then
    return snippet_cache[language_id]
  end

  -- Find the language module path
  local module_path = nil
  for _, lang in ipairs(M.LANGUAGES) do
    if lang.id == language_id then
      module_path = lang.module
      break
    end
  end

  if not module_path then
    vim.notify(
      "Unknown language: " .. language_id,
      vim.log.levels.ERROR
    )
    return { { "Error: Unknown language." } }
  end

  -- Use pcall for robust, failure-tolerant loading
  local ok, snippets = pcall(require, module_path)

  if not ok or type(snippets) ~= 'table' then
    vim.notify(
      "Failed to load snippets for " .. language_id .. ". Check '" .. module_path .. ".lua'.",
      vim.log.levels.ERROR
    )
    -- Provide a critical fallback
    return {
      { "Error loading data. Check source file structure." }
    }
  end

  -- Cache the loaded snippets
  snippet_cache[language_id] = snippets
  return snippets
end

--- @brief Selects a random multi-line snippet for the specified language.
--- @param language_id string The language identifier (e.g., "golang", "java", "rust")
--- @return table<string> The selected snippet, where each element is a line of code.
function M.get_random_snippet(language_id)
  local snippets = load_snippets(language_id)
  local num_snippets = #snippets

  if num_snippets == 0 then
    -- Acknowledge data failure and provide a reliable default
    return { "No valid snippets found in the data file." }
  end

  -- Use math.random() to ensure non-deterministic selection
  local random_index = math.random(1, num_snippets)

  return snippets[random_index]
end

--- @brief Gets the list of available languages
--- @return table<table> List of language configs with id and name
function M.get_languages()
  return M.LANGUAGES
end

return M
