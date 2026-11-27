from django.utils.cache import patch_vary_headers

class PrivateResponseMiddleware:
    """Never let a browser/proxy cache credentials or account-dependent API data."""
    def __init__(self, get_response):
        self.get_response = get_response
    def __call__(self, request):
        response = self.get_response(request)
        path = request.path_info
        # Public versioned avatars are deliberately cacheable for 300 seconds.
        public_avatar = path.startswith('/api/profile/avatar/') and path.removeprefix('/api/profile/avatar/').rstrip('/').isdigit() and request.method == 'GET' and response.status_code == 200
        if (path.startswith('/api/') and not public_avatar) or path.startswith('/admin/') or path == '/healthz/':
            if 'no-store' not in response.get('Cache-Control', '').lower():
                response['Cache-Control'] = 'private, no-store'
            patch_vary_headers(response, ('Authorization', 'Cookie'))
        return response
