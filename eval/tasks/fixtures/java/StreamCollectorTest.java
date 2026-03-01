/**
 * Stream Collector Tests
 * Run with: javac StreamCollector.java StreamCollectorTest.java && java StreamCollectorTest
 */

import java.util.*;
import java.util.stream.*;

public class StreamCollectorTest {
    private static int passed = 0;
    private static int failed = 0;

    public static void main(String[] args) {
        System.out.println("Stream Collector Tests:");

        testBasicSlidingWindow();
        testSlidingWindowWithGrouping();
        testEmptyStream();
        testWindowLargerThanData();
        testParallelStream();
        testGroupingCollector();
        testStatisticsCollector();
        testTopNCollector();
        testSlidingWindowAverages();

        System.out.println("\n" + passed + " passed, " + failed + " failed");
        if (failed > 0) {
            System.exit(1);
        }
    }

    static void testBasicSlidingWindow() {
        try {
            List<Integer> numbers = Arrays.asList(1, 2, 3, 4, 5);

            // Window of 3, sum aggregation, single group
            Map<String, List<Integer>> result = numbers.stream()
                .collect(SlidingWindowCollector.of(
                    n -> "all",
                    3,
                    window -> window.stream().mapToInt(Integer::intValue).sum()
                ));

            List<Integer> sums = result.get("all");
            // Windows: [1,2,3]=6, [2,3,4]=9, [3,4,5]=12
            assert sums.size() == 3 : "Should have 3 windows";
            assert sums.get(0) == 6 : "First window sum should be 6";
            assert sums.get(1) == 9 : "Second window sum should be 9";
            assert sums.get(2) == 12 : "Third window sum should be 12";

            passed("testBasicSlidingWindow");
        } catch (Exception e) {
            failed("testBasicSlidingWindow", e);
        }
    }

    static void testSlidingWindowWithGrouping() {
        try {
            record Sale(String category, int amount) {}

            List<Sale> sales = Arrays.asList(
                new Sale("A", 10), new Sale("A", 20), new Sale("A", 30),
                new Sale("B", 5), new Sale("B", 15)
            );

            Map<String, List<Integer>> result = sales.stream()
                .collect(SlidingWindowCollector.of(
                    Sale::category,
                    2,
                    window -> window.stream().mapToInt(Sale::amount).sum()
                ));

            // Category A: [10,20]=30, [20,30]=50
            List<Integer> categoryA = result.get("A");
            assert categoryA.size() == 2 : "Category A should have 2 windows";
            assert categoryA.get(0) == 30 : "First A window should be 30";
            assert categoryA.get(1) == 50 : "Second A window should be 50";

            // Category B: [5,15]=20
            List<Integer> categoryB = result.get("B");
            assert categoryB.size() == 1 : "Category B should have 1 window";
            assert categoryB.get(0) == 20 : "B window should be 20";

            passed("testSlidingWindowWithGrouping");
        } catch (Exception e) {
            failed("testSlidingWindowWithGrouping", e);
        }
    }

    static void testEmptyStream() {
        try {
            Map<String, List<Integer>> result = Stream.<Integer>empty()
                .collect(SlidingWindowCollector.of(
                    n -> "all",
                    3,
                    window -> window.stream().mapToInt(Integer::intValue).sum()
                ));

            assert result.isEmpty() : "Empty stream should produce empty result";

            passed("testEmptyStream");
        } catch (Exception e) {
            failed("testEmptyStream", e);
        }
    }

    static void testWindowLargerThanData() {
        try {
            List<Integer> numbers = Arrays.asList(1, 2);

            Map<String, List<Integer>> result = numbers.stream()
                .collect(SlidingWindowCollector.of(
                    n -> "all",
                    5, // Window larger than data
                    window -> window.stream().mapToInt(Integer::intValue).sum()
                ));

            List<Integer> sums = result.get("all");
            // Should aggregate all available elements
            assert sums.size() == 1 : "Should have 1 result for partial window";
            assert sums.get(0) == 3 : "Should sum all available elements";

            passed("testWindowLargerThanData");
        } catch (Exception e) {
            failed("testWindowLargerThanData", e);
        }
    }

