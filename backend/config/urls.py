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
from catalog import practice, accounts
urlpatterns = [path('',app_home),path('api/problems/',practice.problems),path('api/submissions/',practice.submissions),path('api/auth/<str:action>/',accounts.account),path('admin/', admin.site.urls), path('api/<str:kind>/', collection), path('api/<str:kind>/<int:pk>/', detail)]
