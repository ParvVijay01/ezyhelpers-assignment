from django.urls import path

from . import views

urlpatterns = [
    path("auth/login/", views.LoginView.as_view(), name="login"),
    path("auth/logout/", views.LogoutView.as_view(), name="logout"),
    path("jobs/", views.JobListView.as_view(), name="job-list"),
    path("jobs/<int:pk>/", views.JobDetailView.as_view(), name="job-detail"),
    path(
        "jobs/<int:pk>/status/",
        views.JobStatusUpdateView.as_view(),
        name="job-status-update",
    ),
]
