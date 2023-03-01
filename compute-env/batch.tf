// Define a compute environment and job queue. A compute environment
// is a way to reference your compute resources (EC2 instances). The settings
// and constraints tell Batch how provisioned instances should be configured
// and launched.

resource "aws_default_subnet" "default" {
  availability_zone = "eu-central-1a"
}

resource "aws_security_group" "bioinfo_general" {
  name = "bioinfo_general"
   egress {
    from_port = 0
    to_port = 0
    protocol = "-1"
    cidr_blocks = [
      "0.0.0.0/0",
    ]
  }
}

/*
// UNCOMMENT AFTER THE INSTANCE IN ami.tf CREATED
resource "aws_batch_compute_environment" "bioinfo_general" {
  compute_environment_name = "bioinfo_general"

  compute_resources {
    image_id = aws_ami_from_instance.base_batch_nf_ami.id 
    instance_role = aws_iam_instance_profile.ecs_instance_profile.arn
    instance_type = [
      "m5.2xlarge",
    ]

    max_vcpus = 1024
    min_vcpus = 0
    desired_vcpus = 16
    
    security_group_ids = [
      aws_security_group.bioinfo_general.id,
    ]
    subnets = [
      aws_default_subnet.default.id,
    ]

    #type = "SPOT"
    type = "EC2"

    
    tags = {
      Name = "bioinfo-general-compute-env"
    }
  }
  service_role = aws_iam_role.aws_batch_service_role.arn
  type         = "MANAGED"
  depends_on   = [ aws_iam_role_policy_attachment.aws_batch_service_role ]
}

resource "aws_batch_job_queue" "high_priority" {
  name = "high_priority"
  state = "ENABLED"
  priority = "1000"
  compute_environments = [
    aws_batch_compute_environment.bioinfo_general.arn,
  ]
}

resource "aws_batch_job_queue" "low_priority" {
  name = "low_priority"
  state = "ENABLED"
  priority = "1"
  compute_environments = [
    aws_batch_compute_environment.bioinfo_general.arn,
  ]
}

// UNCOMMENT AFTER THE INSTANCE IN ami.tf CREATED
*/
