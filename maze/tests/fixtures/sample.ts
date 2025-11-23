// Sample TypeScript code for constraint extraction testing
interface UserAuth {
    username: string;
    password: string;
    email?: string;
}

class AuthService {
    private users: Map<string, UserAuth> = new Map();
    
    async authenticate(username: string, password: string): Promise<boolean> {
        const user = this.users.get(username);
        if (!user) {
            return false;
        }
        return user.password === password;
    }
    
    register(user: UserAuth): void {
        if (this.users.has(user.username)) {
            throw new Error("User already exists");
        }
        this.users.set(user.username, user);
    }
}
