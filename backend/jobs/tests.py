
from django.contrib.auth.models import User
from rest_framework import status
from rest_framework.authtoken.models import Token
from rest_framework.test import APITestCase

from .models import Job


class JobAPITests(APITestCase):
    def setUp(self):
        self.helper1 = User.objects.create_user(
            username="helper1",
            password="DemoPass123!",
        )
        self.helper2 = User.objects.create_user(
            username="helper2",
            password="DemoPass123!",
        )

        self.token1 = Token.objects.create(user=self.helper1)

        self.job = Job.objects.create(
            title="Home Cleaning",
            description="Clean the living room.",
            location="Demo Address A",
            assigned_helper=self.helper1,
            status=Job.Status.ASSIGNED,
        )

        self.other_job = Job.objects.create(
            title="Plumbing Repair",
            assigned_helper=self.helper2,
            status=Job.Status.ASSIGNED,
        )

        self.client.credentials(
            HTTP_AUTHORIZATION=f"Token {self.token1.key}"
        )

    def test_helper_can_view_own_job(self):
        response = self.client.get(
            f"/api/jobs/{self.job.id}/"
        )

        self.assertEqual(response.status_code, status.HTTP_200_OK)

    def test_helper_cannot_view_another_helpers_job(self):
        response = self.client.get(
            f"/api/jobs/{self.other_job.id}/"
        )

        self.assertEqual(response.status_code, status.HTTP_404_NOT_FOUND)

    def test_assigned_job_can_start(self):
        response = self.client.patch(
            f"/api/jobs/{self.job.id}/status/",
            {"status": "IN_PROGRESS"},
            format="json",
        )

        self.assertEqual(response.status_code, status.HTTP_200_OK)

        self.job.refresh_from_db()
        self.assertEqual(
            self.job.status,
            Job.Status.IN_PROGRESS,
        )

    def test_assigned_job_cannot_be_completed_directly(self):
        response = self.client.patch(
            f"/api/jobs/{self.job.id}/status/",
            {"status": "COMPLETED"},
            format="json",
        )

        self.assertEqual(
            response.status_code,
            status.HTTP_400_BAD_REQUEST,
        )

        self.job.refresh_from_db()
        self.assertEqual(
            self.job.status,
            Job.Status.ASSIGNED,
        )

    def test_unauthenticated_request_is_rejected(self):
        self.client.credentials()

        response = self.client.get("/api/jobs/")

        self.assertEqual(
            response.status_code,
            status.HTTP_401_UNAUTHORIZED,
        )
