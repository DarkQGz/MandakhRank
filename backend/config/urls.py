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
from catalog import practice, accounts, cms_bridge, profile, admin_overview, minigames
from catalog import social, learning
urlpatterns = [
    path('api/learning/<int:course_id>/', learning.course),
    path('api/learning/<int:course_id>/quiz/<int:lesson_id>/', learning.quiz),
    path('api/profile/public/<int:user_id>/', social.public_profile), path('api/profile/public/<int:user_id>/comments/<int:comment_id>/delete/', social.delete_comment), path('api/games/create/', minigames.create), path('api/games/<str:code>/', minigames.room_action), path('api/games/<str:code>/<str:action>/', minigames.room_action),path('api/profile/me/', profile.me),path('api/profile/avatar/', profile.avatar),path('api/profile/avatar/<int:user_id>/', profile.public_avatar),path('api/judge/<str:action>/', cms_bridge.endpoint),path('',app_home),path('api/problems/',practice.problems),path('api/submissions/',practice.submissions),path('api/auth/<str:action>/',accounts.account),path('admin/overview/', admin_overview.overview), path('admin/', admin.site.urls), path('api/<str:kind>/', collection), path('api/<str:kind>/<int:pk>/', detail)]
