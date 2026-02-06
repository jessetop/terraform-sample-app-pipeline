# dashboard.tf - CloudWatch Dashboard for Terraform Operations Monitoring
#
# This dashboard provides at-a-glance visibility into:
#   - CI/CD pipeline health (build duration, success/failure rates)
#   - Pipeline execution status (succeeded vs. failed)
#   - State backend operations (S3 reads/writes, DynamoDB lock activity)
#   - Quick links to key AWS console pages
#   - Audit query reference for the SOC team

resource "aws_cloudwatch_dashboard" "terraform_ops" {
  dashboard_name = "${var.student_id}-terraform-operations"

  dashboard_body = jsonencode({
    widgets = [

      # ========================================================================
      # ROW 0: Dashboard Title
      # ========================================================================
      {
        type   = "text"
        x      = 0
        y      = 0
        width  = 24
        height = 2
        properties = {
          markdown = <<-EOF
# Terraform Pipeline Operations Dashboard
**Student:** ${var.student_id} | **Account:** NovaTech AWS | **Region:** us-east-1

This dashboard provides operational visibility into Terraform CI/CD pipeline activity, state management operations, and deployment health. Use this for ongoing monitoring and SOC 2 audit evidence.
EOF
        }
      },

      # ========================================================================
      # ROW 1: CodeBuild Metrics
      # ========================================================================

      # Widget: Build Duration (all 5 projects)
      {
        type   = "metric"
        x      = 0
        y      = 2
        width  = 8
        height = 6
        properties = {
          title   = "CodeBuild Duration (seconds)"
          region  = "us-east-1"
          view    = "timeSeries"
          stacked = false
          period  = 300
          stat    = "Average"
          metrics = [
            ["AWS/CodeBuild", "Duration", "ProjectName", "${var.student_id}-terraform-validate", { label = "Validate" }],
            ["AWS/CodeBuild", "Duration", "ProjectName", "${var.student_id}-terraform-plan-staging", { label = "Plan Staging" }],
            ["AWS/CodeBuild", "Duration", "ProjectName", "${var.student_id}-terraform-apply-staging", { label = "Apply Staging" }],
            ["AWS/CodeBuild", "Duration", "ProjectName", "${var.student_id}-terraform-plan-prod", { label = "Plan Prod" }],
            ["AWS/CodeBuild", "Duration", "ProjectName", "${var.student_id}-terraform-apply-prod", { label = "Apply Prod" }]
          ]
        }
      },

      # Widget: Build Success vs Failure (staging and prod apply projects)
      {
        type   = "metric"
        x      = 8
        y      = 2
        width  = 8
        height = 6
        properties = {
          title   = "Build Success vs Failure"
          region  = "us-east-1"
          view    = "timeSeries"
          stacked = false
          period  = 3600
          stat    = "Sum"
          metrics = [
            ["AWS/CodeBuild", "SucceededBuilds", "ProjectName", "${var.student_id}-terraform-apply-staging", { label = "Staging Succeeded", color = "#2ca02c" }],
            ["AWS/CodeBuild", "FailedBuilds", "ProjectName", "${var.student_id}-terraform-apply-staging", { label = "Staging Failed", color = "#d62728" }],
            ["AWS/CodeBuild", "SucceededBuilds", "ProjectName", "${var.student_id}-terraform-apply-prod", { label = "Prod Succeeded", color = "#1f77b4" }],
            ["AWS/CodeBuild", "FailedBuilds", "ProjectName", "${var.student_id}-terraform-apply-prod", { label = "Prod Failed", color = "#ff7f0e" }]
          ]
        }
      },

      # Widget: Pipeline Execution Counts (single value)
      {
        type   = "metric"
        x      = 16
        y      = 2
        width  = 4
        height = 3
        properties = {
          title   = "Pipeline Succeeded"
          region  = "us-east-1"
          view    = "singleValue"
          period  = 86400
          stat    = "Sum"
          metrics = [
            ["AWS/CodePipeline", "PipelineExecutionSucceeded", "PipelineName", "${var.student_id}-terraform-pipeline", { label = "Succeeded", color = "#2ca02c" }]
          ]
        }
      },
      {
        type   = "metric"
        x      = 20
        y      = 2
        width  = 4
        height = 3
        properties = {
          title   = "Pipeline Failed"
          region  = "us-east-1"
          view    = "singleValue"
          period  = 86400
          stat    = "Sum"
          metrics = [
            ["AWS/CodePipeline", "PipelineExecutionFailed", "PipelineName", "${var.student_id}-terraform-pipeline", { label = "Failed", color = "#d62728" }]
          ]
        }
      },

      # Widget: Pipeline Execution Time Series
      {
        type   = "metric"
        x      = 16
        y      = 5
        width  = 8
        height = 3
        properties = {
          title   = "Pipeline Executions Over Time"
          region  = "us-east-1"
          view    = "timeSeries"
          stacked = true
          period  = 3600
          stat    = "Sum"
          metrics = [
            ["AWS/CodePipeline", "PipelineExecutionSucceeded", "PipelineName", "${var.student_id}-terraform-pipeline", { label = "Succeeded", color = "#2ca02c" }],
            ["AWS/CodePipeline", "PipelineExecutionFailed", "PipelineName", "${var.student_id}-terraform-pipeline", { label = "Failed", color = "#d62728" }]
          ]
        }
      },

      # ========================================================================
      # ROW 2: State & Infrastructure Operations
      # ========================================================================

      # Section Header
      {
        type   = "text"
        x      = 0
        y      = 8
        width  = 24
        height = 1
        properties = {
          markdown = "## State & Infrastructure Operations"
        }
      },

      # Widget: S3 State Bucket Operations
      {
        type   = "metric"
        x      = 0
        y      = 9
        width  = 12
        height = 6
        properties = {
          title   = "State Bucket Operations (S3)"
          region  = "us-east-1"
          view    = "timeSeries"
          stacked = false
          period  = 300
          stat    = "Sum"
          metrics = [
            ["AWS/S3", "GetRequests", "BucketName", "${var.student_id}-terraform-state", "FilterId", "EntireBucket", { label = "Get Requests (Read State)", color = "#1f77b4" }],
            ["AWS/S3", "PutRequests", "BucketName", "${var.student_id}-terraform-state", "FilterId", "EntireBucket", { label = "Put Requests (Write State)", color = "#ff7f0e" }]
          ]
        }
      },

      # Widget: DynamoDB Lock Operations
      {
        type   = "metric"
        x      = 12
        y      = 9
        width  = 12
        height = 6
        properties = {
          title   = "State Lock Operations (DynamoDB)"
          region  = "us-east-1"
          view    = "timeSeries"
          stacked = false
          period  = 300
          stat    = "Sum"
          metrics = [
            ["AWS/DynamoDB", "ConsumedReadCapacityUnits", "TableName", "${var.student_id}-terraform-lock", { label = "Lock Reads (Check/Acquire)", color = "#2ca02c" }],
            ["AWS/DynamoDB", "ConsumedWriteCapacityUnits", "TableName", "${var.student_id}-terraform-lock", { label = "Lock Writes (Acquire/Release)", color = "#9467bd" }]
          ]
        }
      },

      # ========================================================================
      # ROW 3: Quick Links & Audit Reference
      # ========================================================================

      # Section Header
      {
        type   = "text"
        x      = 0
        y      = 15
        width  = 24
        height = 1
        properties = {
          markdown = "## Quick Links & Audit Reference"
        }
      },

      # Widget: Quick Links Panel
      {
        type   = "text"
        x      = 0
        y      = 16
        width  = 12
        height = 5
        properties = {
          markdown = <<-EOF
### Console Quick Links

| Resource | Link |
|----------|------|
| **CodePipeline** | [View Pipeline](https://console.aws.amazon.com/codesuite/codepipeline/pipelines/${var.student_id}-terraform-pipeline/view?region=us-east-1) |
| **CodeBuild** | [Build Projects](https://console.aws.amazon.com/codesuite/codebuild/projects?region=us-east-1) |
| **CloudTrail** | [Event History](https://console.aws.amazon.com/cloudtrail/home?region=us-east-1#/events) |
| **S3 State Bucket** | [View Bucket](https://console.aws.amazon.com/s3/buckets/${var.student_id}-terraform-state?region=us-east-1) |
| **DynamoDB Lock Table** | [View Table](https://console.aws.amazon.com/dynamodbv2/home?region=us-east-1#table?name=${var.student_id}-terraform-lock) |
| **CloudWatch Logs Insights** | [Run Queries](https://console.aws.amazon.com/cloudwatch/home?region=us-east-1#logsV2:logs-insights) |
EOF
        }
      },

      # Widget: Audit Query Reference Panel
      {
        type   = "text"
        x      = 12
        y      = 16
        width  = 12
        height = 5
        properties = {
          markdown = <<-EOF
### CloudTrail Audit Queries (Log Insights)

**All Terraform Activity:**
```
fields @timestamp, eventName, userIdentity.arn
| filter userAgent like /Terraform/
| sort @timestamp desc | limit 50
```

**SSM Parameter Changes by Student:**
```
fields @timestamp, eventName, requestParameters.name
| filter eventSource = "ssm.amazonaws.com"
| filter requestParameters.name like /studentXX/
| sort @timestamp desc | limit 20
```

**Pipeline vs Manual Activity:**
```
fields @timestamp, eventName, sourceIPAddress
| filter userAgent like /Terraform/
| filter sourceIPAddress = "codebuild.amazonaws.com"
| sort @timestamp desc | limit 50
```

*In CloudTrail Event History, filter by:*
- **User name:** `${var.student_id}-codebuild-terraform-role`
- **Event source:** `ssm.amazonaws.com`, `ec2.amazonaws.com`
EOF
        }
      }
    ]
  })
}

# ============================================================================
# Outputs
# ============================================================================

output "dashboard_url" {
  description = "URL to the CloudWatch dashboard in the AWS Console"
  value       = "https://console.aws.amazon.com/cloudwatch/home?region=us-east-1#dashboards:name=${var.student_id}-terraform-operations"
}

output "dashboard_name" {
  description = "Name of the deployed CloudWatch dashboard"
  value       = aws_cloudwatch_dashboard.terraform_ops.dashboard_name
}
