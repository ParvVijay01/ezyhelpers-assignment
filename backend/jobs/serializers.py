from rest_framework import serializers
from .models import Job

class JobSerializer(serializers.ModelSerializer):
    assigned_helper = serializers.ReadOnlyField(source='assigned_helper.username')
    
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
        read_only_fields = ["id",
            "assigned_helper",
            "status",
            "created_at",
            "updated_at",
            ]

class JobStatusSerializer(serializers.Serializer):
    status = serializers.ChoiceField(
        choices=Job.Status.choices
    )