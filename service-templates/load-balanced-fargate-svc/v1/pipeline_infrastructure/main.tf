resource "aws_ecr_repository" "ecr_repo" {
  name = "ECRRepo"
}

resource "aws_ecr_repository_policy" "ecr_repo_policy" {
  repository = aws_ecr_repository.ecr_repo.name
  policy     = local.environment_account_ids != 0 ? data.aws_iam_policy_document.pull_only_policy.json : null
}

resource "aws_codebuild_project" "build_project" {
  name         = "build_project"
  service_role = aws_iam_role.publish_role.arn

  artifacts {
    type = "CODEPIPELINE"
  }

  environment {
    compute_type                = "BUILD_GENERAL1_SMALL"
    privileged_mode             = true
    image                       = "aws/codebuild/amazonlinux2-x86_64-standard:3.0"
    type                        = "LINUX_CONTAINER"
    image_pull_credentials_type = "CODEBUILD"

    environment_variable {
      name  = "repo_name"
      type  = "PLAINTEXT"
      value = aws_ecr_repository.ecr_repo.name
    }

    environment_variable {
      name  = "service_name"
      type  = "PLAINTEXT"
      value = var.service.name
    }
  }

  source {
    buildspec = <<EOF
                {
                  "version": "0.2",
                  "phases": {
                    "install": {
                      "runtime-versions": {
                        "docker": 18
                      },
                      "commands": [
                        "pip3 install --upgrade --user awscli",
                        "echo 'f6bd1536a743ab170b35c94ed4c7c4479763356bd543af5d391122f4af852460  yq_linux_amd64' > yq_linux_amd64.sha",
                        "wget https://github.com/mikefarah/yq/releases/download/3.4.0/yq_linux_amd64",
                        "sha256sum -c yq_linux_amd64.sha",
                        "mv yq_linux_amd64 /usr/bin/yq",
                        "chmod +x /usr/bin/yq"
                      ]
                    },
                    "pre_build": {
                      "commands": [
                        "cd $CODEBUILD_SRC_DIR/${var.pipeline.inputs.service_dir}",
                        "$(aws ecr get-login --no-include-email --region $AWS_DEFAULT_REGION)",
                        "${var.pipeline.inputs.unit_test_command}",
                      ]
                    },
                    "build": {
                      "commands": [
                        "IMAGE_REPO_NAME=$repo_name",
                        "IMAGE_TAG=$CODEBUILD_BUILD_NUMBER",
                        "IMAGE_ID="${local.account_id}
                .dkr.ecr.$AWS_DEFAULT_REGION.amazonaws.com/$IMAGE_REPO_NAME:$IMAGE_TAG",
                        "docker build -t $IMAGE_REPO_NAME:$IMAGE_TAG -f ${var.pipeline.inputs.dockerfile} .",
                        "docker tag $IMAGE_REPO_NAME:$IMAGE_TAG $IMAGE_ID;",
                        "docker push $IMAGE_ID"
                      ]
                    },
                    "post_build": {
                      "commands": [
                        "aws proton --region $AWS_DEFAULT_REGION get-service --name $service_name | jq -r .service.spec > service.yaml",
                        "yq w service.yaml 'instances[*].spec.image' \"$IMAGE_ID\" > rendered_service.yaml"
                      ]
                    }
                  },
                  "artifacts": {
                    "files": [
                      "${var.pipeline.inputs.service_dir}/rendered_service.yaml"
                    ]
                  }
                }
              }
EOF

    type = "CODEPIPELINE"

  }
  source_version = "master"
  encryption_key = aws_kms_key.pipeline_artifacts_bucket_encryption_key.arn
}

