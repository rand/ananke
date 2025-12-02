import { analyzeLog } from './log_analyzer';

describe('analyzeLog', () => {
  describe('basic functionality', () => {
    it('should count log levels correctly', () => {
      const logContent = `
[ERROR] 2023-01-01 10:00:00 - Database connection failed
[WARNING] 2023-01-01 10:01:00 - Slow query detected
[INFO] 2023-01-01 10:02:00 - Server started
[ERROR] 2023-01-01 10:03:00 - Authentication failed
      `.trim();

      const result = analyzeLog(logContent);

      expect(result.errorCount).toBe(2);
      expect(result.warningCount).toBe(1);
      expect(result.infoCount).toBe(1);
    });

    it('should handle WARN as WARNING', () => {
      const logContent = `
[WARN] 2023-01-01 10:00:00 - Warning message
[WARNING] 2023-01-01 10:01:00 - Another warning
      `.trim();

      const result = analyzeLog(logContent);

      expect(result.warningCount).toBe(2);
    });
  });

  describe('top errors tracking', () => {
    it('should track most frequent error messages', () => {
      const logContent = `
[ERROR] 2023-01-01 10:00:00 - Database connection failed
[ERROR] 2023-01-01 10:01:00 - Database connection failed
[ERROR] 2023-01-01 10:02:00 - Authentication failed
[ERROR] 2023-01-01 10:03:00 - Database connection failed
      `.trim();

      const result = analyzeLog(logContent);

      expect(result.topErrors.length).toBe(2);
      expect(result.topErrors[0].message).toBe('Database connection failed');
      expect(result.topErrors[0].count).toBe(3);
      expect(result.topErrors[1].message).toBe('Authentication failed');
      expect(result.topErrors[1].count).toBe(1);
    });

    it('should limit to top 5 errors', () => {
      const logContent = `
[ERROR] 2023-01-01 10:00:00 - Error A
[ERROR] 2023-01-01 10:01:00 - Error B
[ERROR] 2023-01-01 10:02:00 - Error C
[ERROR] 2023-01-01 10:03:00 - Error D
[ERROR] 2023-01-01 10:04:00 - Error E
[ERROR] 2023-01-01 10:05:00 - Error F
      `.trim();

      const result = analyzeLog(logContent);

      expect(result.topErrors.length).toBe(5);
    });

    it('should sort top errors by count descending', () => {
      const logContent = `
[ERROR] 2023-01-01 10:00:00 - Error A
[ERROR] 2023-01-01 10:01:00 - Error B
[ERROR] 2023-01-01 10:02:00 - Error B
[ERROR] 2023-01-01 10:03:00 - Error C
[ERROR] 2023-01-01 10:04:00 - Error C
[ERROR] 2023-01-01 10:05:00 - Error C
      `.trim();

      const result = analyzeLog(logContent);

      expect(result.topErrors[0].message).toBe('Error C');
      expect(result.topErrors[0].count).toBe(3);
      expect(result.topErrors[1].message).toBe('Error B');
      expect(result.topErrors[1].count).toBe(2);
      expect(result.topErrors[2].message).toBe('Error A');
      expect(result.topErrors[2].count).toBe(1);
    });
  });

  describe('malformed line handling', () => {
    it('should ignore malformed log lines', () => {
      const logContent = `
[ERROR] 2023-01-01 10:00:00 - Valid error
This is not a valid log line
[WARNING] 2023-01-01 10:01:00 - Valid warning
Another invalid line
      `.trim();

      const result = analyzeLog(logContent);

      expect(result.errorCount).toBe(1);
      expect(result.warningCount).toBe(1);
    });

    it('should ignore empty lines', () => {
      const logContent = `
[ERROR] 2023-01-01 10:00:00 - Error message

[WARNING] 2023-01-01 10:01:00 - Warning message

      `.trim();

      const result = analyzeLog(logContent);

      expect(result.errorCount).toBe(1);
      expect(result.warningCount).toBe(1);
    });
  });

  describe('edge cases', () => {
    it('should handle empty log content', () => {
      const result = analyzeLog('');

      expect(result.errorCount).toBe(0);
      expect(result.warningCount).toBe(0);
      expect(result.infoCount).toBe(0);
      expect(result.topErrors).toEqual([]);
    });

    it('should handle whitespace-only content', () => {
      const result = analyzeLog('   \n  \n  ');

      expect(result.errorCount).toBe(0);
      expect(result.warningCount).toBe(0);
      expect(result.infoCount).toBe(0);
      expect(result.topErrors).toEqual([]);
    });

    it('should handle logs with only one level', () => {
      const logContent = `
[ERROR] 2023-01-01 10:00:00 - Error 1
[ERROR] 2023-01-01 10:01:00 - Error 2
[ERROR] 2023-01-01 10:02:00 - Error 3
      `.trim();

      const result = analyzeLog(logContent);

      expect(result.errorCount).toBe(3);
      expect(result.warningCount).toBe(0);
      expect(result.infoCount).toBe(0);
    });
  });

  describe('complex log content', () => {
    it('should handle large log files', () => {
      const lines: string[] = [];
      for (let i = 0; i < 1000; i++) {
        lines.push(`[ERROR] 2023-01-01 10:${i % 60}:${i % 60} - Error ${i % 10}`);
      }
      const logContent = lines.join('\n');

      const result = analyzeLog(logContent);

      expect(result.errorCount).toBe(1000);
      expect(result.topErrors.length).toBe(5);
    });

    it('should handle messages with special characters', () => {
      const logContent = `
[ERROR] 2023-01-01 10:00:00 - Error: "Invalid JSON" at line 42
[WARNING] 2023-01-01 10:01:00 - Warning: File path contains spaces: /path/to/my file.txt
[INFO] 2023-01-01 10:02:00 - User logged in: john@example.com
      `.trim();

      const result = analyzeLog(logContent);

      expect(result.errorCount).toBe(1);
      expect(result.warningCount).toBe(1);
      expect(result.infoCount).toBe(1);
    });

    it('should handle mixed levels', () => {
      const logContent = `
[INFO] 2023-01-01 10:00:00 - Server started
[INFO] 2023-01-01 10:01:00 - Config loaded
[WARNING] 2023-01-01 10:02:00 - High memory usage
[ERROR] 2023-01-01 10:03:00 - Failed to connect
[INFO] 2023-01-01 10:04:00 - Retry attempt 1
[ERROR] 2023-01-01 10:05:00 - Failed to connect
[INFO] 2023-01-01 10:06:00 - Retry attempt 2
[ERROR] 2023-01-01 10:07:00 - Failed to connect
[WARNING] 2023-01-01 10:08:00 - Giving up after 3 attempts
      `.trim();

      const result = analyzeLog(logContent);

      expect(result.infoCount).toBe(4);
      expect(result.warningCount).toBe(2);
      expect(result.errorCount).toBe(3);
      expect(result.topErrors[0].message).toBe('Failed to connect');
      expect(result.topErrors[0].count).toBe(3);
    });
  });
});
