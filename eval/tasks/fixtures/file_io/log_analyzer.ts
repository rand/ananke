interface LogStats {
  errorCount: number;
  warningCount: number;
  infoCount: number;
  topErrors: Array<{ message: string; count: number }>;
}

function analyzeLog(logContent: string): LogStats {
  const stats: LogStats = {
    errorCount: 0,
    warningCount: 0,
    infoCount: 0,
    topErrors: []
  };

  if (!logContent || logContent.trim().length === 0) {
    return stats;
  }

  const errorCounts = new Map<string, number>();
  const lines = logContent.split('\n');

  for (const line of lines) {
    if (!line.trim()) {
      continue; // Skip empty lines
    }

    // Parse log line format: [LEVEL] timestamp - message
    const match = line.match(/^\[([A-Z]+)\]\s+.+?\s+-\s+(.+)$/);

    if (!match) {
      continue; // Ignore malformed lines
    }

    const level = match[1];
    const message = match[2];

    // Count by level
    switch (level) {
      case 'ERROR':
        stats.errorCount++;
        // Track error message frequency
        const currentCount = errorCounts.get(message) || 0;
        errorCounts.set(message, currentCount + 1);
        break;
      case 'WARNING':
      case 'WARN':
        stats.warningCount++;
        break;
      case 'INFO':
        stats.infoCount++;
        break;
    }
  }

  // Convert error counts to sorted array and take top 5
  stats.topErrors = Array.from(errorCounts.entries())
    .map(([message, count]) => ({ message, count }))
    .sort((a, b) => b.count - a.count) // Sort descending by count
    .slice(0, 5); // Limit to top 5

  return stats;
}

export { analyzeLog, LogStats };
