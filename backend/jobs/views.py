import logging

from django.contrib.auth import authenticate
from django.db import transaction
from django.shortcuts import get_object_or_404
from rest_framework import generics, status
from rest_framework.authtoken.models import Token
from rest_framework.permissions import AllowAny
from rest_framework.response import Response
from rest_framework.throttling import ScopedRateThrottle
from rest_framework.views import APIView

from .models import Job
from .serializers import JobSerializer, JobStatusSerializer, LoginSerializer

logger = logging.getLogger(__name__)


class LoginView(APIView):
    authentication_classes = []
    permission_classes = [AllowAny]
    throttle_classes = [ScopedRateThrottle]
    throttle_scope = "login"

    def post(self, request):
        serializer = LoginSerializer(data=request.data)
        serializer.is_valid(raise_exception=True)

        user = authenticate(request, **serializer.validated_data)
        if user is None:
            logger.warning(
                "Failed login attempt from %s", request.META.get("REMOTE_ADDR")
            )
            return Response(
                {"error": "Invalid username or password."},
                status=status.HTTP_401_UNAUTHORIZED,
            )

        token, _ = Token.objects.get_or_create(user=user)
        logger.info("User %s logged in", user.pk)
        return Response({"token": token.key, "username": user.username})


class LogoutView(APIView):
    def post(self, request):
        Token.objects.filter(user=request.user).delete()
        logger.info("User %s logged out", request.user.pk)
        return Response(status=status.HTTP_204_NO_CONTENT)


class HelperJobsMixin:
    serializer_class = JobSerializer

    def get_queryset(self):
        return Job.objects.filter(assigned_helper=self.request.user).select_related(
            "assigned_helper"
        )


class JobListView(HelperJobsMixin, generics.ListAPIView):
    pass


class JobDetailView(HelperJobsMixin, generics.RetrieveAPIView):
    pass


class JobStatusUpdateView(APIView):
    def patch(self, request, pk):
        serializer = JobStatusSerializer(data=request.data)
        serializer.is_valid(raise_exception=True)
        new_status = serializer.validated_data["status"]

        with transaction.atomic():
            job = get_object_or_404(
                Job.objects.select_for_update().filter(
                    assigned_helper=request.user
                ),
                pk=pk,
            )

            if not job.can_transition_to(new_status):
                logger.info(
                    "Rejected transition %s -> %s for job %s (user %s)",
                    job.status,
                    new_status,
                    job.pk,
                    request.user.pk,
                )
                return Response(
                    {
                        "error": (
                            f"Cannot change status from {job.status} "
                            f"to {new_status}."
                        )
                    },
                    status=status.HTTP_409_CONFLICT,
                )

            previous = job.status
            job.status = new_status
            job.save(update_fields=["status", "updated_at"])

        logger.info(
            "Job %s moved %s -> %s by user %s",
            job.pk,
            previous,
            new_status,
            request.user.pk,
        )
        return Response(JobSerializer(job).data)
