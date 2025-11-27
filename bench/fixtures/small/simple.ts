// Small TypeScript fixture (<100 LOC)
// Simple function with basic constraints

interface User {
    id: number;
    name: string;
    email: string;
}

function validateEmail(email: string): boolean {
    const emailRegex = /^[^\s@]+@[^\s@]+\.[^\s@]+$/;
    return emailRegex.test(email);
}

function createUser(name: string, email: string): User | null {
    if (!validateEmail(email)) {
        return null;
    }
    
    return {
        id: Math.floor(Math.random() * 10000),
        name: name.trim(),
        email: email.toLowerCase(),
    };
}

export { User, createUser, validateEmail };
