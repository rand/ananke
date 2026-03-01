/**
 * Repository Pattern Tests
 * Run with: javac RepositoryPattern.java RepositoryPatternTest.java && java RepositoryPatternTest
 */

import java.util.*;

public class RepositoryPatternTest {
    private static int passed = 0;
    private static int failed = 0;

    public static void main(String[] args) {
        System.out.println("Repository Pattern Tests:");

        testSaveAndFindById();
        testFindAll();
        testDelete();
        testExistsById();
        testCount();
        testSpecificationBasic();
        testSpecificationAnd();
        testSpecificationOr();
        testSpecificationNot();
        testSpecificationChaining();
        testProductSpecifications();
        testPagination();

        System.out.println("\n" + passed + " passed, " + failed + " failed");
        if (failed > 0) {
            System.exit(1);
        }
    }

    static Repository<Product, String> createRepository() {
        Repository<Product, String> repo = new InMemoryRepository<>();
        repo.save(new Product("1", "Laptop", "Electronics", 999.99, true));
        repo.save(new Product("2", "Mouse", "Electronics", 29.99, true));
        repo.save(new Product("3", "Desk", "Furniture", 299.99, false));
        repo.save(new Product("4", "Chair", "Furniture", 199.99, true));
        repo.save(new Product("5", "Keyboard", "Electronics", 79.99, false));
        return repo;
    }

    static void testSaveAndFindById() {
        try {
            Repository<Product, String> repo = new InMemoryRepository<>();
            Product product = new Product("1", "Test", "Category", 10.0, true);

            repo.save(product);
            Optional<Product> found = repo.findById("1");

            assert found.isPresent() : "Product should be found";
            assert "Test".equals(found.get().getName()) : "Name mismatch";

            // Not found
            Optional<Product> notFound = repo.findById("999");
            assert notFound.isEmpty() : "Should not find non-existent product";

            passed("testSaveAndFindById");
        } catch (Exception e) {
            failed("testSaveAndFindById", e);
        }
    }

    static void testFindAll() {
        try {
            Repository<Product, String> repo = createRepository();
            List<Product> all = repo.findAll();

            assert all.size() == 5 : "Should have 5 products";

            passed("testFindAll");
        } catch (Exception e) {
            failed("testFindAll", e);
        }
    }

    static void testDelete() {
        try {
            Repository<Product, String> repo = createRepository();
            Optional<Product> product = repo.findById("1");
            assert product.isPresent() : "Product should exist";

            repo.delete(product.get());
            assert repo.findById("1").isEmpty() : "Product should be deleted";

            // Delete by ID
            repo.deleteById("2");
            assert repo.findById("2").isEmpty() : "Product should be deleted by ID";

            passed("testDelete");
        } catch (Exception e) {
            failed("testDelete", e);
        }
    }

    static void testExistsById() {
        try {
            Repository<Product, String> repo = createRepository();

            assert repo.existsById("1") : "Product 1 should exist";
            assert !repo.existsById("999") : "Product 999 should not exist";

            passed("testExistsById");
        } catch (Exception e) {
            failed("testExistsById", e);
        }
    }

    static void testCount() {
        try {
            Repository<Product, String> repo = createRepository();

            assert repo.count() == 5 : "Should count 5 products";

            repo.deleteById("1");
            assert repo.count() == 4 : "Should count 4 products after delete";

            passed("testCount");
        } catch (Exception e) {
            failed("testCount", e);
        }
    }

    static void testSpecificationBasic() {
        try {
            Repository<Product, String> repo = createRepository();

            // Find electronics
            Specification<Product> isElectronics =
                product -> "Electronics".equals(product.getCategory());

            List<Product> electronics = repo.findAll(isElectronics);
            assert electronics.size() == 3 : "Should have 3 electronics";

            passed("testSpecificationBasic");
        } catch (Exception e) {
            failed("testSpecificationBasic", e);
        }
    }

    static void testSpecificationAnd() {
        try {
            Repository<Product, String> repo = createRepository();

            Specification<Product> isElectronics =
                product -> "Electronics".equals(product.getCategory());
            Specification<Product> isInStock =
                Product::isInStock;

            Specification<Product> electronicsInStock = isElectronics.and(isInStock);
            List<Product> result = repo.findAll(electronicsInStock);

            assert result.size() == 2 : "Should have 2 electronics in stock";

            passed("testSpecificationAnd");
        } catch (Exception e) {
            failed("testSpecificationAnd", e);
        }
    }

