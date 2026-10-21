
from django.contrib import admin
from django.urls import path

from jobs.views import (
    login_view,
    job_list_view,
    job_detail_view,
    update_job_status_view,
)


urlpatterns = [
    path("admin/", admin.site.urls),

    path(
        "api/auth/login/",
        login_view,
        name="login",
    ),
    path(
        "api/jobs/",
        job_list_view,
        name="job-list",
    ),
    path(
        "api/jobs/<int:pk>/",
        job_detail_view,
        name="job-detail",
    ),
    path(
        "api/jobs/<int:pk>/status/",
        update_job_status_view,
        name="job-status-update",
    ),
]
