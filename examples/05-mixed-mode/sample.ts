// Sample TypeScript file for mixed-mode constraint extraction

import { Request, Response } from 'express';
import { Database } from './database';

interface StandardResponse<T> {
    success: boolean;
    data?: T;
    error?: string;
    meta: {
        timestamp: string;
        requestId: string;
    };
}

interface Payment {
    id: string;
    amount: number;
    currency: string;
    status: 'pending' | 'completed' | 'failed';
}

export class PaymentHandler {
    private db: Database;

    constructor(db: Database) {
        this.db = db;
    }

    /**
     * Process a payment
     * This will be analyzed by mixed-mode constraints
     */
    async processPayment(req: Request, res: Response): Promise<void> {
        try {
            // Extract payment details
            const { amount, currency } = req.body;

            // Validate amount (custom constraint: payment_amount_validation)
            if (amount <= 0) {
                res.status(400).json({
                    success: false,
                    error: 'Amount must be positive',
                    meta: {
                        timestamp: new Date().toISOString(),
                        requestId: req.id
                    }
                });
                return;
            }

            // Check decimal places
            const decimals = (amount.toString().split('.')[1] || '').length;
            if (decimals > 2) {
                res.status(400).json({
                    success: false,
                    error: 'Amount cannot have more than 2 decimal places',
                    meta: {
                        timestamp: new Date().toISOString(),
                        requestId: req.id
                    }
                });
                return;
            }

            // Process payment with retry logic (custom constraint: require_retry_logic)
            const payment = await this.processWithRetry(async () => {
                return this.db.transaction(async (trx) => {
                    const paymentId = await trx('payments').insert({
                        amount,
                        currency,
                        status: 'pending',
                        created_at: new Date()
                    });

                    // Process payment...
                    return { id: paymentId, amount, currency, status: 'completed' as const };
                });
            });

            // Return standard response (custom constraint: standard_response_format)
            const response: StandardResponse<Payment> = {
                success: true,
                data: payment,
                meta: {
                    timestamp: new Date().toISOString(),
                    requestId: req.id
                }
            };

            res.json(response);

        } catch (error) {
            // Error logging format (JSON constraint: error_logging_format)
            console.error('Payment processing failed', {
                message: error.message,
                timestamp: new Date().toISOString(),
                requestId: req.id
                // Note: Not logging sensitive data
            });

            res.status(500).json({
                success: false,
                error: 'Payment processing failed',
                meta: {
                    timestamp: new Date().toISOString(),
                    requestId: req.id
                }
            });
        }
    }

    /**
     * Helper: Retry logic for database operations
     * Implements custom-001: require_transaction_retry
     */
    private async processWithRetry<T>(
        operation: () => Promise<T>,
        maxAttempts: number = 3
    ): Promise<T> {
        for (let attempt = 1; attempt <= maxAttempts; attempt++) {
            try {
                return await operation();
            } catch (error) {
                if (this.isDeadlock(error) && attempt < maxAttempts) {
                    const delay = Math.pow(2, attempt) * 100;
                    await this.sleep(delay);
                    continue;
                }
                throw error;
            }
        }
        throw new Error('Max retry attempts exceeded');
    }

    private isDeadlock(error: any): boolean {
        return error.code === 'DEADLOCK' || error.code === '40P01';
    }

    private sleep(ms: number): Promise<void> {
        return new Promise(resolve => setTimeout(resolve, ms));
    }
}
