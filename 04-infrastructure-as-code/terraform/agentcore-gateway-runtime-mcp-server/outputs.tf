output "agent_runtime_id" {
  description = "ID of the created agent runtime"
  value       = aws_bedrockagentcore_agent_runtime.mcp_server.agent_runtime_id
}

output "agent_runtime_arn" {
  description = "ARN of the created agent runtime"
  value       = aws_bedrockagentcore_agent_runtime.mcp_server.agent_runtime_arn
}

output "agent_runtime_version" {
  description = "Version of the created agent runtime"
  value       = aws_bedrockagentcore_agent_runtime.mcp_server.agent_runtime_version
}

output "ecr_repository_url" {
  description = "URL of the ECR repository"
  value       = aws_ecr_repository.server_ecr.repository_url
}

output "ecr_repository_arn" {
  description = "ARN of the ECR repository"
  value       = aws_ecr_repository.server_ecr.arn
}

output "agent_execution_role_arn" {
  description = "ARN of the agent execution role"
  value       = aws_iam_role.agent_execution.arn
}

output "codebuild_project_name" {
  description = "Name of the CodeBuild project"
  value       = aws_codebuild_project.agent_image.name
}

output "codebuild_project_arn" {
  description = "ARN of the CodeBuild project"
  value       = aws_codebuild_project.agent_image.arn
}

output "source_bucket_name" {
  description = "S3 bucket containing agent source code"
  value       = aws_s3_bucket.agent_source.id
}

output "source_bucket_arn" {
  description = "ARN of the S3 bucket containing agent source code"
  value       = aws_s3_bucket.agent_source.arn
}

output "source_object_key" {
  description = "S3 object key for the agent source code archive"
  value       = aws_s3_object.agent_source.key
}

output "source_code_md5" {
  description = "MD5 hash of the agent source code (triggers rebuild when changed)"
  value       = data.archive_file.agent_source.output_md5
}

# ============================================================================
# Cognito Outputs (only when auth_provider = "cognito")
# ============================================================================

output "cognito_user_pool_id" {
  description = "ID of the Cognito User Pool"
  value       = var.auth_provider == "cognito" ? aws_cognito_user_pool.mcp_user_pool[0].id : null
}

output "cognito_user_pool_arn" {
  description = "ARN of the Cognito User Pool"
  value       = var.auth_provider == "cognito" ? aws_cognito_user_pool.mcp_user_pool[0].arn : null
}

output "cognito_user_pool_client_id" {
  description = "ID of the Cognito User Pool Client"
  value       = var.auth_provider == "cognito" ? aws_cognito_user_pool_client.mcp_client[0].id : null
}

output "cognito_discovery_url" {
  description = "Cognito OIDC Discovery URL"
  value       = var.auth_provider == "cognito" ? "https://cognito-idp.${data.aws_region.current.id}.amazonaws.com/${aws_cognito_user_pool.mcp_user_pool[0].id}/.well-known/openid-configuration" : null
}

output "test_username" {
  description = "Test username for authentication"
  value       = var.auth_provider == "cognito" ? "testuser" : null
}

output "test_password" {
  description = "Test password for authentication"
  value       = var.auth_provider == "cognito" ? "MyPassword123!" : null
  sensitive   = true
}

output "get_token_command" {
  description = "Command to get authentication token"
  value       = var.auth_provider == "cognito" ? "python get_token.py ${aws_cognito_user_pool_client.mcp_client[0].id} testuser MyPassword123! ${data.aws_region.current.id}" : "python get_entra_id_token.py ${var.entra_id_tenant_id} ${var.entra_id_client_id} <username> <password>"
}

# ============================================================================
# Entra ID Outputs (only when auth_provider = "entra_id")
# ============================================================================

output "entra_id_tenant_id" {
  description = "Entra ID Tenant ID"
  value       = var.auth_provider == "entra_id" ? var.entra_id_tenant_id : null
}

output "entra_id_client_id" {
  description = "Entra ID Client ID"
  value       = var.auth_provider == "entra_id" ? var.entra_id_client_id : null
}

output "entra_id_discovery_url" {
  description = "Entra ID OIDC Discovery URL"
  value       = var.auth_provider == "entra_id" ? "https://login.microsoftonline.com/${var.entra_id_tenant_id}/v2.0/.well-known/openid-configuration" : null
}

# ============================================================================
# Authentication Provider Output
# ============================================================================

output "auth_provider" {
  description = "Authentication provider being used"
  value       = var.auth_provider
}

# ============================================================================
# Gateway Outputs
# ============================================================================

output "runtime_endpoint_url" {
  description = "HTTPS endpoint URL for the AgentCore Runtime"
  value       = "https://bedrock-agentcore.${data.aws_region.current.id}.amazonaws.com/runtimes/${urlencode(aws_bedrockagentcore_agent_runtime.mcp_server.agent_runtime_arn)}/invocations"
}

output "runtime_endpoint_arn" {
  description = "ARN of the Runtime Endpoint"
  value       = aws_bedrockagentcore_agent_runtime_endpoint.mcp_server.agent_runtime_endpoint_arn
}

output "gateway_id" {
  description = "ID of the AgentCore Gateway"
  value       = aws_bedrockagentcore_gateway.mcp_server_gateway.gateway_id
}

output "gateway_arn" {
  description = "ARN of the AgentCore Gateway"
  value       = aws_bedrockagentcore_gateway.mcp_server_gateway.gateway_arn
}

output "gateway_url" {
  description = "URL of the AgentCore Gateway"
  value       = aws_bedrockagentcore_gateway.mcp_server_gateway.gateway_url
}

output "gateway_target_id" {
  description = "ID of the Gateway Target"
  value       = aws_bedrockagentcore_gateway_target.mcp_server_target.target_id
}

output "gateway_execution_role_arn" {
  description = "ARN of the gateway execution role"
  value       = aws_iam_role.gateway_execution.arn
}
