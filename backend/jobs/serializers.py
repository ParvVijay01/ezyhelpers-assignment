from rest_framework import serializers

from .models import Job


class LoginSerializer(serializers.Serializer):
    username = serializers.CharField()
    password = serializers.CharField(trim_whitespace=False, write_only=True)


class JobSerializer(serializers.ModelSerializer):
    assigned_helper = serializers.ReadOnlyField(source="assigned_helper.username")

    class Meta:
        model = Job
        fields = [
            "id",
            "title",
            "description",
            "location",
            "scheduled_at",
            "assigned_helper",
            "status",
            "created_at",
            "updated_at",
        ]
        read_only_fields = fields


class JobStatusSerializer(serializers.Serializer):
    status = serializers.ChoiceField(choices=Job.Status.choices)
