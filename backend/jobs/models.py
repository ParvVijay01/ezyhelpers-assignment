from django.conf import settings
from django.db import models


class Job(models.Model):
    class Status(models.TextChoices):
        ASSIGNED = "ASSIGNED", "Assigned"
        IN_PROGRESS = "IN_PROGRESS", "In Progress"
        COMPLETED = "COMPLETED", "Completed"

    ALLOWED_TRANSITIONS = {
        Status.ASSIGNED: Status.IN_PROGRESS,
        Status.IN_PROGRESS: Status.COMPLETED,
    }

    title = models.CharField(max_length=200)
    description = models.TextField(blank=True)
    location = models.CharField(max_length=255, blank=True)
    scheduled_at = models.DateTimeField(null=True, blank=True)

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

    class Meta:
        ordering = ["-created_at"]
        indexes = [
            models.Index(
                fields=["assigned_helper", "-created_at"],
                name="job_helper_created_idx",
            ),
        ]

    def __str__(self) -> str:
        return f"{self.title} - {self.status}"

    def can_transition_to(self, new_status: str) -> bool:
        return self.ALLOWED_TRANSITIONS.get(self.status) == new_status
