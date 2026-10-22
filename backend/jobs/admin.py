
# Register your models here.
from django.contrib import admin

from .models import Job


@admin.register(Job)
class JobAdmin(admin.ModelAdmin):
    list_display = ("id", "title", "assigned_helper", "status", "scheduled_at")
    list_filter = ("status",)
    search_fields = ("title", "location", "assigned_helper__username")
    list_select_related = ("assigned_helper",)
