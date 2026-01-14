# ============================================================================
# Cognito User Pool for JWT Authentication
# ============================================================================
# Only created when auth_provider = "cognito"

resource "aws_cognito_user_pool" "mcp_user_pool" {
  count = var.auth_provider == "cognito" ? 1 : 0

  name = "${var.stack_name}-user-pool"

  password_policy {
    minimum_length    = 8
    require_uppercase = false
    require_lowercase = false
    require_numbers   = false
    require_symbols   = false
  }

  # Schema attributes cannot be modified after pool creation
  # Using lifecycle ignore_changes to prevent Terraform from attempting modifications
  lifecycle {
    ignore_changes = [schema]
  }

  tags = {
    Name      = "${var.stack_name}-user-pool"
    StackName = var.stack_name
    Module    = "Cognito"
  }
}

# ============================================================================
# Cognito User Pool Domain for OAuth Endpoints
# ============================================================================

resource "aws_cognito_user_pool_domain" "mcp_domain" {
  count = var.auth_provider == "cognito" ? 1 : 0

  domain       = "${var.stack_name}-${data.aws_caller_identity.current.account_id}"
  user_pool_id = aws_cognito_user_pool.mcp_user_pool[0].id
}

# ============================================================================
# Cognito User Pool Client
# ============================================================================

resource "aws_cognito_user_pool_client" "mcp_client" {
  count = var.auth_provider == "cognito" ? 1 : 0

  name         = "${var.stack_name}-client"
  user_pool_id = aws_cognito_user_pool.mcp_user_pool[0].id

  explicit_auth_flows = [
    "ALLOW_USER_PASSWORD_AUTH",
    "ALLOW_REFRESH_TOKEN_AUTH"
  ]

  generate_secret               = false
  prevent_user_existence_errors = "ENABLED"
}

# ============================================================================
# Cognito User Pool Client for Gateway (Machine-to-Machine)
# ============================================================================
# Separate client with client_credentials grant for Gateway-to-Runtime auth

resource "aws_cognito_user_pool_client" "gateway_client" {
  count = var.auth_provider == "cognito" ? 1 : 0

  name         = "${var.stack_name}-gateway-client"
  user_pool_id = aws_cognito_user_pool.mcp_user_pool[0].id

  # Client credentials flow for machine-to-machine authentication
  allowed_oauth_flows_user_pool_client = true
  allowed_oauth_flows                  = ["client_credentials"]
  allowed_oauth_scopes                 = aws_cognito_resource_server.mcp_api[0].scope_identifiers

  generate_secret               = true
  prevent_user_existence_errors = "ENABLED"
}

# ============================================================================
# Cognito Resource Server for OAuth Scopes
# ============================================================================

resource "aws_cognito_resource_server" "mcp_api" {
  count = var.auth_provider == "cognito" ? 1 : 0

  identifier   = "mcp-api"
  name         = "MCP API"
  user_pool_id = aws_cognito_user_pool.mcp_user_pool[0].id

  scope {
    scope_name        = "invoke"
    scope_description = "Invoke MCP server"
  }
}

# ============================================================================
# Test User
# ============================================================================

resource "aws_cognito_user" "test_user" {
  count = var.auth_provider == "cognito" ? 1 : 0

  user_pool_id = aws_cognito_user_pool.mcp_user_pool[0].id
  username     = "testuser"

  message_action = "SUPPRESS"
}

# ============================================================================
# Set Permanent Password for Test User
# ============================================================================

resource "null_resource" "set_cognito_password" {
  count = var.auth_provider == "cognito" ? 1 : 0

  triggers = {
    user_id = aws_cognito_user.test_user[0].id
  }

  provisioner "local-exec" {
    command = <<-EOT
      aws cognito-idp admin-set-user-password \
        --user-pool-id ${aws_cognito_user_pool.mcp_user_pool[0].id} \
        --username testuser \
        --password 'MyPassword123!' \
        --permanent \
        --region ${data.aws_region.current.id}
    EOT
  }

  depends_on = [
    aws_cognito_user.test_user
  ]
}
