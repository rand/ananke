/**
 * Sanitizes user input to prevent XSS attacks
 * @param input - User input string to sanitize
 * @returns Sanitized string safe for HTML rendering
 */
export function sanitizeInput(input: string | null | undefined): string {
  // Handle null/undefined input
  if (input === null || input === undefined) {
    return '';
  }

  let sanitized = input;

  // Step 1: Remove script tags and their content
  sanitized = removeScriptTags(sanitized);

  // Step 2: Remove event handler attributes
  sanitized = removeEventHandlers(sanitized);

  // Step 3: Remove javascript: protocol URLs
  sanitized = removeJavaScriptUrls(sanitized);

  // Step 4: Escape HTML special characters
  sanitized = escapeHtml(sanitized);

  return sanitized;
}

/**
 * Removes script tags and their content
 */
function removeScriptTags(text: string): string {
  // Remove script tags (case-insensitive, handles malformed tags)
  return text.replace(/<script\b[^<]*(?:(?!<\/script>)<[^<]*)*<\/script>/gi, '');
}

/**
 * Removes event handler attributes from HTML
 */
function removeEventHandlers(text: string): string {
  // Remove event handler attributes (onclick, onerror, onload, etc.)
  // Matches: on<event>="..." or on<event>='...'
  return text.replace(/\s*on\w+\s*=\s*["'][^"']*["']/gi, '');
}

/**
 * Removes javascript: protocol from URLs
 */
function removeJavaScriptUrls(text: string): string {
  // Remove javascript: protocol (case-insensitive)
  return text.replace(/javascript:/gi, '');
}

/**
 * Escapes HTML special characters to prevent injection
 */
function escapeHtml(text: string): string {
  const htmlEscapes: Record<string, string> = {
    '<': '&lt;',
    '>': '&gt;',
    '&': '&amp;',
    '"': '&quot;',
    "'": '&#x27;',
  };

  return text.replace(/[<>&"']/g, (char) => htmlEscapes[char]);
}
