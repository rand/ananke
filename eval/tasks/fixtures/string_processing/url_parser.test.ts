import { parseURL, URLComponents } from './url_parser';

describe('parseURL', () => {
  describe('complete URLs', () => {
    it('should parse a complete URL with all components', () => {
      const result = parseURL('https://example.com:8080/path/to/resource?key1=value1&key2=value2#section');

      expect(result).not.toBeNull();
      expect(result!.protocol).toBe('https');
      expect(result!.host).toBe('example.com');
      expect(result!.port).toBe(8080);
      expect(result!.path).toBe('/path/to/resource');
      expect(result!.query).toEqual({ key1: 'value1', key2: 'value2' });
      expect(result!.fragment).toBe('section');
    });

    it('should parse HTTP URL', () => {
      const result = parseURL('http://www.example.com/index.html');

      expect(result).not.toBeNull();
      expect(result!.protocol).toBe('http');
      expect(result!.host).toBe('www.example.com');
      expect(result!.path).toBe('/index.html');
    });

    it('should parse FTP URL', () => {
      const result = parseURL('ftp://files.example.com/downloads/file.zip');

      expect(result).not.toBeNull();
      expect(result!.protocol).toBe('ftp');
      expect(result!.host).toBe('files.example.com');
      expect(result!.path).toBe('/downloads/file.zip');
    });
  });

  describe('URLs without protocol', () => {
    it('should parse URL without protocol', () => {
      const result = parseURL('example.com/path');

      expect(result).not.toBeNull();
      expect(result!.protocol).toBeNull();
      expect(result!.host).toBe('example.com');
      expect(result!.path).toBe('/path');
    });

    it('should parse domain with port but no protocol', () => {
      const result = parseURL('localhost:3000/api');

      expect(result).not.toBeNull();
      expect(result!.protocol).toBeNull();
      expect(result!.host).toBe('localhost');
      expect(result!.port).toBe(3000);
      expect(result!.path).toBe('/api');
    });
  });

  describe('port handling', () => {
    it('should parse URL with port', () => {
      const result = parseURL('https://example.com:443/secure');

      expect(result).not.toBeNull();
      expect(result!.port).toBe(443);
    });

    it('should default port to null when not specified', () => {
      const result = parseURL('https://example.com/path');

      expect(result).not.toBeNull();
      expect(result!.port).toBeNull();
    });

    it('should handle non-standard ports', () => {
      const result = parseURL('http://localhost:8888');

      expect(result).not.toBeNull();
      expect(result!.port).toBe(8888);
    });
  });

  describe('query parameter parsing', () => {
    it('should parse single query parameter', () => {
      const result = parseURL('https://example.com?key=value');

      expect(result).not.toBeNull();
      expect(result!.query).toEqual({ key: 'value' });
    });

    it('should parse multiple query parameters', () => {
      const result = parseURL('https://example.com?foo=bar&baz=qux&test=123');

      expect(result).not.toBeNull();
      expect(result!.query).toEqual({
        foo: 'bar',
        baz: 'qux',
        test: '123'
      });
    });

    it('should handle query parameters with special characters', () => {
      const result = parseURL('https://example.com?message=hello%20world&symbol=%26');

      expect(result).not.toBeNull();
      expect(result!.query).toEqual({
        message: 'hello world',
        symbol: '&'
      });
    });

    it('should handle empty query parameter values', () => {
      const result = parseURL('https://example.com?key1=&key2=value2');

      expect(result).not.toBeNull();
      expect(result!.query).toEqual({
        key1: '',
        key2: 'value2'
      });
    });

    it('should handle query parameters without values', () => {
      const result = parseURL('https://example.com?flag1&flag2');

      expect(result).not.toBeNull();
      expect(result!.query).toEqual({
        flag1: '',
        flag2: ''
      });
    });

    it('should return empty object when no query parameters', () => {
      const result = parseURL('https://example.com/path');

      expect(result).not.toBeNull();
      expect(result!.query).toEqual({});
    });
  });

  describe('fragment handling', () => {
    it('should parse fragment/hash', () => {
      const result = parseURL('https://example.com/page#section-1');

      expect(result).not.toBeNull();
      expect(result!.fragment).toBe('section-1');
    });

    it('should parse URL with query and fragment', () => {
      const result = parseURL('https://example.com?key=value#top');

      expect(result).not.toBeNull();
      expect(result!.query).toEqual({ key: 'value' });
      expect(result!.fragment).toBe('top');
    });

    it('should default fragment to null when not specified', () => {
      const result = parseURL('https://example.com/path');

      expect(result).not.toBeNull();
      expect(result!.fragment).toBeNull();
    });
  });

  describe('path handling', () => {
    it('should parse simple path', () => {
      const result = parseURL('https://example.com/page.html');

      expect(result).not.toBeNull();
      expect(result!.path).toBe('/page.html');
    });

    it('should parse nested path', () => {
      const result = parseURL('https://example.com/dir1/dir2/file.txt');

      expect(result).not.toBeNull();
      expect(result!.path).toBe('/dir1/dir2/file.txt');
    });

    it('should parse root path', () => {
      const result = parseURL('https://example.com/');

      expect(result).not.toBeNull();
      expect(result!.path).toBe('/');
    });

    it('should default path to null when not specified', () => {
      const result = parseURL('https://example.com');

      expect(result).not.toBeNull();
      expect(result!.path).toBeNull();
    });
  });

  describe('edge cases', () => {
    it('should return null for empty string', () => {
      const result = parseURL('');
      expect(result).toBeNull();
    });

    it('should return null for whitespace-only string', () => {
      const result = parseURL('   ');
      expect(result).toBeNull();
    });

    it('should handle URL with only path', () => {
      const result = parseURL('/path/to/resource');

      expect(result).not.toBeNull();
      expect(result!.protocol).toBeNull();
      expect(result!.host).toBeNull();
      expect(result!.path).toBe('/path/to/resource');
    });

    it('should handle localhost', () => {
      const result = parseURL('http://localhost:3000/api/users');

      expect(result).not.toBeNull();
      expect(result!.host).toBe('localhost');
      expect(result!.port).toBe(3000);
      expect(result!.path).toBe('/api/users');
    });

    it('should handle IP address', () => {
      const result = parseURL('http://192.168.1.1:8080/admin');

      expect(result).not.toBeNull();
      expect(result!.host).toBe('192.168.1.1');
      expect(result!.port).toBe(8080);
      expect(result!.path).toBe('/admin');
    });

    it('should handle subdomain', () => {
      const result = parseURL('https://api.subdomain.example.com/v1/resource');

      expect(result).not.toBeNull();
      expect(result!.host).toBe('api.subdomain.example.com');
      expect(result!.path).toBe('/v1/resource');
    });

    it('should trim whitespace', () => {
      const result = parseURL('  https://example.com/path  ');

      expect(result).not.toBeNull();
      expect(result!.protocol).toBe('https');
      expect(result!.host).toBe('example.com');
      expect(result!.path).toBe('/path');
    });
  });

  describe('protocol variations', () => {
    it('should handle various protocol schemes', () => {
      const protocols = ['http', 'https', 'ftp', 'file', 'ws', 'wss'];

      protocols.forEach(protocol => {
        const result = parseURL(`${protocol}://example.com`);
        expect(result).not.toBeNull();
        expect(result!.protocol).toBe(protocol);
      });
    });

    it('should lowercase protocol', () => {
      const result = parseURL('HTTPS://example.com');

      expect(result).not.toBeNull();
      expect(result!.protocol).toBe('https');
    });
  });
});
