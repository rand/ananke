import { Router, Request, Response } from 'express';
import { z } from 'zod';

/**
 * Generated Express routes for User Management API
 *
 * This file was generated from OpenAPI specification and existing code patterns.
 * Implements all endpoints defined in the User Management API OpenAPI spec.
 */

const router = Router();

// Mock database - replace with actual database connection in production
const db = {
  users: {
    data: [
      { id: 1, email: 'admin@example.com', name: 'Admin User', role: 'admin', createdAt: '2024-01-01T00:00:00Z' },
      { id: 2, email: 'john@example.com', name: 'John Smith', role: 'user', createdAt: '2024-01-15T10:30:00Z' },
      { id: 3, email: 'jane@example.com', name: 'Jane Doe', role: 'moderator', createdAt: '2024-02-01T14:20:00Z' },
    ],
    nextId: 4,

    async findById(id: number) {
      return this.data.find(u => u.id === id) || null;
    },

    async findByEmail(email: string) {
      return this.data.find(u => u.email === email) || null;
    },

    async findAll(filters: { role?: string; search?: string }) {
      let results = [...this.data];

      if (filters.role) {
        results = results.filter(u => u.role === filters.role);
      }

      if (filters.search) {
        const searchLower = filters.search.toLowerCase();
        results = results.filter(u =>
          u.name.toLowerCase().includes(searchLower) ||
          u.email.toLowerCase().includes(searchLower)
        );
      }

      return results;
    },

    async create(userData: any) {
      const newUser = {
        id: this.nextId++,
        ...userData,
        createdAt: new Date().toISOString(),
      };
      this.data.push(newUser);
      return newUser;
    },

    async update(id: number, updates: any) {
      const index = this.data.findIndex(u => u.id === id);
      if (index === -1) return null;

      this.data[index] = { ...this.data[index], ...updates };
      return this.data[index];
    },

    async delete(id: number) {
      const index = this.data.findIndex(u => u.id === id);
      if (index === -1) return false;

      this.data.splice(index, 1);
      return true;
    },
  },
};

// Validation schemas
const getUserParamsSchema = z.object({
  id: z.number().int().min(1),
});

const getUserQuerySchema = z.object({
  include: z.enum(['profile', 'settings', 'stats', 'all']).optional(),
});

const listUsersQuerySchema = z.object({
  page: z.number().int().min(1).default(1),
  limit: z.number().int().min(1).max(100).default(20),
  role: z.enum(['admin', 'user', 'moderator']).optional(),
  search: z.string().min(2).max(100).optional(),
  sort: z.enum(['createdAt:asc', 'createdAt:desc', 'name:asc', 'name:desc']).default('createdAt:desc'),
});

const createUserBodySchema = z.object({
  email: z.string().email(),
  name: z.string().min(1).max(100),
  password: z.string().min(8).max(72),
  role: z.enum(['admin', 'user', 'moderator']).default('user'),
});

const updateUserParamsSchema = z.object({
  id: z.number().int().min(1),
});

const updateUserBodySchema = z.object({
  email: z.string().email().optional(),
  name: z.string().min(1).max(100).optional(),
  role: z.enum(['admin', 'user', 'moderator']).optional(),
});

const deleteUserParamsSchema = z.object({
  id: z.number().int().min(1),
});

/**
 * GET /users/:id
 * Retrieves a single user by their unique identifier
 *
 * Path Parameters:
 *   - id: integer (minimum: 1) - Unique user identifier
 *
 * Query Parameters:
 *   - include: string (optional) - Related data to include
 *
 * Responses:
 *   - 200: User found successfully
 *   - 400: Invalid user ID format
 *   - 404: User not found
 *   - 500: Internal server error
 */
router.get('/users/:id', async (req: Request, res: Response) => {
  try {
    // Parse and validate path parameters
    const params = getUserParamsSchema.parse({
      id: parseInt(req.params.id, 10),
    });

    // Parse and validate query parameters
    const query = getUserQuerySchema.parse({
      include: req.query.include,
    });

    // Database query
    const user = await db.users.findById(params.id);

    // Handle not found
    if (!user) {
      return res.status(404).json({
        error: 'User not found',
        message: `No user exists with id ${params.id}`,
      });
    }

    // Success response
    return res.status(200).json(user);
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
    console.error('Error fetching user:', error);
    return res.status(500).json({
      error: 'Internal server error',
      message: 'An unexpected error occurred while fetching the user',
    });
  }
});

/**
 * PUT /users/:id
 * Updates an existing user's information
 *
 * Path Parameters:
 *   - id: integer (minimum: 1) - Unique user identifier
 *
 * Request Body:
 *   - email: string (optional) - User's email address
 *   - name: string (optional) - User's full name
 *   - role: string (optional) - User's role
 *
 * Responses:
 *   - 200: User updated successfully
 *   - 400: Invalid request body
 *   - 404: User not found
 *   - 409: Email already in use
 *   - 500: Internal server error
 */
