/**
 * Simple Dependency Injection Container
 * Supports singleton/prototype scopes and constructor injection.
 */

import java.lang.annotation.*;
import java.lang.reflect.*;
import java.util.*;
import java.util.concurrent.ConcurrentHashMap;

// Singleton annotation
@Retention(RetentionPolicy.RUNTIME)
@Target(ElementType.TYPE)
@interface Singleton {}

// Inject annotation (optional, for documentation)
@Retention(RetentionPolicy.RUNTIME)
@Target({ElementType.CONSTRUCTOR, ElementType.FIELD})
@interface Inject {}

// Circular dependency exception
class CircularDependencyException extends RuntimeException {
    public CircularDependencyException(String message) {
        super(message);
    }
}

// Bean not found exception
class BeanNotFoundException extends RuntimeException {
    public BeanNotFoundException(String message) {
        super(message);
    }
}

// Main container
public class Container {
    private final Map<Class<?>, Class<?>> bindings = new ConcurrentHashMap<>();
    private final Map<Class<?>, Object> singletons = new ConcurrentHashMap<>();
    private final Map<Class<?>, Object> instances = new ConcurrentHashMap<>();

    // Register a concrete class
    public <T> void register(Class<T> type) {
        bindings.put(type, type);
    }

    // Register interface to implementation binding
    public <T> void register(Class<T> iface, Class<? extends T> impl) {
        bindings.put(iface, impl);
    }

    // Register a specific instance
    public <T> void registerInstance(Class<T> type, T instance) {
        instances.put(type, instance);
    }

    // Resolve a type
    public <T> T resolve(Class<T> type) {
        return resolveInternal(type, new HashSet<>());
    }

    @SuppressWarnings("unchecked")
    private <T> T resolveInternal(Class<T> type, Set<Class<?>> resolving) {
        // Check for pre-registered instances
        if (instances.containsKey(type)) {
            return (T) instances.get(type);
        }

        // Check for cached singletons
        if (singletons.containsKey(type)) {
            return (T) singletons.get(type);
        }

        // Get implementation class
        Class<?> implClass = bindings.getOrDefault(type, type);

        // Check for circular dependencies
        if (resolving.contains(implClass)) {
            throw new CircularDependencyException(
                "Circular dependency detected: " + buildDependencyChain(resolving, implClass)
            );
        }

        // Verify we can instantiate
        if (implClass.isInterface() || Modifier.isAbstract(implClass.getModifiers())) {
            throw new BeanNotFoundException(
                "Cannot instantiate interface/abstract class without binding: " + type.getName()
            );
        }

        resolving.add(implClass);

        try {
            T instance = (T) createInstance(implClass, resolving);

            // Cache if singleton
            if (implClass.isAnnotationPresent(Singleton.class)) {
                singletons.put(type, instance);
                if (type != implClass) {
                    singletons.put(implClass, instance);
                }
            }

            return instance;

        } finally {
            resolving.remove(implClass);
        }
    }

    private Object createInstance(Class<?> clazz, Set<Class<?>> resolving) {
        Constructor<?> constructor = findConstructor(clazz);
        Object[] params = resolveParameters(constructor, resolving);

        try {
            constructor.setAccessible(true);
            return constructor.newInstance(params);
        } catch (InstantiationException | IllegalAccessException | InvocationTargetException e) {
            throw new RuntimeException("Failed to create instance of " + clazz.getName(), e);
        }
    }

    private Constructor<?> findConstructor(Class<?> clazz) {
        Constructor<?>[] constructors = clazz.getDeclaredConstructors();

        // Look for @Inject annotated constructor
        for (Constructor<?> ctor : constructors) {
            if (ctor.isAnnotationPresent(Inject.class)) {
                return ctor;
            }
        }

        // Prefer public constructor with most parameters (greedy)
        Constructor<?> best = null;
        int maxParams = -1;

        for (Constructor<?> ctor : constructors) {
            if (Modifier.isPublic(ctor.getModifiers())) {
                if (ctor.getParameterCount() > maxParams) {
                    best = ctor;
                    maxParams = ctor.getParameterCount();
                }
            }
        }

        if (best != null) {
            return best;
        }

        // Fall back to default constructor
        try {
            return clazz.getDeclaredConstructor();
        } catch (NoSuchMethodException e) {
            throw new RuntimeException("No suitable constructor found for " + clazz.getName());
        }
    }

    private Object[] resolveParameters(Constructor<?> ctor, Set<Class<?>> resolving) {
        Class<?>[] paramTypes = ctor.getParameterTypes();
        Object[] params = new Object[paramTypes.length];

        for (int i = 0; i < paramTypes.length; i++) {
            params[i] = resolveInternal(paramTypes[i], resolving);
        }

        return params;
    }

    private String buildDependencyChain(Set<Class<?>> chain, Class<?> cycle) {
        StringBuilder sb = new StringBuilder();
        for (Class<?> c : chain) {
            sb.append(c.getSimpleName()).append(" -> ");
        }
        sb.append(cycle.getSimpleName());
        return sb.toString();
    }

    // Check if a type is registered
    public boolean isRegistered(Class<?> type) {
        return bindings.containsKey(type) || instances.containsKey(type);
    }

    // Clear all registrations
    public void clear() {
        bindings.clear();
        singletons.clear();
        instances.clear();
    }
}

// Builder for fluent registration
class ContainerBuilder {
    private final Container container = new Container();

    public <T> ContainerBuilder register(Class<T> type) {
        container.register(type);
        return this;
    }

    public <T> ContainerBuilder register(Class<T> iface, Class<? extends T> impl) {
        container.register(iface, impl);
        return this;
    }

    public <T> ContainerBuilder registerInstance(Class<T> type, T instance) {
        container.registerInstance(type, instance);
        return this;
    }

    public Container build() {
        return container;
    }
}
