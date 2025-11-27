// API Handler Test Fixture
// Tests constraint extraction for:
// - Express-like route handlers
// - Request/response types
// - Middleware patterns
// - Error handling

interface Request {
    body: any;
    params: Record<string, string>;
    query: Record<string, string>;
    headers: Record<string, string>;
    method: string;
    path: string;
}

interface Response {
    status(code: number): Response;
    json(data: any): Response;
    send(data: string): Response;
    setHeader(name: string, value: string): Response;
}

type RequestHandler = (req: Request, res: Response) => Promise<void> | void;
type Middleware = (req: Request, res: Response, next: () => void) => Promise<void> | void;

// Validation middleware with constraints
function validateRequest(schema: any): Middleware {
    return (req, res, next) => {
        // Schema validation constraint
        if (!schema) {
            res.status(500).json({ error: 'Schema is required' });
            return;
        }

        // Validate request body
        const errors = validateSchema(req.body, schema);
        if (errors.length > 0) {
            res.status(400).json({ errors });
            return;
        }

        next();
    };
}

function validateSchema(data: any, schema: any): string[] {
    const errors: string[] = [];

    // Type validation constraints
    for (const [key, type] of Object.entries(schema)) {
        if (!(key in data)) {
            errors.push(`Missing required field: ${key}`);
        } else if (typeof data[key] !== type) {
            errors.push(`Invalid type for ${key}: expected ${type}`);
        }
    }

    return errors;
}

// GET handler with query parameter validation
const getUserHandler: RequestHandler = async (req, res) => {
    // ID parameter constraint
    const userId = req.params.id;
    if (!userId || !/^\d+$/.test(userId)) {
        res.status(400).json({ error: 'Invalid user ID' });
        return;
    }

    // Simulate database lookup
    const user = await fetchUser(parseInt(userId, 10));

    if (!user) {
        res.status(404).json({ error: 'User not found' });
        return;
    }

    res.status(200).json({ data: user });
};

// POST handler with body validation
const createUserHandler: RequestHandler = async (req, res) => {
    const { email, username, password } = req.body;

    // Required field constraints
    if (!email || !username || !password) {
        res.status(400).json({ error: 'Missing required fields' });
        return;
    }

    // Email format constraint
    if (!/^[^\s@]+@[^\s@]+\.[^\s@]+$/.test(email)) {
        res.status(400).json({ error: 'Invalid email format' });
        return;
    }

    // Username length constraint
    if (username.length < 3 || username.length > 30) {
        res.status(400).json({ error: 'Username must be 3-30 characters' });
        return;
    }

    // Password strength constraint
    if (password.length < 8) {
        res.status(400).json({ error: 'Password must be at least 8 characters' });
        return;
    }

    // Simulate user creation
    const newUser = await createUser({ email, username, password });

    res.status(201).json({ data: newUser });
};

// PUT handler with update validation
const updateUserHandler: RequestHandler = async (req, res) => {
    const userId = parseInt(req.params.id, 10);
    const updates = req.body;

    // ID validation constraint
    if (isNaN(userId)) {
        res.status(400).json({ error: 'Invalid user ID' });
        return;
    }

    // Immutable field constraint
    const immutableFields = ['id', 'createdAt'];
    for (const field of immutableFields) {
        if (field in updates) {
            res.status(400).json({ error: `Cannot update ${field}` });
            return;
        }
    }

    // Simulate update
    const updatedUser = await updateUser(userId, updates);

    if (!updatedUser) {
        res.status(404).json({ error: 'User not found' });
        return;
    }

    res.status(200).json({ data: updatedUser });
};

// Simulated database functions
async function fetchUser(id: number): Promise<any> {
    return { id, email: 'test@example.com', username: 'testuser' };
}

async function createUser(data: any): Promise<any> {
    return { id: 1, ...data, createdAt: new Date() };
}

async function updateUser(id: number, updates: any): Promise<any> {
    return { id, ...updates, updatedAt: new Date() };
}

export {
    Request,
    Response,
    RequestHandler,
    Middleware,
    validateRequest,
    getUserHandler,
    createUserHandler,
    updateUserHandler
};
