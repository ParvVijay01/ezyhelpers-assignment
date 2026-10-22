from django.core.management.base import BaseCommand
from django.contrib.auth.models import User
from django.utils import timezone
from datetime import timedelta
from jobs.models import Job

class Command(BaseCommand):
    help = "Seed the database with demo helpers and sample jobs"

    def handle(self, *args, **options):
        self.stdout.write("Seeding demo data...")

        # Create or update demo helpers
        helper1, created1 = User.objects.get_or_create(username="helper1")
        helper1.set_password("DemoPass123!")
        helper1.first_name = "Alex"
        helper1.last_name = "Helper"
        helper1.email = "helper1@example.com"
        helper1.save()

        helper2, created2 = User.objects.get_or_create(username="helper2")
        helper2.set_password("DemoPass123!")
        helper2.first_name = "Sam"
        helper2.last_name = "Partner"
        helper2.email = "helper2@example.com"
        helper2.save()

        self.stdout.write(self.style.SUCCESS("Created/updated demo users: helper1, helper2 (Password: DemoPass123!)"))

        # Clear existing demo jobs if needed or add demo jobs
        now = timezone.now()
        sample_jobs = [
            {
                "title": "Kitchen Plumbing Repair",
                "description": "Fix leaking pipe under the kitchen sink and inspect drain pressure.",
                "location": "742 Evergreen Terrace, Springfield",
                "scheduled_at": now + timedelta(hours=2),
                "status": Job.Status.ASSIGNED,
                "assigned_helper": helper1,
            },
            {
                "title": "Deep House Cleaning",
                "description": "Living room, 2 bedrooms, and kitchen dusting, vacuuming, and mopping.",
                "location": "124 Conch Street, Bikini Bottom",
                "scheduled_at": now - timedelta(hours=1),
                "status": Job.Status.IN_PROGRESS,
                "assigned_helper": helper1,
            },
            {
                "title": "AC Maintenance & Filter Replacement",
                "description": "Clean air filters and check refrigerant pressure for 2 split AC units.",
                "location": "221B Baker Street, London",
                "scheduled_at": now + timedelta(days=1),
                "status": Job.Status.ASSIGNED,
                "assigned_helper": helper1,
            },
            {
                "title": "Home Cleaning & Sanitzation",
                "description": "Post-renovation sanitization and floor scrubbing.",
                "location": "4 Privet Drive, Little Whinging",
                "scheduled_at": now - timedelta(days=1),
                "status": Job.Status.COMPLETED,
                "assigned_helper": helper1,
            },
            {
                "title": "Bathroom Deep Cleaning",
                "description": "Scrub tiles, clean shower enclosure, and descale taps.",
                "location": "31 Spooner Street, Quahog",
                "scheduled_at": now + timedelta(hours=4),
                "status": Job.Status.ASSIGNED,
                "assigned_helper": helper2,
            },
            {
                "title": "Furniture Assembly",
                "description": "Assemble 1 king-size wooden bed frame and 2 nightstands.",
                "location": "1042 Ocean Ave, Santa Monica",
                "scheduled_at": now - timedelta(hours=3),
                "status": Job.Status.IN_PROGRESS,
                "assigned_helper": helper2,
            },
            {
                "title": "Electrical Inspection",
                "description": "Check tripped MCB breaker switch in main electrical distribution board.",
                "location": "740 Park Ave, New York",
                "scheduled_at": now - timedelta(days=2),
                "status": Job.Status.COMPLETED,
                "assigned_helper": helper2,
            },
        ]

        for item in sample_jobs:
            job, created = Job.objects.get_or_create(
                title=item["title"],
                assigned_helper=item["assigned_helper"],
                defaults=item,
            )
            if not created:
                for key, val in item.items():
                    setattr(job, key, val)
                job.save()

        self.stdout.write(self.style.SUCCESS(f"Successfully seeded {len(sample_jobs)} demo jobs across helper1 and helper2."))
