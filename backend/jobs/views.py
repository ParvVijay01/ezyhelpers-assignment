
from django.contrib.auth import authenticate
from django.shortcuts import get_object_or_404

from rest_framework import status
from rest_framework.authtoken.models import Token
from rest_framework.decorators import (
    api_view,
    permission_classes,
)
from rest_framework.permissions import AllowAny
from rest_framework.response import Response

from .models import Job
from .serializers import JobSerializer, JobStatusSerializer


@api_view(["POST"])
@permission_classes([AllowAny])
def login_view(request):
    username = request.data.get("username")
    password = request.data.get("password")

    if not username or not password:
        return Response(
            {"error": "Username and password are required."},
            status=status.HTTP_400_BAD_REQUEST,
        )

    user = authenticate(
        request,
        username=username,
        password=password,
    )

    if user is None:
        return Response(
            {"error": "Invalid username or password."},
            status=status.HTTP_401_UNAUTHORIZED,
        )

    token, _ = Token.objects.get_or_create(user=user)

    return Response(
        {
            "token": token.key,
            "username": user.username,
        },
        status=status.HTTP_200_OK,
    )


@api_view(["GET"])
def job_list_view(request):
    jobs = Job.objects.filter(
        assigned_helper=request.user
    ).order_by("-created_at")

    serializer = JobSerializer(jobs, many=True)
    return Response(serializer.data)


@api_view(["GET"])
def job_detail_view(request, pk):
    job = get_object_or_404(
        Job,
        pk=pk,
        assigned_helper=request.user,
    )

    serializer = JobSerializer(job)
    return Response(serializer.data)


@api_view(["PATCH"])
def update_job_status_view(request, pk):
    job = get_object_or_404(
        Job,
        pk=pk,
        assigned_helper=request.user,
    )

    serializer = JobStatusSerializer(data=request.data)
    serializer.is_valid(raise_exception=True)

    new_status = serializer.validated_data["status"]

    allowed_transitions = {
        Job.Status.ASSIGNED: Job.Status.IN_PROGRESS,
        Job.Status.IN_PROGRESS: Job.Status.COMPLETED,
    }

    expected_status = allowed_transitions.get(job.status)

    if new_status != expected_status:
        return Response(
            {
                "error": (
                    f"Cannot change status from {job.status} "
                    f"to {new_status}."
                )
            },
            status=status.HTTP_400_BAD_REQUEST,
        )

    job.status = new_status
    job.save(update_fields=["status", "updated_at"])

    return Response(JobSerializer(job).data)
