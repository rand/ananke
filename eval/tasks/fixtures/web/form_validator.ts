/**
 * Validation rule for a form field
 */
export interface FieldRule {
  required?: boolean;
  minLength?: number;
  maxLength?: number;
  pattern?: RegExp;
  email?: boolean;
}

/**
 * Validation rules for all form fields
 */
export type ValidationRules = Record<string, FieldRule>;

/**
 * Form data to validate
 */
export type FormData = Record<string, string>;

/**
 * Validation result
 */
export interface ValidationResult {
  isValid: boolean;
  fieldErrors: Record<string, string[]>;
}

/**
 * Validates form data against validation rules
 * @param formData - The form data to validate
 * @param rules - The validation rules for each field
 * @returns Validation result with field-specific errors
 */
export function validateForm(
  formData: FormData,
  rules: ValidationRules
): ValidationResult {
  const fieldErrors: Record<string, string[]> = {};

  // Validate each field that has rules
  for (const [fieldName, fieldRules] of Object.entries(rules)) {
    const value = formData[fieldName] || '';
    const errors: string[] = [];

    // Required validation
    if (fieldRules.required && !value.trim()) {
      errors.push(`${fieldName} is required`);
    }

    // Only run other validations if field has a value
    if (value.trim()) {
      // MinLength validation
      if (fieldRules.minLength !== undefined && value.length < fieldRules.minLength) {
        errors.push(
          `${fieldName} must be at least ${fieldRules.minLength} characters`
        );
      }

      // MaxLength validation
      if (fieldRules.maxLength !== undefined && value.length > fieldRules.maxLength) {
        errors.push(
          `${fieldName} must be at most ${fieldRules.maxLength} characters`
        );
      }

      // Pattern validation
      if (fieldRules.pattern && !fieldRules.pattern.test(value)) {
        errors.push(`${fieldName} format is invalid`);
      }

      // Email validation
      if (fieldRules.email && !isValidEmail(value)) {
        errors.push(`${fieldName} must be a valid email address`);
      }
    }

    // Only add to fieldErrors if there are errors
    if (errors.length > 0) {
      fieldErrors[fieldName] = errors;
    }
  }

  return {
    isValid: Object.keys(fieldErrors).length === 0,
    fieldErrors,
  };
}

/**
 * Checks if a string is a valid email address
 */
function isValidEmail(email: string): boolean {
  const emailRegex = /^[^\s@]+@[^\s@]+\.[^\s@]+$/;
  return emailRegex.test(email);
}