resource "aws_codebuild_project" "deploy_project" {
  for_each = { for instance in var.service_instances : instance.name => instance }

  name         = "Deploy${index(var.service_instances, each.value)}Project"
  service_role = aws_iam_role.deployment_role.arn

  artifacts {
    type = "CODEPIPELINE"
  }

  environment {
    compute_type                = "BUILD_GENERAL1_SMALL"
    image                       = "aws/codebuild/amazonlinux2-x86_64-standard:3.0"
    type                        = "LINUX_CONTAINER"
    privileged_mode             = false
    image_pull_credentials_type = "CODEBUILD"

    environment_variable {
      name  = "service_instance_name"
      value = each.key
    }

    environment_variable {
      name  = "service_name"
      value = var.service.name
    }
  }

  source {
    type      = "CODEPIPELINE"
    buildspec = <<EOF
          {
            "version": "0.2",
            "phases": {
              "build": {
                "commands": [
                  "pip3 install --upgrade --user awscli",
                  "aws proton --region $AWS_DEFAULT_REGION update-service-instance --deployment-type CURRENT_VERSION --name $service_instance_name --service-name $service_name --spec file://${var.pipeline.inputs.service_dir}/rendered_service.yaml",
                  "aws proton --region $AWS_DEFAULT_REGION wait service-instance-deployed --name $service_instance_name --service-name $service_name"
                ]
              }
            }
          }
EOF
  }

  encryption_key = aws_kms_key.pipeline_artifacts_bucket_encryption_key.arn
}

resource "aws_iam_role" "publish_role" {
  name_prefix = "publish_role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = "sts:AssumeRole"
        Principal = {
          Service = "codebuild.amazonaws.com"
        }
      }
    ]
  })
}

resource "aws_iam_policy" "publish_role_default_policy" {
  policy = data.aws_iam_policy_document.publish_role_default_policy.json
}

resource "aws_iam_role_policy_attachment" "publish_role_policy_attachment" {
  policy_arn = aws_iam_policy.publish_role_default_policy.arn
  role       = aws_iam_role.publish_role.name
}

resource "aws_iam_role" "deployment_role" {
  name_prefix = "deploy_role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = "sts:AssumeRole"
        Principal = {
          Service = "codebuild.amazonaws.com"
        }
      }
    ]
  })
}

resource "aws_iam_policy" "deployment_role_default_policy" {
  policy = data.aws_iam_policy_document.deployment_role_default_policy.json
}

resource "aws_iam_role_policy_attachment" "deployment_role_policy_attachment" {
  policy_arn = aws_iam_policy.deployment_role_default_policy.arn
  role       = aws_iam_role.deployment_role.name
}

resource "aws_iam_role" "pipeline_role" {
  name_prefix = "deploy_role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = "sts:AssumeRole"
        Principal = {
          Service = "codebuild.amazonaws.com"
        }
      }
    ]
  })
}

resource "aws_iam_policy" "pipeline_role_default_policy" {
  policy = data.aws_iam_policy_document.pipeline_role_default_policy.json
}

resource "aws_iam_role_policy_attachment" "pipeline_role_policy_attachment" {
  policy_arn = aws_iam_policy.pipeline_role_default_policy.arn
  role       = aws_iam_role.pipeline_role.name
}

resource "aws_iam_role" "pipeline_build_codepipeline_action_role" {
  name_prefix = "pipeline-build-action-role"

  assume_role_policy = jsonencode({
    "Version" : "2012-10-17",
    "Statement" : [
      {
        "Action" : "sts:AssumeRole"
        "Effect" : "Allow",
        "Principal" : {
          "AWS" : "arn:aws:iam::${local.account_id}:root"
        },
      }
    ]
  })
}

resource "aws_iam_policy" "pipeline_build_action_role_policy" {
  policy = data.aws_iam_policy_document.pipeline_build_codepipeline_action_role_policy.json
}

resource "aws_iam_role_policy_attachment" "pipeline_build_codepipeline_action_role_attachment" {
  policy_arn = aws_iam_policy.pipeline_build_action_role_policy.arn
  role       = aws_iam_role.pipeline_build_codepipeline_action_role.name
}

resource "aws_iam_role" "pipeline_deploy_codepipeline_action_role" {
  name_prefix = "pipeline-deploy-action-role"

  assume_role_policy = jsonencode({
    "Version" : "2012-10-17",
    "Statement" : [
      {
        "Action" : "sts:AssumeRole"
        "Effect" : "Allow",
        "Principal" : {
          "AWS" : "arn:aws:iam::${local.account_id}:root"
        },
      }
    ]
  })
}

