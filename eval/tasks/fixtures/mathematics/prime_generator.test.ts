import { generatePrimes } from './prime_generator';

describe('generatePrimes', () => {
  describe('basic functionality', () => {
    it('should generate primes up to 10', () => {
      const result = generatePrimes(10);
      expect(result).toEqual([2, 3, 5, 7]);
    });

    it('should generate primes up to 20', () => {
      const result = generatePrimes(20);
      expect(result).toEqual([2, 3, 5, 7, 11, 13, 17, 19]);
    });

    it('should generate primes up to 30', () => {
      const result = generatePrimes(30);
      expect(result).toEqual([2, 3, 5, 7, 11, 13, 17, 19, 23, 29]);
    });

    it('should generate first 25 primes (up to 100)', () => {
      const result = generatePrimes(100);
      expect(result).toEqual([
        2, 3, 5, 7, 11, 13, 17, 19, 23, 29,
        31, 37, 41, 43, 47, 53, 59, 61, 67, 71,
        73, 79, 83, 89, 97
      ]);
      expect(result.length).toBe(25);
    });
  });

  describe('edge cases', () => {
    it('should return empty array for limit < 2', () => {
      expect(generatePrimes(0)).toEqual([]);
      expect(generatePrimes(1)).toEqual([]);
      expect(generatePrimes(-1)).toEqual([]);
      expect(generatePrimes(-10)).toEqual([]);
    });

    it('should return [2] for limit 2', () => {
      const result = generatePrimes(2);
      expect(result).toEqual([2]);
    });

    it('should return [2, 3] for limit 3', () => {
      const result = generatePrimes(3);
      expect(result).toEqual([2, 3]);
    });

    it('should return [2, 3, 5] for limit 5', () => {
      const result = generatePrimes(5);
      expect(result).toEqual([2, 3, 5]);
    });

    it('should include limit if it is prime', () => {
      expect(generatePrimes(7)).toEqual([2, 3, 5, 7]);
      expect(generatePrimes(11)).toEqual([2, 3, 5, 7, 11]);
      expect(generatePrimes(13)).toEqual([2, 3, 5, 7, 11, 13]);
    });

    it('should not include limit if it is not prime', () => {
      const result6 = generatePrimes(6);
      expect(result6).toEqual([2, 3, 5]);
      expect(result6).not.toContain(6);

      const result10 = generatePrimes(10);
      expect(result10).toEqual([2, 3, 5, 7]);
      expect(result10).not.toContain(10);
    });
  });

  describe('properties of prime numbers', () => {
    it('should include 2 as the only even prime', () => {
      const result = generatePrimes(50);
      const evenPrimes = result.filter(n => n % 2 === 0);
      expect(evenPrimes).toEqual([2]);
    });

    it('should not include any composite numbers', () => {
      const result = generatePrimes(30);
      const composites = [4, 6, 8, 9, 10, 12, 14, 15, 16, 18, 20, 21, 22, 24, 25, 26, 27, 28, 30];

      composites.forEach(composite => {
        expect(result).not.toContain(composite);
      });
    });

    it('should return primes in ascending order', () => {
      const result = generatePrimes(100);

      for (let i = 1; i < result.length; i++) {
        expect(result[i]).toBeGreaterThan(result[i - 1]);
      }
    });

    it('should only contain numbers divisible only by 1 and themselves', () => {
      const result = generatePrimes(50);

      result.forEach(prime => {
        let divisorCount = 0;
        for (let i = 1; i <= prime; i++) {
          if (prime % i === 0) {
            divisorCount++;
          }
        }
        expect(divisorCount).toBe(2); // Only 1 and the number itself
      });
    });
  });

  describe('larger limits', () => {
    it('should handle limit 1000', () => {
      const result = generatePrimes(1000);

      expect(result[0]).toBe(2);
      expect(result[result.length - 1]).toBe(997);
      expect(result.length).toBe(168); // There are 168 primes up to 1000
    });

    it('should handle limit 10000', () => {
      const result = generatePrimes(10000);

      expect(result[0]).toBe(2);
      expect(result[result.length - 1]).toBe(9973);
      expect(result.length).toBe(1229); // There are 1229 primes up to 10000
    });
  });

  describe('specific prime verification', () => {
    it('should include known primes', () => {
      const result = generatePrimes(200);
      const knownPrimes = [2, 3, 5, 7, 11, 13, 17, 19, 23, 29, 31, 37, 41, 43, 47, 53, 59, 61, 67, 71, 73, 79, 83, 89, 97, 101, 103, 107, 109, 113, 127, 131, 137, 139, 149, 151, 157, 163, 167, 173, 179, 181, 191, 193, 197, 199];

      knownPrimes.forEach(prime => {
        expect(result).toContain(prime);
      });
    });

    it('should not include known composites', () => {
      const result = generatePrimes(200);
      const knownComposites = [4, 6, 8, 9, 10, 12, 14, 15, 16, 18, 20, 21, 22, 24, 25, 26, 27, 28, 30, 100, 121, 144, 169, 196];

      knownComposites.forEach(composite => {
        expect(result).not.toContain(composite);
      });
    });
  });

  describe('performance characteristics', () => {
    it('should complete for large inputs in reasonable time', () => {
      const start = Date.now();
      const result = generatePrimes(100000);
      const duration = Date.now() - start;

      // Should complete in under 1 second for 100k
      expect(duration).toBeLessThan(1000);
      expect(result.length).toBe(9592); // There are 9592 primes up to 100000
    });
  });
});
