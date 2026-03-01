/**
 * Fluent Builder Pattern Implementation
 * Immutable User class with required/optional fields and validation.
 */

import java.util.Objects;
import java.util.Optional;
import java.util.regex.Pattern;

public class User {
    private static final Pattern EMAIL_PATTERN =
        Pattern.compile("^[A-Za-z0-9+_.-]+@[A-Za-z0-9.-]+$");

    // Required fields
    private final String id;
    private final String email;

    // Optional fields
    private final String name;
    private final Integer age;
    private final String address;
    private final String phone;

    private User(Builder builder) {
        this.id = builder.id;
        this.email = builder.email;
        this.name = builder.name;
        this.age = builder.age;
        this.address = builder.address;
        this.phone = builder.phone;
    }

    // Getters (no setters - immutable)
    public String getId() { return id; }
    public String getEmail() { return email; }
    public Optional<String> getName() { return Optional.ofNullable(name); }
    public Optional<Integer> getAge() { return Optional.ofNullable(age); }
    public Optional<String> getAddress() { return Optional.ofNullable(address); }
    public Optional<String> getPhone() { return Optional.ofNullable(phone); }

    @Override
    public boolean equals(Object o) {
        if (this == o) return true;
        if (o == null || getClass() != o.getClass()) return false;
        User user = (User) o;
        return Objects.equals(id, user.id) &&
               Objects.equals(email, user.email) &&
               Objects.equals(name, user.name) &&
               Objects.equals(age, user.age) &&
               Objects.equals(address, user.address) &&
               Objects.equals(phone, user.phone);
    }

    @Override
    public int hashCode() {
        return Objects.hash(id, email, name, age, address, phone);
    }

    @Override
    public String toString() {
        return "User{" +
               "id='" + id + '\'' +
               ", email='" + email + '\'' +
               ", name='" + name + '\'' +
               ", age=" + age +
               ", address='" + address + '\'' +
               ", phone='" + phone + '\'' +
               '}';
    }

    public static Builder builder() {
        return new Builder();
    }

    public static class Builder {
        private String id;
        private String email;
        private String name;
        private Integer age;
        private String address;
        private String phone;

        public Builder() {}

        // Required field setters
        public Builder id(String id) {
            this.id = id;
            return this;
        }

        public Builder email(String email) {
            this.email = email;
            return this;
        }

        // Optional field setters
        public Builder name(String name) {
            this.name = name;
            return this;
        }

        public Builder age(int age) {
            this.age = age;
            return this;
        }

        public Builder address(String address) {
            this.address = address;
            return this;
        }

        public Builder phone(String phone) {
            this.phone = phone;
            return this;
        }

        public User build() {
            validate();
            return new User(this);
        }

        private void validate() {
            // Validate required fields
            if (id == null || id.trim().isEmpty()) {
                throw new IllegalStateException("id is required");
            }
            if (email == null || email.trim().isEmpty()) {
                throw new IllegalStateException("email is required");
            }

            // Validate email format
            if (!EMAIL_PATTERN.matcher(email).matches()) {
                throw new IllegalArgumentException("Invalid email format: " + email);
            }

            // Validate optional fields if present
            if (age != null && (age < 0 || age > 150)) {
                throw new IllegalArgumentException("Invalid age: " + age);
            }
        }
    }
}

// Additional builder examples for different use cases

class HttpRequest {
    private final String method;
    private final String url;
    private final java.util.Map<String, String> headers;
    private final String body;
    private final int timeout;

    private HttpRequest(Builder builder) {
        this.method = builder.method;
        this.url = builder.url;
        this.headers = java.util.Collections.unmodifiableMap(new java.util.HashMap<>(builder.headers));
        this.body = builder.body;
        this.timeout = builder.timeout;
    }

    public String getMethod() { return method; }
    public String getUrl() { return url; }
    public java.util.Map<String, String> getHeaders() { return headers; }
    public String getBody() { return body; }
    public int getTimeout() { return timeout; }

    public static Builder builder(String method, String url) {
        return new Builder(method, url);
    }

    public static class Builder {
        private final String method;
        private final String url;
        private final java.util.Map<String, String> headers = new java.util.HashMap<>();
        private String body;
        private int timeout = 30000; // Default 30 seconds

        public Builder(String method, String url) {
            this.method = Objects.requireNonNull(method, "method is required");
            this.url = Objects.requireNonNull(url, "url is required");
        }

        public Builder header(String name, String value) {
            this.headers.put(name, value);
            return this;
        }

        public Builder body(String body) {
            this.body = body;
            return this;
        }

        public Builder timeout(int timeout) {
            if (timeout < 0) {
                throw new IllegalArgumentException("timeout must be non-negative");
            }
            this.timeout = timeout;
            return this;
        }

        public HttpRequest build() {
            return new HttpRequest(this);
        }
    }
}