    static void testParallelStream() {
        try {
            List<Integer> numbers = IntStream.range(0, 1000)
                .boxed()
                .collect(Collectors.toList());

            Map<String, List<Long>> result = numbers.parallelStream()
                .collect(SlidingWindowCollector.of(
                    n -> n % 2 == 0 ? "even" : "odd",
                    5,
                    window -> window.stream().mapToLong(Integer::longValue).sum()
                ));

            assert result.containsKey("even") : "Should have even group";
            assert result.containsKey("odd") : "Should have odd group";
            assert !result.get("even").isEmpty() : "Even group should have results";
            assert !result.get("odd").isEmpty() : "Odd group should have results";

            passed("testParallelStream");
        } catch (Exception e) {
            failed("testParallelStream", e);
        }
    }

    static void testGroupingCollector() {
        try {
            record Person(String dept, String name) {}

            List<Person> people = Arrays.asList(
                new Person("Engineering", "Alice"),
                new Person("Engineering", "Bob"),
                new Person("Sales", "Carol")
            );

            Map<String, List<Person>> byDept = people.stream()
                .collect(GroupingCollector.groupBy(Person::dept));

            assert byDept.get("Engineering").size() == 2 : "Engineering should have 2 people";
            assert byDept.get("Sales").size() == 1 : "Sales should have 1 person";

            passed("testGroupingCollector");
        } catch (Exception e) {
            failed("testGroupingCollector", e);
        }
    }

    static void testStatisticsCollector() {
        try {
            StatisticsCollector.Stats stats = Stream.of(1, 2, 3, 4, 5)
                .collect(StatisticsCollector.statistics());

            assert stats.getCount() == 5 : "Count should be 5";
            assert stats.getSum() == 15.0 : "Sum should be 15";
            assert stats.getMin() == 1.0 : "Min should be 1";
            assert stats.getMax() == 5.0 : "Max should be 5";
            assert stats.getAverage() == 3.0 : "Average should be 3";

            // Empty stream
            StatisticsCollector.Stats emptyStats = Stream.<Number>empty()
                .collect(StatisticsCollector.statistics());
            assert emptyStats.getCount() == 0 : "Empty count should be 0";
            assert emptyStats.getAverage() == 0 : "Empty average should be 0";

            passed("testStatisticsCollector");
        } catch (Exception e) {
            failed("testStatisticsCollector", e);
        }
    }

    static void testTopNCollector() {
        try {
            List<Integer> numbers = Arrays.asList(5, 2, 8, 1, 9, 3, 7, 4, 6);

            List<Integer> top3 = numbers.stream()
                .collect(TopNCollector.topN(3));

            assert top3.size() == 3 : "Should have 3 elements";
            assert top3.get(0) == 9 : "First should be 9";
            assert top3.get(1) == 8 : "Second should be 8";
            assert top3.get(2) == 7 : "Third should be 7";

            // Custom comparator (reverse - bottom N)
            List<Integer> bottom3 = numbers.stream()
                .collect(TopNCollector.topN(3, Comparator.<Integer>reverseOrder()));

            assert bottom3.get(0) == 1 : "First should be 1";
            assert bottom3.get(1) == 2 : "Second should be 2";
            assert bottom3.get(2) == 3 : "Third should be 3";

            passed("testTopNCollector");
        } catch (Exception e) {
            failed("testTopNCollector", e);
        }
    }

    static void testSlidingWindowAverages() {
        try {
            List<Double> prices = Arrays.asList(100.0, 102.0, 104.0, 103.0, 105.0);

            // Moving average with window of 3
            Map<String, List<Double>> result = prices.stream()
                .collect(SlidingWindowCollector.of(
                    p -> "price",
                    3,
                    window -> window.stream()
                        .mapToDouble(Double::doubleValue)
                        .average()
                        .orElse(0.0)
                ));

            List<Double> averages = result.get("price");
            // Windows: [100,102,104], [102,104,103], [104,103,105]
            // Averages: 102, 103, 104

            assert averages.size() == 3 : "Should have 3 moving averages";
            assert Math.abs(averages.get(0) - 102.0) < 0.01 : "First avg should be ~102";
            assert Math.abs(averages.get(1) - 103.0) < 0.01 : "Second avg should be ~103";
            assert Math.abs(averages.get(2) - 104.0) < 0.01 : "Third avg should be ~104";

            passed("testSlidingWindowAverages");
        } catch (Exception e) {
            failed("testSlidingWindowAverages", e);
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
