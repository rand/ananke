function generatePrimes(limit: number): number[] {
  // Handle edge case: limit < 2
  if (limit < 2) {
    return [];
  }

  // Create boolean array "isPrime[0..limit]" and initialize all entries as true
  const isPrime: boolean[] = new Array(limit + 1).fill(true);

  // 0 and 1 are not prime numbers
  isPrime[0] = false;
  isPrime[1] = false;

  // Sieve of Eratosthenes algorithm
  for (let p = 2; p * p <= limit; p++) {
    // If isPrime[p] is not changed, then it is a prime
    if (isPrime[p]) {
      // Mark all multiples of p as not prime
      // Start from p*p, as smaller multiples have already been marked
      for (let i = p * p; i <= limit; i += p) {
        isPrime[i] = false;
      }
    }
  }

  // Collect all numbers that are still marked as prime
  const primes: number[] = [];
  for (let i = 2; i <= limit; i++) {
    if (isPrime[i]) {
      primes.push(i);
    }
  }

  return primes;
}

export { generatePrimes };
