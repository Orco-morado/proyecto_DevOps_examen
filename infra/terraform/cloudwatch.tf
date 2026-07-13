resource "aws_cloudwatch_log_group" "eks_apps" {
  name              = "/eks/${var.project_name}/applications"
  retention_in_days = 7

  tags = {
    Project = var.project_name
    Course  = "ISY1101"
  }
}
