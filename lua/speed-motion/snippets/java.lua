-- Java code snippets for typing practice

return {
  -- Class definition
  {
    "public class Main {",
    "  public static void main(String[] args) {",
    "    System.out.println(\"Hello World\");",
    "  }",
    "}",
  },

  -- Constructor
  {
    "public class User {",
    "  private String name;",
    "  ",
    "  public User(String name) {",
    "    this.name = name;",
    "  }",
    "}",
  },

  -- Interface
  {
    "public interface Repository<T> {",
    "  T findById(Long id);",
    "  List<T> findAll();",
    "  void save(T entity);",
    "}",
  },

  -- Exception handling
  {
    "try {",
    "  processData();",
    "} catch (IOException e) {",
    "  logger.error(\"Error: {}\", e.getMessage());",
    "} finally {",
    "  cleanup();",
    "}",
  },

  -- Lambda expression
  {
    "List<String> names = Arrays.asList(\"Alice\", \"Bob\");",
    "names.stream()",
    "  .filter(n -> n.startsWith(\"A\"))",
    "  .forEach(System.out::println);",
  },

  -- Getter and Setter
  {
    "private String name;",
    "",
    "public String getName() {",
    "  return name;",
    "}",
    "",
    "public void setName(String name) {",
    "  this.name = name;",
    "}",
  },

  -- Generic method
  {
    "public <T> List<T> createList(T... elements) {",
    "  List<T> list = new ArrayList<>();",
    "  for (T element : elements) {",
    "    list.add(element);",
    "  }",
    "  return list;",
    "}",
  },

  -- Enum
  {
    "public enum Status {",
    "  ACTIVE,",
    "  INACTIVE,",
    "  PENDING;",
    "}",
  },

  -- Abstract class
  {
    "public abstract class Animal {",
    "  protected String name;",
    "  ",
    "  public abstract void makeSound();",
    "  ",
    "  public String getName() {",
    "    return name;",
    "  }",
    "}",
  },

  -- Builder pattern
  {
    "public class User {",
    "  private final String name;",
    "  ",
    "  private User(Builder builder) {",
    "    this.name = builder.name;",
    "  }",
    "  ",
    "  public static class Builder {",
    "    private String name;",
    "    ",
    "    public Builder name(String name) {",
    "      this.name = name;",
    "      return this;",
    "    }",
    "    ",
    "    public User build() {",
    "      return new User(this);",
    "    }",
    "  }",
    "}",
  },
}
