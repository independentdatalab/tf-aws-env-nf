// This Role is used by Batch to access other services
resource "aws_iam_role" "ecs_instance_role" {
  name = "ecs_instance_role"
  assume_role_policy = templatefile("${path.module}/aws_policies/ecs_instance_role.json", {})
}

resource "aws_iam_instance_profile" "ecs_instance_profile" {
  name = "ecs_instance_role"
  role = aws_iam_role.ecs_instance_role.name
}

// Policies attached to the role (e.g. similar to a group but for services).
// (to have access to ECS, EC2 and S3)
resource "aws_iam_role_policy_attachment" "ecs_instance_role_ecs" {
  role       = aws_iam_role.ecs_instance_role.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonEC2ContainerServiceforEC2Role"
}
resource "aws_iam_role_policy_attachment" "ecs_instance_role_ec2_full" {
  role       = aws_iam_role.ecs_instance_role.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonEC2FullAccess"
}
resource "aws_iam_role_policy_attachment" "ecs_instance_role_s3_full" {
  role       = aws_iam_role.ecs_instance_role.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonS3FullAccess"
}


resource "aws_iam_role" "aws_batch_service_role" {
  name = "aws_batch_service_role"
  assume_role_policy = templatefile("${path.module}/aws_policies/batch_service_role.json", {})
}

resource "aws_iam_role_policy_attachment" "aws_batch_service_role" {
  role       = aws_iam_role.aws_batch_service_role.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSBatchServiceRole"
}

