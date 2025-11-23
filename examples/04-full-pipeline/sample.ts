// Sample TypeScript file demonstrating API endpoint patterns
// Used as input for full pipeline constraint extraction

/**
 * Payment processing API handler
 * Demonstrates patterns for secure payment endpoints
 */
export class PaymentHandler {
    private readonly maxRetries: number = 3;
    private readonly timeoutMs: number = 30000;

    /**
     * Process a payment transaction
     * @param amount - Payment amount in cents
     * @param currency - ISO 4217 currency code
     * @param customerId - Customer identifier
     * @returns Transaction result with ID and status
     */
    async processPayment(
        amount: number,
        currency: string,
        customerId: string
    ): Promise<PaymentResult> {
        // Input validation constraint
        if (amount <= 0) {
            throw new Error("Amount must be positive");
        }

        if (!this.isValidCurrency(currency)) {
            throw new Error(`Invalid currency: ${currency}`);
        }

        // Rate limiting constraint (should be enforced)
        await this.checkRateLimit(customerId);

        // Retry logic constraint
        let lastError: Error | null = null;
        for (let attempt = 0; attempt < this.maxRetries; attempt++) {
            try {
                const result = await this.executePayment(amount, currency, customerId);
                return result;
            } catch (error) {
                lastError = error as Error;
                await this.delay(Math.pow(2, attempt) * 1000);
            }
        }

        throw new Error(`Payment failed after ${this.maxRetries} attempts: ${lastError?.message}`);
    }

    /**
     * Refund a payment
     * @param transactionId - Original transaction ID
     * @param amount - Refund amount in cents (partial refunds allowed)
     * @returns Refund result
     */
    async refundPayment(transactionId: string, amount?: number): Promise<RefundResult> {
        // Authorization constraint: Must verify transaction exists
        const transaction = await this.getTransaction(transactionId);

        if (!transaction) {
            throw new Error(`Transaction not found: ${transactionId}`);
        }

        // Business logic constraint: Can't refund more than original amount
        const refundAmount = amount ?? transaction.amount;
        if (refundAmount > transaction.amount) {
            throw new Error("Refund amount exceeds transaction amount");
        }

        // Idempotency constraint: Check for duplicate refund
        const existingRefund = await this.findRefund(transactionId);
        if (existingRefund) {
            return existingRefund;
        }

        return await this.executeRefund(transactionId, refundAmount);
    }

    private async checkRateLimit(customerId: string): Promise<void> {
        // Rate limiting pattern to be extracted
        const recentRequests = await this.getRecentRequests(customerId, 60000);
        const maxRequestsPerMinute = 10;

        if (recentRequests >= maxRequestsPerMinute) {
            throw new Error("Rate limit exceeded");
        }
    }

    private isValidCurrency(currency: string): boolean {
        // Type constraint: Currency must be 3-letter code
        return /^[A-Z]{3}$/.test(currency);
    }

    private async executePayment(
        amount: number,
        currency: string,
        customerId: string
    ): Promise<PaymentResult> {
        // Placeholder for actual payment processing
        return {
            transactionId: `txn_${Date.now()}`,
            status: "success",
            amount,
            currency,
            customerId,
            timestamp: new Date().toISOString(),
        };
    }

    private async getTransaction(transactionId: string): Promise<Transaction | null> {
        // Placeholder for database lookup
        return null;
    }

    private async findRefund(transactionId: string): Promise<RefundResult | null> {
        // Placeholder for idempotency check
        return null;
    }

    private async executeRefund(transactionId: string, amount: number): Promise<RefundResult> {
        // Placeholder for actual refund processing
        return {
            refundId: `ref_${Date.now()}`,
            transactionId,
            amount,
            status: "completed",
            timestamp: new Date().toISOString(),
        };
    }

    private async getRecentRequests(customerId: string, windowMs: number): Promise<number> {
        // Placeholder for rate limit tracking
        return 0;
    }

    private delay(ms: number): Promise<void> {
        return new Promise(resolve => setTimeout(resolve, ms));
    }
}

interface PaymentResult {
    transactionId: string;
    status: "success" | "failed" | "pending";
    amount: number;
    currency: string;
    customerId: string;
    timestamp: string;
}

interface RefundResult {
    refundId: string;
    transactionId: string;
    amount: number;
    status: "completed" | "pending" | "failed";
    timestamp: string;
}

interface Transaction {
    transactionId: string;
    amount: number;
    currency: string;
    customerId: string;
    timestamp: string;
}

// Additional constraint patterns
export const PaymentConfig = {
    minAmount: 100, // $1.00 minimum
    maxAmount: 100000000, // $1M maximum
    supportedCurrencies: ["USD", "EUR", "GBP"],
    defaultTimeout: 30000,
} as const;
