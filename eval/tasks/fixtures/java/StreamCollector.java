/**
 * Custom Stream Collector Implementation
 * Sliding window aggregation with grouping support.
 */

import java.util.*;
import java.util.function.*;
import java.util.stream.Collector;

public class SlidingWindowCollector<T, K, R> implements
        Collector<T, Map<K, List<T>>, Map<K, List<R>>> {

    private final Function<T, K> keyExtractor;
    private final int windowSize;
    private final Function<List<T>, R> aggregator;

    public SlidingWindowCollector(
            Function<T, K> keyExtractor,
            int windowSize,
            Function<List<T>, R> aggregator) {

        if (windowSize <= 0) {
            throw new IllegalArgumentException("Window size must be positive");
        }

        this.keyExtractor = Objects.requireNonNull(keyExtractor);
        this.windowSize = windowSize;
        this.aggregator = Objects.requireNonNull(aggregator);
    }

    public static <T, K, R> SlidingWindowCollector<T, K, R> of(
            Function<T, K> keyExtractor,
            int windowSize,
            Function<List<T>, R> aggregator) {
        return new SlidingWindowCollector<>(keyExtractor, windowSize, aggregator);
    }

    @Override
    public Supplier<Map<K, List<T>>> supplier() {
        return HashMap::new;
    }

    @Override
    public BiConsumer<Map<K, List<T>>, T> accumulator() {
        return (map, element) -> {
            K key = keyExtractor.apply(element);
            map.computeIfAbsent(key, k -> new ArrayList<>()).add(element);
        };
    }

    @Override
    public BinaryOperator<Map<K, List<T>>> combiner() {
        return (left, right) -> {
            right.forEach((key, list) ->
                left.merge(key, list, (l1, l2) -> {
                    l1.addAll(l2);
                    return l1;
                })
            );
            return left;
        };
    }

    @Override
    public Function<Map<K, List<T>>, Map<K, List<R>>> finisher() {
        return accumulated -> {
            Map<K, List<R>> result = new HashMap<>();

            for (Map.Entry<K, List<T>> entry : accumulated.entrySet()) {
                K key = entry.getKey();
                List<T> items = entry.getValue();
                List<R> windows = applySlidingWindow(items);
                result.put(key, windows);
            }

            return Collections.unmodifiableMap(result);
        };
    }

    private List<R> applySlidingWindow(List<T> items) {
        if (items.size() < windowSize) {
            if (items.isEmpty()) {
                return Collections.emptyList();
            }
            // If fewer elements than window size, apply aggregator to all
            return Collections.singletonList(aggregator.apply(items));
        }

        List<R> results = new ArrayList<>();
        for (int i = 0; i <= items.size() - windowSize; i++) {
            List<T> window = items.subList(i, i + windowSize);
            results.add(aggregator.apply(window));
        }
        return results;
    }

    @Override
    public Set<Characteristics> characteristics() {
        return Collections.unmodifiableSet(EnumSet.of(Characteristics.UNORDERED));
    }
}

// Simple grouping collector without windowing
class GroupingCollector<T, K> implements Collector<T, Map<K, List<T>>, Map<K, List<T>>> {

    private final Function<T, K> keyExtractor;

    public GroupingCollector(Function<T, K> keyExtractor) {
        this.keyExtractor = Objects.requireNonNull(keyExtractor);
    }

    public static <T, K> GroupingCollector<T, K> groupBy(Function<T, K> keyExtractor) {
        return new GroupingCollector<>(keyExtractor);
    }

    @Override
    public Supplier<Map<K, List<T>>> supplier() {
        return HashMap::new;
    }

    @Override
    public BiConsumer<Map<K, List<T>>, T> accumulator() {
        return (map, element) -> {
            K key = keyExtractor.apply(element);
            map.computeIfAbsent(key, k -> new ArrayList<>()).add(element);
        };
    }

    @Override
    public BinaryOperator<Map<K, List<T>>> combiner() {
        return (left, right) -> {
            right.forEach((key, list) ->
                left.merge(key, list, (l1, l2) -> {
                    l1.addAll(l2);
                    return l1;
                })
            );
            return left;
        };
    }

