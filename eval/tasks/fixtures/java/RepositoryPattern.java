/**
 * Generic Repository with Specification Pattern
 * Supports CRUD operations and composable query predicates.
 */

import java.util.*;
import java.util.function.Function;
import java.util.stream.Collectors;

// Entity marker interface
interface Entity<ID> {
    ID getId();
}

// Specification interface with composition support
interface Specification<T> {
    boolean isSatisfiedBy(T entity);

    default Specification<T> and(Specification<T> other) {
        return entity -> this.isSatisfiedBy(entity) && other.isSatisfiedBy(entity);
    }

    default Specification<T> or(Specification<T> other) {
        return entity -> this.isSatisfiedBy(entity) || other.isSatisfiedBy(entity);
    }

    default Specification<T> not() {
        return entity -> !this.isSatisfiedBy(entity);
    }

    static <T> Specification<T> all() {
        return entity -> true;
    }

    static <T> Specification<T> none() {
        return entity -> false;
    }
}

// Repository interface
interface Repository<T extends Entity<ID>, ID> {
    Optional<T> findById(ID id);
    List<T> findAll();
    List<T> findAll(Specification<T> spec);
    T save(T entity);
    void delete(T entity);
    void deleteById(ID id);
    boolean existsById(ID id);
    long count();
    long count(Specification<T> spec);
}

// In-memory implementation
class InMemoryRepository<T extends Entity<ID>, ID> implements Repository<T, ID> {
    private final Map<ID, T> storage = new HashMap<>();

    @Override
    public Optional<T> findById(ID id) {
        return Optional.ofNullable(storage.get(id));
    }

    @Override
    public List<T> findAll() {
        return new ArrayList<>(storage.values());
    }

    @Override
    public List<T> findAll(Specification<T> spec) {
        return storage.values().stream()
            .filter(spec::isSatisfiedBy)
            .collect(Collectors.toList());
    }

    @Override
    public T save(T entity) {
        storage.put(entity.getId(), entity);
        return entity;
    }

    @Override
    public void delete(T entity) {
        storage.remove(entity.getId());
    }

    @Override
    public void deleteById(ID id) {
        storage.remove(id);
    }

    @Override
    public boolean existsById(ID id) {
        return storage.containsKey(id);
    }

    @Override
    public long count() {
        return storage.size();
    }

    @Override
    public long count(Specification<T> spec) {
        return storage.values().stream()
            .filter(spec::isSatisfiedBy)
            .count();
    }
}

// Sample entity
class Product implements Entity<String> {
    private final String id;
    private final String name;
    private final String category;
    private final double price;
    private final boolean inStock;

    public Product(String id, String name, String category, double price, boolean inStock) {
        this.id = id;
        this.name = name;
        this.category = category;
        this.price = price;
        this.inStock = inStock;
    }

    @Override
    public String getId() { return id; }
    public String getName() { return name; }
    public String getCategory() { return category; }
    public double getPrice() { return price; }
    public boolean isInStock() { return inStock; }

    @Override
    public String toString() {
        return "Product{id='" + id + "', name='" + name + "', category='" + category +
               "', price=" + price + ", inStock=" + inStock + "}";
    }
}

// Specification implementations for Product
class ProductSpecifications {
    public static Specification<Product> hasCategory(String category) {
        return product -> product.getCategory().equals(category);
    }

    public static Specification<Product> priceLessThan(double maxPrice) {
        return product -> product.getPrice() < maxPrice;
    }

    public static Specification<Product> priceGreaterThan(double minPrice) {
        return product -> product.getPrice() > minPrice;
    }

    public static Specification<Product> priceBetween(double min, double max) {
        return priceGreaterThan(min).and(priceLessThan(max));
    }

    public static Specification<Product> isInStock() {
        return Product::isInStock;
    }

    public static Specification<Product> isOutOfStock() {
        return isInStock().not();
    }

    public static Specification<Product> nameContains(String substring) {
        return product -> product.getName().toLowerCase().contains(substring.toLowerCase());
    }
}

// Extended repository with pagination support
interface PaginatedRepository<T extends Entity<ID>, ID> extends Repository<T, ID> {
    Page<T> findAll(Specification<T> spec, Pageable pageable);
}

class Page<T> {
    private final List<T> content;
    private final int pageNumber;
    private final int pageSize;
    private final long totalElements;

    public Page(List<T> content, int pageNumber, int pageSize, long totalElements) {
        this.content = content;
        this.pageNumber = pageNumber;
        this.pageSize = pageSize;
        this.totalElements = totalElements;
    }

    public List<T> getContent() { return content; }
    public int getPageNumber() { return pageNumber; }
    public int getPageSize() { return pageSize; }
    public long getTotalElements() { return totalElements; }
    public int getTotalPages() {
        return (int) Math.ceil((double) totalElements / pageSize);
    }
    public boolean hasNext() { return pageNumber < getTotalPages() - 1; }
    public boolean hasPrevious() { return pageNumber > 0; }
}

class Pageable {
    private final int pageNumber;
    private final int pageSize;
    private final String sortBy;
    private final boolean ascending;

    public Pageable(int pageNumber, int pageSize) {
        this(pageNumber, pageSize, null, true);
    }

    public Pageable(int pageNumber, int pageSize, String sortBy, boolean ascending) {
        this.pageNumber = pageNumber;
        this.pageSize = pageSize;
        this.sortBy = sortBy;
        this.ascending = ascending;
    }

    public int getPageNumber() { return pageNumber; }
    public int getPageSize() { return pageSize; }
    public String getSortBy() { return sortBy; }
    public boolean isAscending() { return ascending; }
    public int getOffset() { return pageNumber * pageSize; }
}

// Paginated in-memory implementation
class PaginatedInMemoryRepository<T extends Entity<ID>, ID>
        extends InMemoryRepository<T, ID>
        implements PaginatedRepository<T, ID> {

    @Override
    public Page<T> findAll(Specification<T> spec, Pageable pageable) {
        List<T> filtered = findAll(spec);
        long totalElements = filtered.size();

        int start = Math.min(pageable.getOffset(), filtered.size());
        int end = Math.min(start + pageable.getPageSize(), filtered.size());

        List<T> pageContent = filtered.subList(start, end);

        return new Page<>(pageContent, pageable.getPageNumber(),
                         pageable.getPageSize(), totalElements);
    }
}
