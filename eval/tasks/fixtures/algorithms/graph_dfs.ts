function depthFirstSearch(graph: Map<number, number[]>, start: number): number[] {
  // Handle empty graph or invalid start node
  if (graph.size === 0 || !graph.has(start)) {
    return [];
  }

  const visited = new Set<number>();
  const result: number[] = [];
  const stack: number[] = [start];

  while (stack.length > 0) {
    const current = stack.pop()!;

    // Skip if already visited
    if (visited.has(current)) {
      continue;
    }

    // Mark as visited and add to result
    visited.add(current);
    result.push(current);

    // Get neighbors for current node
    const neighbors = graph.get(current) || [];

    // Push neighbors to stack in reverse order
    // (so they are popped in original order for consistent traversal)
    for (let i = neighbors.length - 1; i >= 0; i--) {
      const neighbor = neighbors[i];
      if (!visited.has(neighbor)) {
        stack.push(neighbor);
      }
    }
  }

  return result;
}

export { depthFirstSearch };
