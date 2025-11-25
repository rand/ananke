// Validation Module Test Fixture
// Tests constraint extraction for:
// - Generic types
// - Validation functions
// - Regular expressions
// - Custom error types

type ValidationResult<T> = {
    valid: boolean;
    value?: T;
    errors?: string[];
};

type ValidationRule<T> = {
    name: string;
    validate: (value: T) => boolean;
    message: string;
};

// Email validation with multiple constraints
class EmailValidator {
    private readonly maxLength = 255;
    private readonly minLength = 3;
    private readonly pattern = /^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$/;

    validate(email: string): ValidationResult<string> {
        const errors: string[] = [];

        // Length constraints
        if (email.length < this.minLength) {
            errors.push(`Email must be at least ${this.minLength} characters`);
        }

        if (email.length > this.maxLength) {
            errors.push(`Email must not exceed ${this.maxLength} characters`);
        }

        // Pattern constraint
        if (!this.pattern.test(email)) {
            errors.push('Invalid email format');
        }

        // Domain blacklist constraint
        const blacklistedDomains = ['tempmail.com', 'throwaway.com'];
        const domain = email.split('@')[1];
        if (domain && blacklistedDomains.includes(domain)) {
            errors.push('Email domain is not allowed');
        }

        return {
            valid: errors.length === 0,
            value: errors.length === 0 ? email.toLowerCase() : undefined,
            errors: errors.length > 0 ? errors : undefined
        };
    }
}

// Phone number validation with format constraints
function validatePhoneNumber(phone: string): ValidationResult<string> {
    const cleaned = phone.replace(/\D/g, '');
    const errors: string[] = [];

    // Length constraint
    if (cleaned.length !== 10 && cleaned.length !== 11) {
        errors.push('Phone number must be 10 or 11 digits');
    }

    // Country code constraint
    if (cleaned.length === 11 && !cleaned.startsWith('1')) {
        errors.push('11-digit numbers must start with 1');
    }

    // Area code constraint
    const areaCode = cleaned.length === 11 ? cleaned.substring(1, 4) : cleaned.substring(0, 3);
    if (areaCode.startsWith('0') || areaCode.startsWith('1')) {
        errors.push('Invalid area code');
    }

    return {
        valid: errors.length === 0,
        value: errors.length === 0 ? cleaned : undefined,
        errors: errors.length > 0 ? errors : undefined
    };
}

// Generic validator with customizable rules
class Validator<T> {
    private rules: ValidationRule<T>[] = [];

    addRule(rule: ValidationRule<T>): this {
        this.rules.push(rule);
        return this;
    }

    validate(value: T): ValidationResult<T> {
        const errors: string[] = [];

        for (const rule of this.rules) {
            if (!rule.validate(value)) {
                errors.push(rule.message);
            }
        }

        return {
            valid: errors.length === 0,
            value: errors.length === 0 ? value : undefined,
            errors: errors.length > 0 ? errors : undefined
        };
    }
}

// Password strength validator with multiple constraints
interface PasswordStrength {
    score: number;
    feedback: string[];
    isStrong: boolean;
}

function checkPasswordStrength(password: string): PasswordStrength {
    let score = 0;
    const feedback: string[] = [];

    // Length constraint
    if (password.length >= 8) score += 1;
    else feedback.push('Use at least 8 characters');

    if (password.length >= 12) score += 1;

    // Character type constraints
    if (/[a-z]/.test(password)) score += 1;
    else feedback.push('Include lowercase letters');

    if (/[A-Z]/.test(password)) score += 1;
    else feedback.push('Include uppercase letters');

    if (/[0-9]/.test(password)) score += 1;
    else feedback.push('Include numbers');

    if (/[^a-zA-Z0-9]/.test(password)) score += 1;
    else feedback.push('Include special characters');

    // Common password constraint
    const commonPasswords = ['password', '12345678', 'qwerty'];
    if (commonPasswords.includes(password.toLowerCase())) {
        score = 0;
        feedback.push('Password is too common');
    }

    return {
        score,
        feedback,
        isStrong: score >= 4
    };
}

// Form validation with nested constraints
interface FormData {
    email: string;
    phone: string;
    password: string;
    confirmPassword: string;
}

class FormValidator {
    private emailValidator = new EmailValidator();

    validateForm(data: FormData): ValidationResult<FormData> {
        const errors: string[] = [];

        // Validate email
        const emailResult = this.emailValidator.validate(data.email);
        if (!emailResult.valid && emailResult.errors) {
            errors.push(...emailResult.errors);
        }

        // Validate phone
        const phoneResult = validatePhoneNumber(data.phone);
        if (!phoneResult.valid && phoneResult.errors) {
            errors.push(...phoneResult.errors);
        }

        // Validate password strength
        const passwordStrength = checkPasswordStrength(data.password);
        if (!passwordStrength.isStrong) {
            errors.push(...passwordStrength.feedback);
        }

        // Password confirmation constraint
        if (data.password !== data.confirmPassword) {
            errors.push('Passwords do not match');
        }

        return {
            valid: errors.length === 0,
            value: errors.length === 0 ? data : undefined,
            errors: errors.length > 0 ? errors : undefined
        };
    }
}

export {
    ValidationResult,
    ValidationRule,
    EmailValidator,
    validatePhoneNumber,
    Validator,
    checkPasswordStrength,
    FormValidator
};