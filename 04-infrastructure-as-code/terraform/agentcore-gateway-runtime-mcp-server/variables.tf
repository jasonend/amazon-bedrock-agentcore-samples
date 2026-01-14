variable "agent_name" {
  description = "Name for the agent runtime"
  type        = string
  default     = "MCPServerAgent"

  validation {
    condition     = can(regex("^[a-zA-Z][a-zA-Z0-9_]{0,47}$", var.agent_name))
    error_message = "Agent name must start with a letter, max 48 characters, alphanumeric and underscores only."
  }
}

variable "network_mode" {
  description = "Network mode for AgentCore resources"
  type        = string
  default     = "PUBLIC"

  validation {
    condition     = contains(["PUBLIC", "PRIVATE"], var.network_mode)
    error_message = "Network mode must be either PUBLIC or PRIVATE."
  }
}

variable "image_tag" {
  description = "Docker image tag"
  type        = string
  default     = "latest"
}

variable "aws_region" {
  description = "AWS region for deployment (REQUIRED)"
  type        = string
  # No default - must be explicitly provided

  validation {
    condition     = can(regex("^[a-z]{2}-[a-z]+-\\d{1}$", var.aws_region))
    error_message = "Must be a valid AWS region (e.g., us-east-1, eu-west-1)"
  }
}

variable "environment" {
  description = "Environment name"
  type        = string
  default     = "dev"
}

variable "stack_name" {
  description = "Stack name for resource naming"
  type        = string
  default     = "agentcore-mcp-server"
}

variable "description" {
  description = "Description of the agent runtime"
  type        = string
  default     = "MCP server runtime with JWT authentication"
}

variable "environment_variables" {
  description = "Environment variables for the agent runtime"
  type        = map(string)
  default     = {}
}

variable "ecr_repository_name" {
  description = "Name of the ECR repository"
  type        = string
  default     = "mcp-server"
}

# ============================================================================
# Authentication Provider Configuration
# ============================================================================

variable "auth_provider" {
  description = "Authentication provider to use: 'cognito' or 'entra_id'"
  type        = string
  default     = "cognito"

  validation {
    condition     = contains(["cognito", "entra_id"], var.auth_provider)
    error_message = "Auth provider must be either 'cognito' or 'entra_id'"
  }
}

# Cognito Configuration (used when auth_provider = "cognito")
variable "cognito_user_pool_name" {
  description = "Name for the Cognito User Pool (only used if auth_provider = 'cognito')"
  type        = string
  default     = "mcp-server-users"
}

# Entra ID Configuration (used when auth_provider = "entra_id")
variable "entra_id_tenant_id" {
  description = "Entra ID (Azure AD) Tenant ID (only used if auth_provider = 'entra_id')"
  type        = string
  default     = ""

  validation {
    condition     = var.entra_id_tenant_id == "" || can(regex("^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$", var.entra_id_tenant_id))
    error_message = "Must be empty or a valid UUID format for Entra ID Tenant ID"
  }
}

variable "entra_id_client_id" {
  description = "Entra ID Application (Client) ID (only used if auth_provider = 'entra_id')"
  type        = string
  default     = ""

  validation {
    condition     = var.entra_id_client_id == "" || can(regex("^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$", var.entra_id_client_id))
    error_message = "Must be empty or a valid UUID format for Entra ID Client ID"
  }
}
