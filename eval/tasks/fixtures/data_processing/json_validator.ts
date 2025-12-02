interface Schema {
  required?: string[];
  properties: Record<string, PropertySchema>;
}

interface PropertySchema {
  type: 'string' | 'number' | 'boolean' | 'object' | 'array';
  properties?: Record<string, PropertySchema>;
  required?: string[];
}

interface ValidationResult {
  valid: boolean;
  errors: string[];
}

function validateJSON(data: any, schema: Schema): ValidationResult {
  const errors: string[] = [];

  // Check required fields
  if (schema.required) {
    for (const field of schema.required) {
      if (!(field in data)) {
        errors.push(`Missing required field: ${field}`);
      }
    }
  }

  // Validate each property in the schema
  for (const [fieldName, fieldSchema] of Object.entries(schema.properties)) {
    // Skip if field is not in data and not required
    if (!(fieldName in data)) {
      continue;
    }

    const value = data[fieldName];
    const fieldErrors = validateField(fieldName, value, fieldSchema);
    errors.push(...fieldErrors);
  }

  return {
    valid: errors.length === 0,
    errors
  };
}

function validateField(fieldName: string, value: any, schema: PropertySchema): string[] {
  const errors: string[] = [];

  // Check type
  const actualType = getType(value);
  if (actualType !== schema.type) {
    errors.push(`Field '${fieldName}' has invalid type. Expected ${schema.type}, got ${actualType}`);
    return errors; // Stop validation if type is wrong
  }

  // For objects, recursively validate nested properties
  if (schema.type === 'object' && schema.properties) {
    // Check required nested fields
    if (schema.required) {
      for (const nestedField of schema.required) {
        if (!(nestedField in value)) {
          errors.push(`Field '${fieldName}.${nestedField}' is required`);
        }
      }
    }

    // Validate nested properties
    for (const [nestedFieldName, nestedFieldSchema] of Object.entries(schema.properties)) {
      if (nestedFieldName in value) {
        const nestedErrors = validateField(
          `${fieldName}.${nestedFieldName}`,
          value[nestedFieldName],
          nestedFieldSchema
        );
        errors.push(...nestedErrors);
      }
    }
  }

  return errors;
}

function getType(value: any): string {
  if (value === null) {
    return 'null';
  }
  if (Array.isArray(value)) {
    return 'array';
  }
  return typeof value;
}

export { validateJSON, Schema, PropertySchema, ValidationResult };
