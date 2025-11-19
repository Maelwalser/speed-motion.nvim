-- Go code snippets for typing practice

return {
  -- Basic function
  {
    "func main() {",
    "  fmt.Println(\"Hello, World!\")",
    "}",
  },

  -- Struct definition
  {
    "type User struct {",
    "  ID   int",
    "  Name string",
    "  Age  int",
    "}",
  },

  -- Interface
  {
    "type Reader interface {",
    "  Read(p []byte) (n int, err error)",
    "}",
  },

  -- Method with receiver
  {
    "func (u *User) GetName() string {",
    "  return u.Name",
    "}",
  },

  -- Error handling
  {
    "if err != nil {",
    "  return fmt.Errorf(\"failed: %w\", err)",
    "}",
  },

  -- Goroutine
  {
    "go func() {",
    "  defer close(ch)",
    "  processData()",
    "}()",
  },

  -- Channel operation
  {
    "select {",
    "case msg := <-ch:",
    "  fmt.Println(msg)",
    "case <-time.After(time.Second):",
    "  fmt.Println(\"timeout\")",
    "}",
  },

  -- Slice operation
  {
    "items := make([]string, 0, 10)",
    "items = append(items, \"new item\")",
    "for _, item := range items {",
    "  fmt.Println(item)",
    "}",
  },

  -- Map usage
  {
    "cache := make(map[string]int)",
    "cache[\"key\"] = 42",
    "if val, ok := cache[\"key\"]; ok {",
    "  fmt.Println(val)",
    "}",
  },

  -- Defer statement
  {
    "func processFile(path string) error {",
    "  f, err := os.Open(path)",
    "  if err != nil {",
    "    return err",
    "  }",
    "  defer f.Close()",
    "  return nil",
    "}",
  },
}
