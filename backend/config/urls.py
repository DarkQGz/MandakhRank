from django.urls import path
from django.contrib import admin
from catalog.views import collection, detail
from catalog import practice, accounts
urlpatterns = [path('api/problems/',practice.problems),path('api/submissions/',practice.submissions),path('api/auth/<str:action>/',accounts.account),path('admin/', admin.site.urls), path('api/<str:kind>/', collection), path('api/<str:kind>/<int:pk>/', detail)]
