// Docker health check for the Ghost container.
// Sends a single HTTP request to Ghost's local port and exits 0 (healthy)
// for any response with a status code below 500, or 1 (unhealthy) on error
// or a 5xx response.  Node.js is guaranteed to be present in the ghost image.
require('http')
  .get('http://localhost:2368/', (r) => process.exit(r.statusCode < 500 ? 0 : 1))
  .on('error', () => process.exit(1));
