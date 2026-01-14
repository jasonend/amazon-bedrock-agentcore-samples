# ============================================================================
# AgentCore Runtime - Main Agent Runtime Resource
# ============================================================================

# Random suffix to ensure unique runtime name
resource "random_id" "runtime_suffix" {
  byte_length = 4
}

resource "aws_bedrockagentcore_agent_runtime" "mcp_server" {
  agent_runtime_name = replace("${var.stack_name}_${var.agent_name}_${random_id.runtime_suffix.hex}", "-", "_")
  description        = var.description
  role_arn           = aws_iam_role.agent_execution.arn

  agent_runtime_artifact {
    container_configuration {
      container_uri = "${aws_ecr_repository.server_ecr.repository_url}:${var.image_tag}"
    }
  }

  network_configuration {
    network_mode = var.network_mode
  }

  # MCP Protocol Configuration
  protocol_configuration {
    server_protocol = "MCP"
  }

  # JWT Authorization - Dynamic based on auth_provider
  # Accepts tokens from both user client and gateway client
  authorizer_configuration {
    custom_jwt_authorizer {
      allowed_clients = var.auth_provider == "cognito" ? [
        aws_cognito_user_pool_client.mcp_client[0].id,
        aws_cognito_user_pool_client.gateway_client[0].id
      ] : [var.entra_id_client_id]
      discovery_url = var.auth_provider == "cognito" ? "https://cognito-idp.${data.aws_region.current.id}.amazonaws.com/${aws_cognito_user_pool.mcp_user_pool[0].id}/.well-known/openid-configuration" : "https://login.microsoftonline.com/${var.entra_id_tenant_id}/v2.0/.well-known/openid-configuration"
    }
  }

  environment_variables = merge(
    {
      AWS_REGION         = var.aws_region
      AWS_DEFAULT_REGION = var.aws_region
    },
    var.environment_variables
  )

  depends_on = [
    null_resource.trigger_build,
    aws_iam_role_policy.agent_execution,
    aws_iam_role_policy_attachment.agent_execution_managed
  ]
}