    @Override
    public Function<Map<K, List<T>>, Map<K, List<T>>> finisher() {
        return Collections::unmodifiableMap;
    }

    @Override
    public Set<Characteristics> characteristics() {
        return Collections.unmodifiableSet(EnumSet.of(Characteristics.UNORDERED));
    }
}

// Statistics collector
class StatisticsCollector implements Collector<Number, StatisticsCollector.Stats, StatisticsCollector.Stats> {

    public static StatisticsCollector statistics() {
        return new StatisticsCollector();
    }

    @Override
    public Supplier<Stats> supplier() {
        return Stats::new;
    }

    @Override
    public BiConsumer<Stats, Number> accumulator() {
        return Stats::accept;
    }

    @Override
    public BinaryOperator<Stats> combiner() {
        return Stats::combine;
    }

    @Override
    public Function<Stats, Stats> finisher() {
        return Function.identity();
    }

    @Override
    public Set<Characteristics> characteristics() {
        return Collections.unmodifiableSet(
            EnumSet.of(Characteristics.IDENTITY_FINISH, Characteristics.UNORDERED)
        );
    }

    public static class Stats {
        private long count = 0;
        private double sum = 0;
        private double min = Double.MAX_VALUE;
        private double max = Double.MIN_VALUE;

        public void accept(Number value) {
            double d = value.doubleValue();
            count++;
            sum += d;
            min = Math.min(min, d);
            max = Math.max(max, d);
        }

        public Stats combine(Stats other) {
            count += other.count;
            sum += other.sum;
            min = Math.min(min, other.min);
            max = Math.max(max, other.max);
            return this;
        }

        public long getCount() { return count; }
        public double getSum() { return sum; }
        public double getMin() { return count > 0 ? min : 0; }
        public double getMax() { return count > 0 ? max : 0; }
        public double getAverage() { return count > 0 ? sum / count : 0; }

        @Override
        public String toString() {
            return String.format("Stats{count=%d, sum=%.2f, min=%.2f, max=%.2f, avg=%.2f}",
                count, sum, getMin(), getMax(), getAverage());
        }
    }
}

// Top N collector
class TopNCollector<T> implements Collector<T, PriorityQueue<T>, List<T>> {

    private final int n;
    private final Comparator<T> comparator;

    public TopNCollector(int n, Comparator<T> comparator) {
        if (n <= 0) {
            throw new IllegalArgumentException("n must be positive");
        }
        this.n = n;
        this.comparator = Objects.requireNonNull(comparator);
    }

    public static <T extends Comparable<T>> TopNCollector<T> topN(int n) {
        return new TopNCollector<>(n, Comparator.naturalOrder());
    }

    public static <T> TopNCollector<T> topN(int n, Comparator<T> comparator) {
        return new TopNCollector<>(n, comparator);
    }

    @Override
    public Supplier<PriorityQueue<T>> supplier() {
        // Min-heap to keep largest N elements
        return () -> new PriorityQueue<>(comparator);
    }

    @Override
    public BiConsumer<PriorityQueue<T>, T> accumulator() {
        return (heap, element) -> {
            if (heap.size() < n) {
                heap.offer(element);
            } else if (comparator.compare(element, heap.peek()) > 0) {
                heap.poll();
                heap.offer(element);
            }
        };
    }

    @Override
    public BinaryOperator<PriorityQueue<T>> combiner() {
        return (left, right) -> {
            for (T element : right) {
                if (left.size() < n) {
                    left.offer(element);
                } else if (comparator.compare(element, left.peek()) > 0) {
                    left.poll();
                    left.offer(element);
                }
            }
            return left;
        };
    }

    @Override
    public Function<PriorityQueue<T>, List<T>> finisher() {
        return heap -> {
            List<T> result = new ArrayList<>(heap);
            result.sort(comparator.reversed());
            return Collections.unmodifiableList(result);
        };
    }

    @Override
    public Set<Characteristics> characteristics() {
        return Collections.unmodifiableSet(EnumSet.of(Characteristics.UNORDERED));
    }
}
