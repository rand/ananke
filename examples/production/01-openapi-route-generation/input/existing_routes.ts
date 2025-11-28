import { Router, Request, Response } from 'express';
import { z } from 'zod';

/**
 * Example Express routes showing the preferred patterns for this codebase.
 * These patterns will be extracted and applied to generated routes.
 */

const router = Router();

// Database mock (in real code, this would be a proper database connection)
const db = {
  products: {
    async findById(id: number) {
      // Simulated database query
      const products = [
        { id: 1, name: 'Laptop', price: 999.99, category: 'electronics', inStock: true },
        { id: 2, name: 'Desk Chair', price: 299.99, category: 'furniture', inStock: true },
        { id: 3, name: 'Coffee Mug', price: 12.99, category: 'kitchen', inStock: false },
      ];
      return products.find(p => p.id === id) || null;
    },
    async findAll(filters: { category?: string; inStock?: boolean }) {
      // Simulated database query with filtering
      let products = [
        { id: 1, name: 'Laptop', price: 999.99, category: 'electronics', inStock: true },
        { id: 2, name: 'Desk Chair', price: 299.99, category: 'furniture', inStock: true },
        { id: 3, name: 'Coffee Mug', price: 12.99, category: 'kitchen', inStock: false },
      ];

      if (filters.category) {
        products = products.filter(p => p.category === filters.category);
      }
      if (filters.inStock !== undefined) {
        products = products.filter(p => p.inStock === filters.inStock);
      }

      return products;
    },
  },
};

// Validation schemas using Zod
const getProductParamsSchema = z.object({
  id: z.number().int().positive(),
});

const listProductsQuerySchema = z.object({
  category: z.enum(['electronics', 'furniture', 'kitchen', 'clothing']).optional(),
  inStock: z.boolean().optional(),
  page: z.number().int().min(1).default(1),
  limit: z.number().int().min(1).max(100).default(20),
});

/**
 * GET /products/:id
 * Fetch a single product by ID
 *
 * Example pattern demonstrating:
 * - Path parameter validation
 * - Type-safe request handling
 * - Comprehensive error handling
 * - Proper HTTP status codes
 * - Consistent error response format
 */
router.get('/products/:id', async (req: Request, res: Response) => {
  try {
    // Parse and validate path parameters
    const params = getProductParamsSchema.parse({
      id: parseInt(req.params.id, 10),
    });

    // Database query
    const product = await db.products.findById(params.id);

    // Handle not found
    if (!product) {
      return res.status(404).json({
        error: 'Product not found',
        message: `No product exists with id ${params.id}`,
      });
    }

    // Success response
    return res.status(200).json(product);
  } catch (error) {
    // Handle validation errors
    if (error instanceof z.ZodError) {
      return res.status(400).json({
        error: 'Validation failed',
        message: 'Invalid request parameters',
        details: error.errors.map(e => ({
          field: e.path.join('.'),
          issue: e.message,
        })),
      });
    }

    // Handle unexpected errors
    console.error('Error fetching product:', error);
    return res.status(500).json({
      error: 'Internal server error',
      message: 'An unexpected error occurred while fetching the product',
    });
  }
});

/**
 * GET /products
 * List products with optional filtering and pagination
 *
 * Example pattern demonstrating:
 * - Query parameter validation
 * - Optional filters
 * - Pagination support
 * - Array response format
 * - Metadata in response
 */
router.get('/products', async (req: Request, res: Response) => {
  try {
    // Parse and validate query parameters
    const query = listProductsQuerySchema.parse({
      category: req.query.category,
      inStock: req.query.inStock === 'true' ? true : req.query.inStock === 'false' ? false : undefined,
      page: req.query.page ? parseInt(req.query.page as string, 10) : undefined,
      limit: req.query.limit ? parseInt(req.query.limit as string, 10) : undefined,
    });

    // Database query with filters
    const products = await db.products.findAll({
      category: query.category,
      inStock: query.inStock,
    });

    // Calculate pagination
    const startIndex = (query.page - 1) * query.limit;
    const endIndex = startIndex + query.limit;
    const paginatedProducts = products.slice(startIndex, endIndex);

    // Success response with pagination metadata
    return res.status(200).json({
      data: paginatedProducts,
      pagination: {
        page: query.page,
        limit: query.limit,
        total: products.length,
        totalPages: Math.ceil(products.length / query.limit),
      },
    });
  } catch (error) {
    // Handle validation errors
    if (error instanceof z.ZodError) {
      return res.status(400).json({
        error: 'Validation failed',
        message: 'Invalid query parameters',
        details: error.errors.map(e => ({
          field: e.path.join('.'),
          issue: e.message,
        })),
      });
    }

    // Handle unexpected errors
    console.error('Error listing products:', error);
    return res.status(500).json({
      error: 'Internal server error',
      message: 'An unexpected error occurred while listing products',
    });
  }
});

export default router;
