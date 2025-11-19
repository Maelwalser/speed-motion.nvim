-- Rust code snippets for typing practice

return {
  -- Main function
  {
    "fn main() {",
    "  println!(\"Hello, world!\");",
    "}",
  },

  -- Struct definition
  {
    "struct User {",
    "  id: u32,",
    "  name: String,",
    "  email: String,",
    "}",
  },

  -- Impl block
  {
    "impl User {",
    "  fn new(id: u32, name: String) -> Self {",
    "    User {",
    "      id,",
    "      name,",
    "      email: String::new(),",
    "    }",
    "  }",
    "}",
  },

  -- Trait definition
  {
    "trait Drawable {",
    "  fn draw(&self);",
    "  fn description(&self) -> String {",
    "    String::from(\"A drawable object\")",
    "  }",
    "}",
  },

  -- Match expression
  {
    "match result {",
    "  Ok(value) => println!(\"Success: {}\", value),",
    "  Err(e) => eprintln!(\"Error: {}\", e),",
    "}",
  },

  -- Option handling
  {
    "fn find_user(id: u32) -> Option<User> {",
    "  if id > 0 {",
    "    Some(User::new(id, String::from(\"John\")))",
    "  } else {",
    "    None",
    "  }",
    "}",
  },

  -- Result with error handling
  {
    "fn read_file(path: &str) -> Result<String, io::Error> {",
    "  let mut file = File::open(path)?;",
    "  let mut contents = String::new();",
    "  file.read_to_string(&mut contents)?;",
    "  Ok(contents)",
    "}",
  },

  -- Iterator chain
  {
    "let result: Vec<i32> = vec![1, 2, 3, 4, 5]",
    "  .iter()",
    "  .filter(|&&x| x % 2 == 0)",
    "  .map(|&x| x * 2)",
    "  .collect();",
  },

  -- Enum with variants
  {
    "enum Message {",
    "  Quit,",
    "  Move { x: i32, y: i32 },",
    "  Write(String),",
    "  ChangeColor(u8, u8, u8),",
    "}",
  },

  -- Generic function
  {
    "fn largest<T: PartialOrd>(list: &[T]) -> &T {",
    "  let mut largest = &list[0];",
    "  for item in list {",
    "    if item > largest {",
    "      largest = item;",
    "    }",
    "  }",
    "  largest",
    "}",
  },

  -- Lifetime annotation
  {
    "fn longest<'a>(x: &'a str, y: &'a str) -> &'a str {",
    "  if x.len() > y.len() {",
    "    x",
    "  } else {",
    "    y",
    "  }",
    "}",
  },

  -- Closure
  {
    "let add_one = |x: i32| -> i32 { x + 1 };",
    "let result = vec![1, 2, 3]",
    "  .into_iter()",
    "  .map(add_one)",
    "  .collect::<Vec<i32>>();",
  },
}