resource "aws_iam_policy" "pipeline_deploy_action_role_policy" {
  policy = data.aws_iam_policy_document.pipeline_deploy_codepipeline_action_role_policy.json
}

resource "aws_iam_role_policy_attachment" "pipeline_deploy_codepipeline_action_role_attachment" {
  policy_arn = aws_iam_policy.pipeline_deploy_action_role_policy.arn
  role       = aws_iam_role.pipeline_deploy_codepipeline_action_role.name
}

resource "aws_s3_bucket" "pipeline_artifacts_bucket" {
  bucket_prefix = "pipeline-artifacts-bucket"
}

resource "aws_s3_bucket_versioning" "pipeline_artifacts_bucket_versioning" {
  bucket = aws_s3_bucket.pipeline_artifacts_bucket.id
  versioning_configuration {
    status = "Enabled"
  }
}

resource "aws_s3_bucket_server_side_encryption_configuration" "pipeline_artifacts_bucket_encryption" {
  bucket = aws_s3_bucket.pipeline_artifacts_bucket.id

  rule {
    apply_server_side_encryption_by_default {
      kms_master_key_id = aws_kms_key.pipeline_artifacts_bucket_encryption_key.arn
      sse_algorithm     = "aws:kms"
    }
  }
}

resource "aws_s3_bucket_public_access_block" "pipeline_artifacts_bucket_access_block" {
  bucket                  = aws_s3_bucket.pipeline_artifacts_bucket.id
  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

resource "aws_kms_key" "pipeline_artifacts_bucket_encryption_key" {
  policy = data.aws_iam_policy_document.pipeline_artifacts_bucket_key_policy.json
}

resource "aws_kms_alias" "pipeline_artifacts_bucket_key_alias" {
  target_key_id = aws_kms_key.pipeline_artifacts_bucket_encryption_key.id
  name          = "alias/codepipeline-encryption-key-${var.service.name}"
}

resource "aws_codepipeline" "pipeline" {
  name     = "${var.service.name}-pipeline"
  role_arn = aws_iam_role.pipeline_role.arn

  stage {
    name = "Source"
    action {
      category  = "Source"
      name      = "Checkout"
      owner     = "AWS"
      provider  = "CodeStarSourceConnection"
      version   = "1"
      run_order = 1

      configuration = {
        ConnectionArn : var.service.repository_connection_arn
        FullRepositoryId : var.service.repository_id
        BranchName : var.service.branch_name
      }
      output_artifacts = ["Artifact_Source_Checkout"]
    }
  }

  stage {
    name = "Build"
    action {
      category  = "Build"
      name      = "Build"
      owner     = "AWS"
      provider  = "CodeBuild"
      version   = "1"
      run_order = 1

      configuration = {
        ProjectName = aws_codebuild_project.build_project.name
      }
      input_artifacts  = ["Artifact_Source_Checkout"]
      output_artifacts = ["BuildOutput"]
      role_arn         = aws_iam_role.pipeline_build_codepipeline_action_role.arn
    }
  }

  dynamic "stage" {
    for_each = toset(var.service_instances)

    content {
      name = "Deploy${index(var.service_instances, stage.value)}Project"

      action {
        category  = "Build"
        name      = "Deploy${index(var.service_instances, stage.value)}"
        owner     = "AWS"
        provider  = "CodeBuild"
        version   = "1"
        run_order = 1

        configuration = {
          ProjectName = "Deploy${index(var.service_instances, stage.value)}Project"
        }
        input_artifacts = ["BuildOutput"]
        role_arn        = aws_iam_role.pipeline_deploy_codepipeline_action_role.arn
      }
    }
  }

  artifact_store {
    encryption_key {
      id   = aws_kms_key.pipeline_artifacts_bucket_encryption_key.arn
      type = "KMS"
    }
    location = aws_s3_bucket.pipeline_artifacts_bucket.bucket
    type     = "S3"
  }
}
