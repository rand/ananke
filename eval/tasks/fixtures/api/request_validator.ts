/**
 * Validation schema definition
 */
export interface ValidationSchema {
  [key: string]: {
    type: 'string' | 'number' | 'boolean' | 'array' | 'object';
    required?: boolean;
    properties?: ValidationSchema; // For nested objects
  };
}

/**
 * Validation result
 */
export interface ValidationResult {
  valid: boolean;
  errors: string[];
}

/**
 * Validates an HTTP request object against a schema
 * @param request - The request object to validate
 * @param schema - The validation schema
 * @returns Validation result with errors if any
 */
export function validateRequest(
  request: Record<string, any>,
  schema: ValidationSchema
): ValidationResult {
  const errors: string[] = [];

  // Check each field in the schema
  for (const [fieldName, fieldSchema] of Object.entries(schema)) {
    const value = request[fieldName];

    // Check required fields
    if (fieldSchema.required && (value === undefined || value === null)) {
      errors.push(`Field '${fieldName}' is required`);
      continue;
    }

    // Skip validation if field is not present and not required
    if (value === undefined || value === null) {
      continue;
    }

    // Validate type
    const actualType = getType(value);
    if (actualType !== fieldSchema.type) {
      errors.push(
        `Field '${fieldName}' must be of type ${fieldSchema.type}, got ${actualType}`
      );
      continue;
    }

    // Validate nested objects
    if (fieldSchema.type === 'object' && fieldSchema.properties) {
      const nestedResult = validateRequest(value, fieldSchema.properties);
      for (const error of nestedResult.errors) {
        errors.push(`${fieldName}.${error}`);
      }
    }
  }

  return {
    valid: errors.length === 0,
    errors,
  };
}

/**
 * Get the type of a value for validation
 */
function getType(value: any): string {
  if (Array.isArray(value)) {
    return 'array';
  }
  if (value === null) {
    return 'null';
  }
  return typeof value;
}
