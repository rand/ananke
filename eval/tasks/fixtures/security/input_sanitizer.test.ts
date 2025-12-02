import { describe, it, expect } from '@jest/globals';
import { sanitizeInput } from './input_sanitizer';

describe('sanitizeInput', () => {
  // Basic HTML escaping
  it('should escape HTML special characters', () => {
    const input = '<div>Hello & goodbye</div>';
    const result = sanitizeInput(input);

    expect(result).toBe('&lt;div&gt;Hello &amp; goodbye&lt;/div&gt;');
  });

  it('should escape quotes', () => {
    const input = `He said "Hello" and 'goodbye'`;
    const result = sanitizeInput(input);

    expect(result).toBe('He said &quot;Hello&quot; and &#x27;goodbye&#x27;');
  });

  it('should escape less than and greater than', () => {
    expect(sanitizeInput('5 < 10')).toBe('5 &lt; 10');
    expect(sanitizeInput('10 > 5')).toBe('10 &gt; 5');
  });

  // Script tag removal
  it('should remove script tags and content', () => {
    const input = '<script>alert("XSS")</script>';
    const result = sanitizeInput(input);

    expect(result).not.toContain('script');
    expect(result).not.toContain('alert');
    expect(result).toBe('');
  });

  it('should remove script tags with attributes', () => {
    const input = '<script type="text/javascript">alert("XSS")</script>';
    const result = sanitizeInput(input);

    expect(result).toBe('');
  });

  it('should remove multiple script tags', () => {
    const input = '<script>alert(1)</script>Hello<script>alert(2)</script>';
    const result = sanitizeInput(input);

    expect(result).toBe('Hello');
  });

  it('should remove script tags case-insensitively', () => {
    const input = '<SCRIPT>alert("XSS")</SCRIPT>';
    const result = sanitizeInput(input);

    expect(result).toBe('');
  });

  it('should handle nested script tags', () => {
    const input = '<script><script>alert("XSS")</script></script>';
    const result = sanitizeInput(input);

    expect(result).not.toContain('alert');
  });

  // Event handler removal
  it('should remove onclick event handler', () => {
    const input = '<div onclick="alert(\'XSS\')">Click me</div>';
    const result = sanitizeInput(input);

    expect(result).not.toContain('onclick');
    expect(result).toContain('Click me');
  });

  it('should remove onerror event handler', () => {
    const input = '<img onerror="alert(\'XSS\')" src="invalid">';
    const result = sanitizeInput(input);

    expect(result).not.toContain('onerror');
    expect(result).not.toContain('alert');
  });

  it('should remove onload event handler', () => {
    const input = '<body onload="alert(\'XSS\')">';
    const result = sanitizeInput(input);

    expect(result).not.toContain('onload');
  });

  it('should remove multiple event handlers', () => {
    const input = '<div onclick="alert(1)" onmouseover="alert(2)">Text</div>';
    const result = sanitizeInput(input);

    expect(result).not.toContain('onclick');
    expect(result).not.toContain('onmouseover');
    expect(result).toContain('Text');
  });

  it('should remove event handlers with different quote styles', () => {
    const input1 = `<div onclick="alert('XSS')">Text</div>`;
    const input2 = `<div onclick='alert("XSS")'>Text</div>`;

    expect(sanitizeInput(input1)).not.toContain('onclick');
    expect(sanitizeInput(input2)).not.toContain('onclick');
  });

  // JavaScript URL removal
  it('should remove javascript: protocol', () => {
    const input = '<a href="javascript:alert(\'XSS\')">Click</a>';
    const result = sanitizeInput(input);

    expect(result).not.toContain('javascript:');
    expect(result).toContain('Click');
  });

  it('should remove javascript: protocol case-insensitively', () => {
    const input1 = '<a href="JAVASCRIPT:alert(\'XSS\')">Click</a>';
    const input2 = '<a href="JaVaScRiPt:alert(\'XSS\')">Click</a>';

    expect(sanitizeInput(input1)).not.toContain('JAVASCRIPT:');
    expect(sanitizeInput(input2)).not.toContain('JaVaScRiPt:');
  });

  // Null/undefined handling
  it('should return empty string for null input', () => {
    expect(sanitizeInput(null)).toBe('');
  });

  it('should return empty string for undefined input', () => {
    expect(sanitizeInput(undefined)).toBe('');
  });

  // Safe text preservation
  it('should preserve safe text content', () => {
    const input = 'Hello, World! This is safe text.';
    const result = sanitizeInput(input);

    expect(result).toBe(input);
  });

  it('should preserve numbers and special characters', () => {
    const input = 'Price: $19.99 (20% off!)';
    const result = sanitizeInput(input);

    expect(result).toBe(input);
  });

  it('should preserve newlines and whitespace', () => {
    const input = 'Line 1\nLine 2\n  Indented';
    const result = sanitizeInput(input);

    expect(result).toBe(input);
  });

  // Combined attacks
  it('should handle multiple attack vectors combined', () => {
    const input = '<script>alert("XSS")</script><img onerror="alert(\'XSS\')" src="x"><a href="javascript:alert(\'XSS\')">Click</a>';
    const result = sanitizeInput(input);

    expect(result).not.toContain('script');
    expect(result).not.toContain('onerror');
    expect(result).not.toContain('javascript:');
    expect(result).not.toContain('alert');
  });

  it('should sanitize script tag with event handler', () => {
    const input = '<div onclick="<script>alert(\'XSS\')</script>">Text</div>';
    const result = sanitizeInput(input);

    expect(result).not.toContain('script');
    expect(result).not.toContain('onclick');
  });

  // Edge cases
  it('should handle empty string', () => {
    expect(sanitizeInput('')).toBe('');
  });

  it('should handle string with only spaces', () => {
    expect(sanitizeInput('   ')).toBe('   ');
  });

  it('should handle malformed HTML', () => {
    const input = '<div onclick="alert(1)" class="test" onerror="alert(2)">';
    const result = sanitizeInput(input);

    expect(result).not.toContain('onclick');
    expect(result).not.toContain('onerror');
  });

  it('should handle unclosed script tag', () => {
    const input = '<script>alert("XSS")';
    const result = sanitizeInput(input);

    // Note: Unclosed tags might not be fully removed by simple regex
    // This test documents current behavior
    expect(result).toContain('&lt;script&gt;');
  });

  // Real-world examples
  it('should sanitize user comment with XSS attempt', () => {
    const input = 'Great article! <script>alert("Hacked")</script> Very informative.';
    const result = sanitizeInput(input);

    expect(result).toBe('Great article!  Very informative.');
  });

  it('should sanitize form input with event handler', () => {
    const input = '<input type="text" onkeyup="sendToServer(this.value)">';
    const result = sanitizeInput(input);

    expect(result).not.toContain('onkeyup');
    expect(result).not.toContain('sendToServer');
  });

  it('should preserve safe HTML-like text', () => {
    const input = 'To use tags like <div> in HTML, escape them properly.';
    const result = sanitizeInput(input);

    expect(result).toBe('To use tags like &lt;div&gt; in HTML, escape them properly.');
  });

  it('should handle complex nested attack', () => {
    const input = '<div><script>eval(location.hash.substr(1))</script><img src=x onerror="alert(1)"></div>';
    const result = sanitizeInput(input);

    expect(result).not.toContain('script');
    expect(result).not.toContain('eval');
    expect(result).not.toContain('onerror');
  });

  it('should sanitize SVG-based XSS', () => {
    const input = '<svg onload="alert(\'XSS\')"></svg>';
    const result = sanitizeInput(input);

    expect(result).not.toContain('onload');
  });

  // Performance
  it('should handle large input efficiently', () => {
    const input = 'Safe text '.repeat(1000) + '<script>alert("XSS")</script>';

    const start = Date.now();
    const result = sanitizeInput(input);
    const duration = Date.now() - start;

    expect(duration).toBeLessThan(100); // Should complete in <100ms
    expect(result).not.toContain('script');
  });
});
