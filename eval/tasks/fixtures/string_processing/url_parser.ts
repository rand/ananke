interface URLComponents {
  protocol: string | null;
  host: string | null;
  port: number | null;
  path: string | null;
  query: Record<string, string>;
  fragment: string | null;
}

function parseURL(url: string): URLComponents | null {
  if (!url || url.trim().length === 0) {
    return null;
  }

  try {
    const components: URLComponents = {
      protocol: null,
      host: null,
      port: null,
      path: null,
      query: {},
      fragment: null,
    };

    let remaining = url.trim();

    // Extract protocol
    const protocolMatch = remaining.match(/^([a-zA-Z][a-zA-Z0-9+.-]*):\/\//);
    if (protocolMatch) {
      components.protocol = protocolMatch[1].toLowerCase();
      remaining = remaining.substring(protocolMatch[0].length);
    }

    // Extract fragment first (appears at end)
    const fragmentIndex = remaining.indexOf('#');
    if (fragmentIndex !== -1) {
      components.fragment = remaining.substring(fragmentIndex + 1);
      remaining = remaining.substring(0, fragmentIndex);
    }

    // Extract query string
    const queryIndex = remaining.indexOf('?');
    if (queryIndex !== -1) {
      const queryString = remaining.substring(queryIndex + 1);
      components.query = parseQueryString(queryString);
      remaining = remaining.substring(0, queryIndex);
    }

    // Extract path
    const pathIndex = remaining.indexOf('/');
    if (pathIndex !== -1) {
      components.path = remaining.substring(pathIndex);
      remaining = remaining.substring(0, pathIndex);
    }

    // Extract host and port from remaining
    if (remaining.length > 0) {
      const portMatch = remaining.match(/:(\d+)$/);
      if (portMatch) {
        components.port = parseInt(portMatch[1], 10);
        components.host = remaining.substring(0, portMatch.index);
      } else {
        components.host = remaining;
      }
    }

    // Validation: must have at least host or path
    if (!components.host && !components.path) {
      return null;
    }

    return components;
  } catch (error) {
    return null;
  }
}

function parseQueryString(query: string): Record<string, string> {
  const params: Record<string, string> = {};

  if (!query || query.length === 0) {
    return params;
  }

  const pairs = query.split('&');
  for (const pair of pairs) {
    const [key, value] = pair.split('=');
    if (key) {
      params[decodeURIComponent(key)] = decodeURIComponent(value || '');
    }
  }

  return params;
}

export { parseURL, URLComponents };
