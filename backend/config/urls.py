from django.urls import path
from django.contrib import admin
from django.conf import settings
from django.http import FileResponse, HttpResponse

def app_home(request):
    index = settings.BASE_DIR / "webapp" / "index.html"
    if not index.exists():
        return HttpResponse("Flutter web build missing. See UPGRADE.md", status=503)
    response = FileResponse(index.open("rb"), content_type="text/html")
    response["Cache-Control"] = "no-cache"
    return response

from catalog.views import collection, detail
from catalog import practice, accounts, cms_bridge, profile, admin_overview
urlpatterns = [path('api/profile/me/', profile.me),path('api/profile/avatar/', profile.avatar),path('api/profile/avatar/<int:user_id>/', profile.public_avatar),path('api/judge/<str:action>/', cms_bridge.endpoint),path('',app_home),path('api/problems/',practice.problems),path('api/submissions/',practice.submissions),path('api/auth/<str:action>/',accounts.account),path('admin/overview/', admin_overview.overview), path('admin/', admin.site.urls), path('api/<str:kind>/', collection), path('api/<str:kind>/<int:pk>/', detail)]
