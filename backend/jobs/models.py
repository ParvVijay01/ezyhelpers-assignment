from django.db import models
from django.conf import settings
# Create your models here.

class Job(models.Model): 

    class Status(models.TextChoices):
        ASSIGNED = "ASSIGNED","Assigned"
        IN_PROGRESS = "IN_PROGRESS", "In Progress"
        COMPLETED = "COMPLETED", "Completed"

    title = models.CharField(max_length=200)
    description = models.TextField(blank = True)
    location = models.CharField(max_length=255, blank = True)
    
    scheduled_at = models.DateTimeField(
        null=True,
        blank=True,
    )

    assigned_helper = models.ForeignKey(
        settings.AUTH_USER_MODEL,
        on_delete=models.CASCADE,
        related_name="assigned_jobs",
    )

    status = models.CharField(
        max_length=20,
        choices=Status.choices,
        default=Status.ASSIGNED,
    )

    created_at = models.DateTimeField(auto_now_add=True)
    updated_at = models.DateTimeField(auto_now=True)

    def __str__(self):
        return f"{self.title} - {self.status}"