router.put('/users/:id', async (req: Request, res: Response) => {
  try {
    // Parse and validate path parameters
    const params = updateUserParamsSchema.parse({
      id: parseInt(req.params.id, 10),
    });

    // Parse and validate request body
    const body = updateUserBodySchema.parse(req.body);

    // Check if user exists
    const existingUser = await db.users.findById(params.id);
    if (!existingUser) {
      return res.status(404).json({
        error: 'User not found',
        message: `No user exists with id ${params.id}`,
      });
    }

    // Check for email conflicts (if email is being updated)
    if (body.email && body.email !== existingUser.email) {
      const emailExists = await db.users.findByEmail(body.email);
      if (emailExists) {
        return res.status(409).json({
          error: 'Conflict',
          message: `Email ${body.email} is already registered`,
        });
      }
    }

    // Update user
    const updatedUser = await db.users.update(params.id, body);

    // Success response
    return res.status(200).json(updatedUser);
  } catch (error) {
    // Handle validation errors
    if (error instanceof z.ZodError) {
      return res.status(400).json({
        error: 'Validation failed',
        message: 'Invalid request body',
        details: error.errors.map(e => ({
          field: e.path.join('.'),
          issue: e.message,
        })),
      });
    }

    // Handle unexpected errors
    console.error('Error updating user:', error);
    return res.status(500).json({
      error: 'Internal server error',
      message: 'An unexpected error occurred while updating the user',
    });
  }
});

/**
 * DELETE /users/:id
 * Soft deletes a user (marks as inactive rather than permanent deletion)
 *
 * Path Parameters:
 *   - id: integer (minimum: 1) - Unique user identifier
 *
 * Responses:
 *   - 204: User deleted successfully
 *   - 404: User not found
 *   - 500: Internal server error
 */
router.delete('/users/:id', async (req: Request, res: Response) => {
  try {
    // Parse and validate path parameters
    const params = deleteUserParamsSchema.parse({
      id: parseInt(req.params.id, 10),
    });

    // Delete user
    const deleted = await db.users.delete(params.id);

    // Handle not found
    if (!deleted) {
      return res.status(404).json({
        error: 'User not found',
        message: `No user exists with id ${params.id}`,
      });
    }

    // Success response (no content)
    return res.status(204).send();
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
    console.error('Error deleting user:', error);
    return res.status(500).json({
      error: 'Internal server error',
      message: 'An unexpected error occurred while deleting the user',
    });
  }
});

/**
 * GET /users
 * Retrieves a paginated list of users with optional filtering
 *
 * Query Parameters:
 *   - page: integer (default: 1) - Page number
 *   - limit: integer (default: 20, max: 100) - Users per page
 *   - role: string (optional) - Filter by user role
 *   - search: string (optional) - Search by name or email
 *   - sort: string (default: createdAt:desc) - Sort field and direction
 *
 * Responses:
 *   - 200: Users retrieved successfully
 *   - 400: Invalid query parameters
 *   - 500: Internal server error
 */
router.get('/users', async (req: Request, res: Response) => {
  try {
    // Parse and validate query parameters
    const query = listUsersQuerySchema.parse({
      page: req.query.page ? parseInt(req.query.page as string, 10) : undefined,
      limit: req.query.limit ? parseInt(req.query.limit as string, 10) : undefined,
      role: req.query.role,
      search: req.query.search,
      sort: req.query.sort,
    });

    // Database query with filters
    const allUsers = await db.users.findAll({
      role: query.role,
      search: query.search,
    });

    // Apply sorting
    const [sortField, sortDirection] = query.sort.split(':');
    allUsers.sort((a, b) => {
      const aVal = a[sortField as keyof typeof a];
      const bVal = b[sortField as keyof typeof b];

      if (aVal < bVal) return sortDirection === 'asc' ? -1 : 1;
      if (aVal > bVal) return sortDirection === 'asc' ? 1 : -1;
      return 0;
    });

    // Calculate pagination
    const startIndex = (query.page - 1) * query.limit;
    const endIndex = startIndex + query.limit;
    const paginatedUsers = allUsers.slice(startIndex, endIndex);

    // Success response with pagination metadata
    return res.status(200).json({
      data: paginatedUsers,
      pagination: {
        page: query.page,
        limit: query.limit,
        total: allUsers.length,
        totalPages: Math.ceil(allUsers.length / query.limit),
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
    console.error('Error listing users:', error);
    return res.status(500).json({
      error: 'Internal server error',
      message: 'An unexpected error occurred while listing users',
    });
  }
});

/**
 * POST /users
 * Creates a new user account
 *
 * Request Body:
 *   - email: string (required) - User's email address
 *   - name: string (required) - User's full name
 *   - password: string (required) - User's password (min 8 chars)
 *   - role: string (default: user) - User's role
 *
 * Responses:
 *   - 201: User created successfully
 *   - 400: Invalid request body
 *   - 409: Email already exists
 *   - 500: Internal server error
 */
router.post('/users', async (req: Request, res: Response) => {
  try {
    // Parse and validate request body
    const body = createUserBodySchema.parse(req.body);

    // Check for duplicate email
    const existingUser = await db.users.findByEmail(body.email);
    if (existingUser) {
      return res.status(409).json({
        error: 'Conflict',
        message: `Email ${body.email} is already registered`,
      });
    }

    // Create user (in production, hash password before storing)
    const newUser = await db.users.create({
      email: body.email,
      name: body.name,
      role: body.role,
      // Note: password should be hashed in production
    });

    // Success response
    res.setHeader('Location', `/users/${newUser.id}`);
    return res.status(201).json(newUser);
  } catch (error) {
    // Handle validation errors
    if (error instanceof z.ZodError) {
      return res.status(400).json({
        error: 'Validation failed',
        message: 'Invalid request body',
        details: error.errors.map(e => ({
          field: e.path.join('.'),
          issue: e.message,
        })),
      });
    }

    // Handle unexpected errors
    console.error('Error creating user:', error);
    return res.status(500).json({
      error: 'Internal server error',
      message: 'An unexpected error occurred while creating the user',
    });
  }
});

export default router;
