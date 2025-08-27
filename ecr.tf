resource "aws_ecr_repository" "soci_repo" {
  name = "soci-repo"
}

output "ecr_repo_url" {
  value = aws_ecr_repository.soci_repo.repository_url
}

output "ecr_registry_url" {
  value = split("/", aws_ecr_repository.soci_repo.repository_url)[0]
}