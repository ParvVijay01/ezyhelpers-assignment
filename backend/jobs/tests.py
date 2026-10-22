import logging

from django.contrib.auth.models import User
from django.core.cache import cache
from rest_framework import status
from rest_framework.authtoken.models import Token
from rest_framework.test import APITestCase

from .models import Job

PASSWORD = "DemoPass123!"


def setUpModule():
    logging.disable(logging.CRITICAL)


def tearDownModule():
    logging.disable(logging.NOTSET)


class BaseAPITestCase(APITestCase):
    def setUp(self):
        cache.clear()
        self.helper1 = User.objects.create_user("helper1", password=PASSWORD)
        self.helper2 = User.objects.create_user("helper2", password=PASSWORD)

        self.job = Job.objects.create(
            title="Home Cleaning",
            description="Clean the living room.",
            location="Demo Address A",
            assigned_helper=self.helper1,
        )
        self.other_job = Job.objects.create(
            title="Plumbing Repair",
            assigned_helper=self.helper2,
        )

    def authenticate(self, user):
        token, _ = Token.objects.get_or_create(user=user)
        self.client.credentials(HTTP_AUTHORIZATION=f"Token {token.key}")

    def patch_status(self, job, new_status):
        return self.client.patch(
            f"/api/jobs/{job.id}/status/",
            {"status": new_status},
            format="json",
        )


class AuthTests(BaseAPITestCase):
    def test_login_returns_token(self):
        response = self.client.post(
            "/api/auth/login/",
            {"username": "helper1", "password": PASSWORD},
            format="json",
        )

        self.assertEqual(response.status_code, status.HTTP_200_OK)
        self.assertEqual(response.data["username"], "helper1")
        self.assertTrue(Token.objects.filter(key=response.data["token"]).exists())

    def test_login_rejects_wrong_password(self):
        response = self.client.post(
            "/api/auth/login/",
            {"username": "helper1", "password": "wrong"},
            format="json",
        )

        self.assertEqual(response.status_code, status.HTTP_401_UNAUTHORIZED)

    def test_login_requires_both_fields(self):
        response = self.client.post(
            "/api/auth/login/", {"username": "helper1"}, format="json"
        )

        self.assertEqual(response.status_code, status.HTTP_400_BAD_REQUEST)

    def test_logout_invalidates_token(self):
        self.authenticate(self.helper1)

        response = self.client.post("/api/auth/logout/")
        self.assertEqual(response.status_code, status.HTTP_204_NO_CONTENT)

        response = self.client.get("/api/jobs/")
        self.assertEqual(response.status_code, status.HTTP_401_UNAUTHORIZED)


class JobReadTests(BaseAPITestCase):
    def test_unauthenticated_request_is_rejected(self):
        response = self.client.get("/api/jobs/")

        self.assertEqual(response.status_code, status.HTTP_401_UNAUTHORIZED)

    def test_list_returns_only_own_jobs(self):
        self.authenticate(self.helper1)

        response = self.client.get("/api/jobs/")

        self.assertEqual(response.status_code, status.HTTP_200_OK)
        self.assertEqual([job["id"] for job in response.data], [self.job.id])

    def test_helper_can_view_own_job(self):
        self.authenticate(self.helper1)

        response = self.client.get(f"/api/jobs/{self.job.id}/")

        self.assertEqual(response.status_code, status.HTTP_200_OK)
        self.assertEqual(response.data["title"], "Home Cleaning")

    def test_helper_cannot_view_another_helpers_job(self):
        self.authenticate(self.helper1)

        response = self.client.get(f"/api/jobs/{self.other_job.id}/")

        self.assertEqual(response.status_code, status.HTTP_404_NOT_FOUND)


class JobStatusUpdateTests(BaseAPITestCase):
    def setUp(self):
        super().setUp()
        self.authenticate(self.helper1)

    def test_assigned_job_can_start(self):
        response = self.patch_status(self.job, "IN_PROGRESS")

        self.assertEqual(response.status_code, status.HTTP_200_OK)
        self.assertEqual(response.data["status"], "IN_PROGRESS")
        self.job.refresh_from_db()
        self.assertEqual(self.job.status, Job.Status.IN_PROGRESS)

    def test_full_workflow_reaches_completed(self):
        self.patch_status(self.job, "IN_PROGRESS")
        response = self.patch_status(self.job, "COMPLETED")

        self.assertEqual(response.status_code, status.HTTP_200_OK)
        self.job.refresh_from_db()
        self.assertEqual(self.job.status, Job.Status.COMPLETED)

    def test_assigned_job_cannot_skip_to_completed(self):
        response = self.patch_status(self.job, "COMPLETED")

        self.assertEqual(response.status_code, status.HTTP_409_CONFLICT)
        self.job.refresh_from_db()
        self.assertEqual(self.job.status, Job.Status.ASSIGNED)

    def test_completed_job_is_final(self):
        self.job.status = Job.Status.COMPLETED
        self.job.save()

        for target in ("ASSIGNED", "IN_PROGRESS", "COMPLETED"):
            with self.subTest(target=target):
                response = self.patch_status(self.job, target)
                self.assertEqual(response.status_code, status.HTTP_409_CONFLICT)

    def test_in_progress_job_cannot_move_backwards(self):
        self.job.status = Job.Status.IN_PROGRESS
        self.job.save()

        response = self.patch_status(self.job, "ASSIGNED")

        self.assertEqual(response.status_code, status.HTTP_409_CONFLICT)

    def test_unknown_status_value_is_rejected(self):
        response = self.patch_status(self.job, "DONE")

        self.assertEqual(response.status_code, status.HTTP_400_BAD_REQUEST)

    def test_missing_status_is_rejected(self):
        response = self.client.patch(
            f"/api/jobs/{self.job.id}/status/", {}, format="json"
        )

        self.assertEqual(response.status_code, status.HTTP_400_BAD_REQUEST)

    def test_helper_cannot_update_another_helpers_job(self):
        response = self.patch_status(self.other_job, "IN_PROGRESS")

        self.assertEqual(response.status_code, status.HTTP_404_NOT_FOUND)
        self.other_job.refresh_from_db()
        self.assertEqual(self.other_job.status, Job.Status.ASSIGNED)

    def test_unauthenticated_update_is_rejected(self):
        self.client.credentials()

        response = self.patch_status(self.job, "IN_PROGRESS")

        self.assertEqual(response.status_code, status.HTTP_401_UNAUTHORIZED)
