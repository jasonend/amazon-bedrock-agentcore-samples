# ============================================================================
# Runtime Endpoint - Provides HTTPS endpoint for the Runtime
# ============================================================================

resource "aws_bedrockagentcore_agent_runtime_endpoint" "mcp_server" {
  name                  = replace("${var.stack_name}_endpoint", "-", "_")
  description           = "HTTPS endpoint for MCP server runtime"
  agent_runtime_id      = aws_bedrockagentcore_agent_runtime.mcp_server.agent_runtime_id
  agent_runtime_version = aws_bedrockagentcore_agent_runtime.mcp_server.agent_runtime_version

  depends_on = [
    aws_bedrockagentcore_agent_runtime.mcp_server
  ]
}

# ============================================================================
# AgentCore Gateway - Exposes MCP Server Runtime as MCP Tools
# ============================================================================

resource "aws_bedrockagentcore_gateway" "mcp_server_gateway" {
  name            = replace("${var.stack_name}_gateway", "_", "-")
  description     = "Gateway exposing MCP server tools (add_numbers, multiply_numbers, greet_user)"
  role_arn        = aws_iam_role.gateway_execution.arn
  protocol_type   = "MCP"
  authorizer_type = "CUSTOM_JWT"

  # JWT Authorization - Dynamic based on auth_provider
  authorizer_configuration {
    custom_jwt_authorizer {
      allowed_clients = var.auth_provider == "cognito" ? [aws_cognito_user_pool_client.mcp_client[0].id] : [var.entra_id_client_id]
      discovery_url   = var.auth_provider == "cognito" ? "https://cognito-idp.${data.aws_region.current.id}.amazonaws.com/${aws_cognito_user_pool.mcp_user_pool[0].id}/.well-known/openid-configuration" : "https://login.microsoftonline.com/${var.entra_id_tenant_id}/v2.0/.well-known/openid-configuration"
    }
  }

  depends_on = [
    aws_iam_role_policy.gateway_execution
  ]
}

# ============================================================================
# OAuth2 Credential Provider for Gateway-to-Runtime Authentication
# ============================================================================
# The Gateway uses OAuth2 client credentials to authenticate with the Runtime
# This enables machine-to-machine authentication between Gateway and Runtime

# Store Cognito client secret in Secrets Manager
resource "aws_secretsmanager_secret" "gateway_client_secret" {
  count = var.auth_provider == "cognito" ? 1 : 0

  name_prefix = "${var.stack_name}-gateway-client-secret-"
  description = "OAuth2 client secret for Gateway-to-Runtime authentication"

  tags = {
    Name   = "${var.stack_name}-gateway-client-secret"
    Module = "Gateway"
  }
}

resource "aws_secretsmanager_secret_version" "gateway_client_secret" {
  count = var.auth_provider == "cognito" ? 1 : 0

  secret_id = aws_secretsmanager_secret.gateway_client_secret[0].id
  secret_string = jsonencode({
    client_id     = aws_cognito_user_pool_client.gateway_client[0].id
    client_secret = aws_cognito_user_pool_client.gateway_client[0].client_secret
  })
}

resource "aws_bedrockagentcore_oauth2_credential_provider" "gateway_to_runtime" {
  name                       = replace("${var.stack_name}_oauth_provider", "_", "-")
  credential_provider_vendor = "CustomOauth2"

  oauth2_provider_config {
    custom_oauth2_provider_config {
      # Client credentials stored securely (write-only)
      # For Cognito: uses dedicated gateway client with client_credentials grant
      # For Entra ID: uses the configured client
      client_id_wo                  = var.auth_provider == "cognito" ? aws_cognito_user_pool_client.gateway_client[0].id : var.entra_id_client_id
      client_secret_wo              = var.auth_provider == "cognito" ? aws_cognito_user_pool_client.gateway_client[0].client_secret : ""
      client_credentials_wo_version = 1 # Version number for credential rotation

      # OAuth discovery configuration
      oauth_discovery {
        discovery_url = var.auth_provider == "cognito" ? "https://cognito-idp.${data.aws_region.current.id}.amazonaws.com/${aws_cognito_user_pool.mcp_user_pool[0].id}/.well-known/openid-configuration" : "https://login.microsoftonline.com/${var.entra_id_tenant_id}/v2.0/.well-known/openid-configuration"
      }
    }
  }

  depends_on = [
    aws_cognito_user_pool_client.mcp_client,
    aws_bedrockagentcore_gateway.mcp_server_gateway
  ]
}

# ============================================================================
# Gateway Target - Connects Gateway to AgentCore Runtime
# ============================================================================

resource "aws_bedrockagentcore_gateway_target" "mcp_server_target" {
  name               = replace("${var.stack_name}_runtime_target_v5", "_", "-")
  description        = "Target connecting gateway to MCP server runtime"
  gateway_identifier = aws_bedrockagentcore_gateway.mcp_server_gateway.gateway_id

  # Target configuration - MCP Server endpoint
  # Uses the Runtime ARN (URL-encoded) in the endpoint path
  # Format: https://bedrock-agentcore.{region}.amazonaws.com/runtimes/{EncodedAgentARN}/invocations
  target_configuration {
    mcp {
      mcp_server {
        endpoint = "https://bedrock-agentcore.${data.aws_region.current.id}.amazonaws.com/runtimes/${urlencode(aws_bedrockagentcore_agent_runtime.mcp_server.agent_runtime_arn)}/invocations"
      }
    }
  }

  # Gateway uses OAuth2 to authenticate with the runtime
  # References the OAuth2 credential provider configured above
  credential_provider_configuration {
    oauth {
      provider_arn = aws_bedrockagentcore_oauth2_credential_provider.gateway_to_runtime.credential_provider_arn
      scopes       = [] # No specific scopes required for AgentCore Runtime
    }
  }

  depends_on = [
    aws_bedrockagentcore_gateway.mcp_server_gateway,
    aws_bedrockagentcore_agent_runtime_endpoint.mcp_server,
    aws_bedrockagentcore_oauth2_credential_provider.gateway_to_runtime
  ]
}
