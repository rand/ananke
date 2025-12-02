import { depthFirstSearch } from './graph_dfs';

describe('depthFirstSearch', () => {
  describe('basic functionality', () => {
    it('should traverse a simple linear graph', () => {
      const graph = new Map<number, number[]>();
      graph.set(1, [2]);
      graph.set(2, [3]);
      graph.set(3, []);

      const result = depthFirstSearch(graph, 1);
      expect(result).toEqual([1, 2, 3]);
    });

    it('should traverse a graph with multiple neighbors', () => {
      const graph = new Map<number, number[]>();
      graph.set(1, [2, 3]);
      graph.set(2, [4]);
      graph.set(3, [5]);
      graph.set(4, []);
      graph.set(5, []);

      const result = depthFirstSearch(graph, 1);
      expect(result).toContain(1);
      expect(result).toContain(2);
      expect(result).toContain(3);
      expect(result).toContain(4);
      expect(result).toContain(5);
      expect(result.length).toBe(5);
    });

    it('should traverse a tree structure', () => {
      const graph = new Map<number, number[]>();
      graph.set(1, [2, 3]);
      graph.set(2, [4, 5]);
      graph.set(3, [6, 7]);
      graph.set(4, []);
      graph.set(5, []);
      graph.set(6, []);
      graph.set(7, []);

      const result = depthFirstSearch(graph, 1);
      expect(result.length).toBe(7);
      expect(result[0]).toBe(1);
    });
  });

  describe('cycle handling', () => {
    it('should handle graph with cycles', () => {
      const graph = new Map<number, number[]>();
      graph.set(1, [2]);
      graph.set(2, [3]);
      graph.set(3, [1]); // Cycle back to 1

      const result = depthFirstSearch(graph, 1);
      expect(result).toEqual([1, 2, 3]);
    });

    it('should handle self-loop', () => {
      const graph = new Map<number, number[]>();
      graph.set(1, [1, 2]); // Self-loop
      graph.set(2, []);

      const result = depthFirstSearch(graph, 1);
      expect(result).toEqual([1, 2]);
    });
  });

  describe('disconnected graphs', () => {
    it('should only visit reachable nodes', () => {
      const graph = new Map<number, number[]>();
      graph.set(1, [2]);
      graph.set(2, []);
      graph.set(3, [4]); // Disconnected component
      graph.set(4, []);

      const result = depthFirstSearch(graph, 1);
      expect(result).toEqual([1, 2]);
      expect(result).not.toContain(3);
      expect(result).not.toContain(4);
    });

    it('should start from different connected component', () => {
      const graph = new Map<number, number[]>();
      graph.set(1, [2]);
      graph.set(2, []);
      graph.set(3, [4]);
      graph.set(4, []);

      const result = depthFirstSearch(graph, 3);
      expect(result).toEqual([3, 4]);
    });
  });

  describe('edge cases', () => {
    it('should return empty array for empty graph', () => {
      const graph = new Map<number, number[]>();
      const result = depthFirstSearch(graph, 1);
      expect(result).toEqual([]);
    });

    it('should return empty array for invalid start node', () => {
      const graph = new Map<number, number[]>();
      graph.set(1, [2]);
      graph.set(2, []);

      const result = depthFirstSearch(graph, 99);
      expect(result).toEqual([]);
    });

    it('should handle single node graph', () => {
      const graph = new Map<number, number[]>();
      graph.set(1, []);

      const result = depthFirstSearch(graph, 1);
      expect(result).toEqual([1]);
    });

    it('should handle node with no outgoing edges', () => {
      const graph = new Map<number, number[]>();
      graph.set(1, []);

      const result = depthFirstSearch(graph, 1);
      expect(result).toEqual([1]);
    });
  });

  describe('complex graphs', () => {
    it('should handle diamond pattern', () => {
      const graph = new Map<number, number[]>();
      graph.set(1, [2, 3]);
      graph.set(2, [4]);
      graph.set(3, [4]);
      graph.set(4, []);

      const result = depthFirstSearch(graph, 1);
      expect(result).toContain(1);
      expect(result).toContain(2);
      expect(result).toContain(3);
      expect(result).toContain(4);
      expect(result.length).toBe(4);
      expect(result[0]).toBe(1);
    });

    it('should handle larger graph', () => {
      const graph = new Map<number, number[]>();
      for (let i = 0; i < 10; i++) {
        graph.set(i, [i + 1, i + 2].filter(n => n < 10));
      }

      const result = depthFirstSearch(graph, 0);
      expect(result.length).toBe(10);
      expect(result[0]).toBe(0);
    });
  });

  describe('properties', () => {
    it('should not visit any node more than once', () => {
      const graph = new Map<number, number[]>();
      graph.set(1, [2, 3]);
      graph.set(2, [3, 4]);
      graph.set(3, [4]);
      graph.set(4, []);

      const result = depthFirstSearch(graph, 1);
      const uniqueNodes = new Set(result);
      expect(result.length).toBe(uniqueNodes.size);
    });

    it('should visit start node first', () => {
      const graph = new Map<number, number[]>();
      graph.set(5, [6, 7]);
      graph.set(6, []);
      graph.set(7, []);

      const result = depthFirstSearch(graph, 5);
      expect(result[0]).toBe(5);
    });
  });
});