    static void testSpecificationOr() {
        try {
            Repository<Product, String> repo = createRepository();

            Specification<Product> isElectronics =
                product -> "Electronics".equals(product.getCategory());
            Specification<Product> isFurniture =
                product -> "Furniture".equals(product.getCategory());

            Specification<Product> either = isElectronics.or(isFurniture);
            List<Product> result = repo.findAll(either);

            assert result.size() == 5 : "Should have all 5 products";

            passed("testSpecificationOr");
        } catch (Exception e) {
            failed("testSpecificationOr", e);
        }
    }

    static void testSpecificationNot() {
        try {
            Repository<Product, String> repo = createRepository();

            Specification<Product> isElectronics =
                product -> "Electronics".equals(product.getCategory());

            Specification<Product> notElectronics = isElectronics.not();
            List<Product> result = repo.findAll(notElectronics);

            assert result.size() == 2 : "Should have 2 non-electronics";

            passed("testSpecificationNot");
        } catch (Exception e) {
            failed("testSpecificationNot", e);
        }
    }

    static void testSpecificationChaining() {
        try {
            Repository<Product, String> repo = createRepository();

            // Complex query: (Electronics OR Furniture) AND inStock AND price < 500
            Specification<Product> isElectronics =
                product -> "Electronics".equals(product.getCategory());
            Specification<Product> isFurniture =
                product -> "Furniture".equals(product.getCategory());
            Specification<Product> inStock = Product::isInStock;
            Specification<Product> cheaperThan500 = product -> product.getPrice() < 500;

            Specification<Product> complex = isElectronics
                .or(isFurniture)
                .and(inStock)
                .and(cheaperThan500);

            List<Product> result = repo.findAll(complex);
            // Mouse (29.99, Electronics, inStock)
            // Chair (199.99, Furniture, inStock)
            assert result.size() == 2 : "Should have 2 matching products, got " + result.size();

            passed("testSpecificationChaining");
        } catch (Exception e) {
            failed("testSpecificationChaining", e);
        }
    }

    static void testProductSpecifications() {
        try {
            Repository<Product, String> repo = createRepository();

            // Test hasCategory
            List<Product> electronics = repo.findAll(ProductSpecifications.hasCategory("Electronics"));
            assert electronics.size() == 3 : "Should have 3 electronics";

            // Test priceBetween
            List<Product> midRange = repo.findAll(ProductSpecifications.priceBetween(50.0, 500.0));
            // Desk: 299.99, Chair: 199.99, Keyboard: 79.99
            assert midRange.size() == 3 : "Should have 3 mid-range products";

            // Test isInStock
            List<Product> inStock = repo.findAll(ProductSpecifications.isInStock());
            assert inStock.size() == 3 : "Should have 3 in stock";

            // Test nameContains
            List<Product> withKeyword = repo.findAll(ProductSpecifications.nameContains("key"));
            assert withKeyword.size() == 1 : "Should find Keyboard";

            passed("testProductSpecifications");
        } catch (Exception e) {
            failed("testProductSpecifications", e);
        }
    }

    static void testPagination() {
        try {
            PaginatedInMemoryRepository<Product, String> repo = new PaginatedInMemoryRepository<>();
            for (int i = 0; i < 25; i++) {
                repo.save(new Product(String.valueOf(i), "Product " + i, "Category", 10.0, true));
            }

            // First page
            Page<Product> page1 = repo.findAll(Specification.all(), new Pageable(0, 10));
            assert page1.getContent().size() == 10 : "First page should have 10 items";
            assert page1.getTotalElements() == 25 : "Total should be 25";
            assert page1.getTotalPages() == 3 : "Should have 3 pages";
            assert page1.hasNext() : "Should have next page";
            assert !page1.hasPrevious() : "Should not have previous page";

            // Last page
            Page<Product> page3 = repo.findAll(Specification.all(), new Pageable(2, 10));
            assert page3.getContent().size() == 5 : "Last page should have 5 items";
            assert !page3.hasNext() : "Should not have next page";
            assert page3.hasPrevious() : "Should have previous page";

            passed("testPagination");
        } catch (Exception e) {
            failed("testPagination", e);
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
