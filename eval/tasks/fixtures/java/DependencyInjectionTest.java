/**
 * Dependency Injection Tests
 * Run with: javac DependencyInjection.java DependencyInjectionTest.java && java DependencyInjectionTest
 */

public class DependencyInjectionTest {
    private static int passed = 0;
    private static int failed = 0;

    public static void main(String[] args) {
        System.out.println("Dependency Injection Tests:");

        testSimpleResolve();
        testInterfaceBinding();
        testConstructorInjection();
        testSingletonScope();
        testPrototypeScope();
        testCircularDependency();
        testUnregisteredInterface();
        testRegisterInstance();
        testDeepDependencyChain();
        testContainerBuilder();

        System.out.println("\n" + passed + " passed, " + failed + " failed");
        if (failed > 0) {
            System.exit(1);
        }
    }

    // Test classes
    static class SimpleService {
        public String getMessage() { return "Hello"; }
    }

    interface MessageService {
        String getMessage();
    }

    static class EmailService implements MessageService {
        public String getMessage() { return "Email"; }
    }

    static class SmsService implements MessageService {
        public String getMessage() { return "SMS"; }
    }

    static class NotificationController {
        private final MessageService messageService;

        public NotificationController(MessageService messageService) {
            this.messageService = messageService;
        }

        public String notify() {
            return "Notification: " + messageService.getMessage();
        }
    }

    @Singleton
    static class ConfigService {
        private static int instanceCount = 0;
        private final int id;

        public ConfigService() {
            this.id = ++instanceCount;
        }

        public int getId() { return id; }

        public static void resetCount() { instanceCount = 0; }
    }

    static class PrototypeService {
        private static int instanceCount = 0;
        private final int id;

        public PrototypeService() {
            this.id = ++instanceCount;
        }

        public int getId() { return id; }

        public static void resetCount() { instanceCount = 0; }
    }

    // Circular dependency test classes
    static class ServiceA {
        public ServiceA(ServiceB b) {}
    }

    static class ServiceB {
        public ServiceB(ServiceA a) {}
    }

    // Deep chain
    static class Level1 {
        public Level1(Level2 l2) {}
    }

    static class Level2 {
        public Level2(Level3 l3) {}
    }

    static class Level3 {
        public Level3() {}
    }

    static void testSimpleResolve() {
        try {
            Container container = new Container();
            container.register(SimpleService.class);

            SimpleService service = container.resolve(SimpleService.class);
            assert service != null : "Service should not be null";
            assert "Hello".equals(service.getMessage()) : "Message mismatch";

            passed("testSimpleResolve");
        } catch (Exception e) {
            failed("testSimpleResolve", e);
        }
    }

    static void testInterfaceBinding() {
        try {
            Container container = new Container();
            container.register(MessageService.class, EmailService.class);

            MessageService service = container.resolve(MessageService.class);
            assert service instanceof EmailService : "Should be EmailService";
            assert "Email".equals(service.getMessage()) : "Message mismatch";

            passed("testInterfaceBinding");
        } catch (Exception e) {
            failed("testInterfaceBinding", e);
        }
    }

    static void testConstructorInjection() {
        try {
            Container container = new Container();
            container.register(MessageService.class, SmsService.class);
            container.register(NotificationController.class);

            NotificationController controller = container.resolve(NotificationController.class);
            assert controller != null : "Controller should not be null";
            assert "Notification: SMS".equals(controller.notify()) : "Notification mismatch";

            passed("testConstructorInjection");
        } catch (Exception e) {
            failed("testConstructorInjection", e);
        }
    }

    static void testSingletonScope() {
        try {
            ConfigService.resetCount();

            Container container = new Container();
            container.register(ConfigService.class);

            ConfigService s1 = container.resolve(ConfigService.class);
            ConfigService s2 = container.resolve(ConfigService.class);

            assert s1 == s2 : "Singletons should be same instance";
            assert s1.getId() == 1 : "Should only create once";

            passed("testSingletonScope");
        } catch (Exception e) {
            failed("testSingletonScope", e);
        }
    }

    static void testPrototypeScope() {
        try {
            PrototypeService.resetCount();

            Container container = new Container();
            container.register(PrototypeService.class);

            PrototypeService s1 = container.resolve(PrototypeService.class);
            PrototypeService s2 = container.resolve(PrototypeService.class);

            assert s1 != s2 : "Prototypes should be different instances";
            assert s1.getId() == 1 : "First should have id 1";
            assert s2.getId() == 2 : "Second should have id 2";

            passed("testPrototypeScope");
        } catch (Exception e) {
            failed("testPrototypeScope", e);
        }
    }

    static void testCircularDependency() {
        try {
            Container container = new Container();
            container.register(ServiceA.class);
            container.register(ServiceB.class);

            try {
                container.resolve(ServiceA.class);
                failed("testCircularDependency", "Expected CircularDependencyException");
            } catch (CircularDependencyException e) {
                // Expected
                assert e.getMessage().contains("Circular") : "Should mention circular";
                passed("testCircularDependency");
            }
        } catch (Exception e) {
            failed("testCircularDependency", e);
        }
    }

    static void testUnregisteredInterface() {
        try {
            Container container = new Container();

            try {
                container.resolve(MessageService.class);
                failed("testUnregisteredInterface", "Expected BeanNotFoundException");
            } catch (BeanNotFoundException e) {
                // Expected
                passed("testUnregisteredInterface");
            }
        } catch (Exception e) {
            failed("testUnregisteredInterface", e);
        }
    }

    static void testRegisterInstance() {
        try {
            Container container = new Container();
            EmailService instance = new EmailService();
            container.registerInstance(MessageService.class, instance);

            MessageService resolved = container.resolve(MessageService.class);
            assert resolved == instance : "Should return same instance";

            passed("testRegisterInstance");
        } catch (Exception e) {
            failed("testRegisterInstance", e);
        }
    }

    static void testDeepDependencyChain() {
        try {
            Container container = new Container();
            container.register(Level1.class);
            container.register(Level2.class);
            container.register(Level3.class);

            Level1 l1 = container.resolve(Level1.class);
            assert l1 != null : "Should resolve deep chain";

            passed("testDeepDependencyChain");
        } catch (Exception e) {
            failed("testDeepDependencyChain", e);
        }
    }

    static void testContainerBuilder() {
        try {
            Container container = new ContainerBuilder()
                .register(MessageService.class, EmailService.class)
                .register(NotificationController.class)
                .build();

            NotificationController controller = container.resolve(NotificationController.class);
            assert "Notification: Email".equals(controller.notify()) : "Should work with builder";

            passed("testContainerBuilder");
        } catch (Exception e) {
            failed("testContainerBuilder", e);
        }
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
