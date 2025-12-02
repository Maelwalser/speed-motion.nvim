local M = {}

-- Top 200 most common English words
M.COMMON_WORDS = {
  "the", "be", "to", "of", "and", "a", "in", "that", "have", "I",
  "it", "for", "not", "on", "with", "he", "as", "you", "do", "at",
  "this", "but", "his", "by", "from", "they", "we", "say", "her", "she",
  "or", "an", "will", "my", "one", "all", "would", "there", "their", "what",
  "so", "up", "out", "if", "about", "who", "get", "which", "go", "me",
  "when", "make", "can", "like", "time", "no", "just", "him", "know", "take",
  "people", "into", "year", "your", "good", "some", "could", "them", "see", "other",
  "than", "then", "now", "look", "only", "come", "its", "over", "think", "also",
  "back", "after", "use", "two", "how", "our", "work", "first", "well", "way",
  "even", "new", "want", "because", "any", "these", "give", "day", "most", "us",
  "is", "was", "are", "been", "has", "had", "were", "said", "did", "having",
  "may", "should", "does", "being", "might", "must", "shall", "can", "could", "ought",
  "need", "dare", "used", "him", "man", "life", "child", "such", "made", "between",
  "own", "through", "where", "much", "before", "right", "too", "means", "old", "any",
  "same", "tell", "does", "set", "three", "want", "air", "well", "also", "play",
  "small", "end", "put", "home", "read", "hand", "port", "large", "spell", "add",
  "even", "land", "here", "must", "big", "high", "such", "follow", "act", "why",
  "ask", "men", "change", "went", "light", "kind", "off", "need", "house", "picture",
  "try", "us", "again", "animal", "point", "mother", "world", "near", "build", "self",
  "earth", "father", "head", "stand", "own", "page", "should", "country", "found", "answer"
}

--- Generates a random sequence of words
--- @param count number Number of words to generate
--- @return string The generated word sequence
function M.generate_word_sequence(count)
  local words = {}
  local word_count = #M.COMMON_WORDS

  for i = 1, count do
    local random_index = math.random(1, word_count)
    table.insert(words, M.COMMON_WORDS[random_index])
  end

  return table.concat(words, " ")
end

--- Counts correctly typed words in the typed text compared to target
--- @param typed string The text the user typed
--- @param target string The target text
--- @return number Number of correctly typed words
function M.count_correct_words(typed, target)
  local typed_words = vim.split(typed, " ", { plain = true, trimempty = true })
  local target_words = vim.split(target, " ", { plain = true, trimempty = true })

  local correct_count = 0
  for i, typed_word in ipairs(typed_words) do
    if target_words[i] and typed_word == target_words[i] then
      correct_count = correct_count + 1
    end
  end

  return correct_count
end

--- Calculates words per minute
--- @param word_count number Number of words typed correctly
--- @param seconds number Time elapsed in seconds
--- @return number Words per minute
function M.calculate_wpm(word_count, seconds)
  if seconds == 0 then
    return 0
  end
  return math.floor((word_count / seconds) * 60)
end

return M
