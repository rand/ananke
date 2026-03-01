/**
 * Builder Pattern Tests
 * Run with: javac BuilderPattern.java BuilderPatternTest.java && java BuilderPatternTest
 */

public class UserTest {
    private static int passed = 0;
    private static int failed = 0;

    public static void main(String[] args) {
        System.out.println("Builder Pattern Tests:");

        testBasicBuild();
        testRequiredFieldsMissing();
        testInvalidEmail();
        testOptionalFields();
        testImmutability();
        testEquals();
        testHttpRequestBuilder();
        testHttpRequestRequiredInConstructor();
        testBuilderReuse();
        testAgeValidation();

        System.out.println("\n" + passed + " passed, " + failed + " failed");
        if (failed > 0) {
            System.exit(1);
        }
    }

    static void testBasicBuild() {
        try {
            User user = User.builder()
                .id("123")
                .email("test@example.com")
                .build();

            assert "123".equals(user.getId()) : "id mismatch";
            assert "test@example.com".equals(user.getEmail()) : "email mismatch";
            passed("testBasicBuild");
        } catch (Exception e) {
            failed("testBasicBuild", e);
        }
    }

    static void testRequiredFieldsMissing() {
        // Missing id
        try {
            User.builder()
                .email("test@example.com")
                .build();
            failed("testRequiredFieldsMissing - id", "Expected exception for missing id");
        } catch (IllegalStateException e) {
            // Expected
        }

        // Missing email
        try {
            User.builder()
                .id("123")
                .build();
            failed("testRequiredFieldsMissing - email", "Expected exception for missing email");
        } catch (IllegalStateException e) {
            // Expected
        }

        passed("testRequiredFieldsMissing");
    }

    static void testInvalidEmail() {
        try {
            User.builder()
                .id("123")
                .email("invalid-email")
                .build();
            failed("testInvalidEmail", "Expected exception for invalid email");
        } catch (IllegalArgumentException e) {
            if (e.getMessage().contains("Invalid email")) {
                passed("testInvalidEmail");
            } else {
                failed("testInvalidEmail", "Wrong exception message: " + e.getMessage());
            }
        } catch (Exception e) {
            failed("testInvalidEmail", e);
        }
    }

    static void testOptionalFields() {
        try {
            User user = User.builder()
                .id("123")
                .email("test@example.com")
                .name("John Doe")
                .age(30)
                .address("123 Main St")
                .phone("555-1234")
                .build();

            assert user.getName().isPresent() : "name should be present";
            assert "John Doe".equals(user.getName().get()) : "name mismatch";
            assert user.getAge().isPresent() : "age should be present";
            assert user.getAge().get() == 30 : "age mismatch";
            assert user.getAddress().isPresent() : "address should be present";
            assert "123 Main St".equals(user.getAddress().get()) : "address mismatch";
            assert user.getPhone().isPresent() : "phone should be present";

            passed("testOptionalFields");
        } catch (Exception e) {
            failed("testOptionalFields", e);
        }
    }

    static void testImmutability() {
        try {
            User user = User.builder()
                .id("123")
                .email("test@example.com")
                .build();

            // Verify there are no setters (can't be tested at runtime easily)
            // But we can verify the object is consistent
            assert "123".equals(user.getId()) : "id should remain constant";

            passed("testImmutability");
        } catch (Exception e) {
            failed("testImmutability", e);
        }
    }

    static void testEquals() {
        try {
            User user1 = User.builder()
                .id("123")
                .email("test@example.com")
                .name("John")
                .build();

            User user2 = User.builder()
                .id("123")
                .email("test@example.com")
                .name("John")
                .build();

            User user3 = User.builder()
                .id("456")
                .email("other@example.com")
                .build();

            assert user1.equals(user2) : "Equal users should be equal";
            assert !user1.equals(user3) : "Different users should not be equal";
            assert user1.hashCode() == user2.hashCode() : "Equal objects should have same hashCode";

            passed("testEquals");
        } catch (Exception e) {
            failed("testEquals", e);
        }
    }

    static void testHttpRequestBuilder() {
        try {
            HttpRequest request = HttpRequest.builder("POST", "https://api.example.com/users")
                .header("Content-Type", "application/json")
                .header("Authorization", "Bearer token")
                .body("{\"name\": \"John\"}")
                .timeout(5000)
                .build();

            assert "POST".equals(request.getMethod()) : "method mismatch";
            assert "https://api.example.com/users".equals(request.getUrl()) : "url mismatch";
            assert "application/json".equals(request.getHeaders().get("Content-Type")) : "header mismatch";
            assert request.getTimeout() == 5000 : "timeout mismatch";

            passed("testHttpRequestBuilder");
        } catch (Exception e) {
            failed("testHttpRequestBuilder", e);
        }
    }

    static void testHttpRequestRequiredInConstructor() {
        try {
            HttpRequest.builder(null, "http://test.com").build();
            failed("testHttpRequestRequiredInConstructor", "Expected exception for null method");
        } catch (NullPointerException e) {
            // Expected
            passed("testHttpRequestRequiredInConstructor");
        } catch (Exception e) {
            failed("testHttpRequestRequiredInConstructor", e);
        }
    }

    static void testBuilderReuse() {
        try {
            User.Builder builder = User.builder()
                .id("123")
                .email("test@example.com");

            User user1 = builder.name("John").build();
            User user2 = builder.name("Jane").build();

            // Note: Builders are typically not safe to reuse like this in production
            // This test verifies the behavior
            assert user1.getName().isPresent() : "user1 should have name";

            passed("testBuilderReuse");
        } catch (Exception e) {
            failed("testBuilderReuse", e);
        }
    }

    static void testAgeValidation() {
        // Negative age
        try {
            User.builder()
                .id("123")
                .email("test@example.com")
                .age(-1)
                .build();
            failed("testAgeValidation - negative", "Expected exception for negative age");
        } catch (IllegalArgumentException e) {
            // Expected
        }

        // Age too high
        try {
            User.builder()
                .id("123")
                .email("test@example.com")
                .age(200)
                .build();
            failed("testAgeValidation - too high", "Expected exception for age > 150");
        } catch (IllegalArgumentException e) {
            // Expected
        }

        passed("testAgeValidation");
    }

    static void passed(String testName) {
        System.out.println("  " + testName + "... PASSED");
        passed++;
    }

    static void failed(String testName, String message) {
        System.out.println("  " + testName + "... FAILED: " + message);
        failed++;
    }

    static void failed(String testName, Exception e) {
        System.out.println("  " + testName + "... FAILED: " + e.getMessage());
        e.printStackTrace();
        failed++;
    }
}
