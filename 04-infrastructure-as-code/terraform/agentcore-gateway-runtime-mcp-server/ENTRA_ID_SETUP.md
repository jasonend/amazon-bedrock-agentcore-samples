# Using Entra ID Authentication Instead of Cognito

This guide explains how to configure the MCP Server and Gateway to use Microsoft Entra ID (formerly Azure AD) for JWT authentication instead of AWS Cognito.

## Table of Contents

- [Overview](#overview)
- [Prerequisites](#prerequisites)
- [Entra ID Setup](#entra-id-setup)
- [Terraform Configuration](#terraform-configuration)
- [Testing with Entra ID](#testing-with-entra-id)
- [Production Considerations](#production-considerations)
- [Troubleshooting](#troubleshooting)

## Overview

The AgentCore Runtime and Gateway support any OIDC-compliant identity provider through the Custom JWT Authorizer. This includes:

- Microsoft Entra ID (Azure AD)
- Okta
- Auth0
- Google Identity Platform
- Any OIDC-compliant provider

The key requirement is an OIDC discovery URL that provides the JWT validation configuration.

## Prerequisites

### Azure/Entra ID Requirements

1. **Azure Subscription** with access to Entra ID
2. **App Registration** in Entra ID
3. **User Account** for testing (or service principal for production)

### Local Development Requirements

```bash
# For token acquisition
pip install msal

# For MCP testing (already required)
pip install boto3 mcp
```

## Entra ID Setup

### Step 1: Create App Registration

1. Go to [Azure Portal](https://portal.azure.com)
2. Navigate to **Azure Active Directory** > **App registrations**
3. Click **New registration**
4. Configure:
   - **Name**: `AgentCore MCP Server`
   - **Supported account types**: Choose based on your needs
     - Single tenant (recommended for internal use)
     - Multi-tenant (if needed)
   - **Redirect URI**: Leave blank for now
5. Click **Register**

### Step 2: Note Important IDs

After registration, note these values:

- **Application (client) ID**: `87654321-4321-4321-4321-210987654321`
- **Directory (tenant) ID**: `12345678-1234-1234-1234-123456789012`

These will be used in your Terraform configuration.

### Step 3: Configure Authentication

1. Go to **Authentication** in your App Registration
2. Under **Advanced settings**:
   - Enable **Allow public client flows** (for testing with ROPC)
   - This allows the Resource Owner Password Credentials flow

**⚠️ Important**: ROPC flow is for testing only. For production, use:
- Authorization Code flow with PKCE (web applications)
- Client Credentials flow (service-to-service)
- Device Code flow (CLI tools)

### Step 4: Configure API Permissions (Optional)

If you need specific scopes:

1. Go to **API permissions**
2. Add permissions as needed
3. Grant admin consent if required

### Step 5: Verify OIDC Discovery URL

Your Entra ID OIDC discovery URL will be:

```
https://login.microsoftonline.com/{tenant-id}/v2.0/.well-known/openid-configuration
```

You can verify it works:

```bash
curl https://login.microsoftonline.com/12345678-1234-1234-1234-123456789012/v2.0/.well-known/openid-configuration
```

## Terraform Configuration

### Step 1: Update terraform.tfvars

Simply set the authentication provider and add your Entra ID credentials:

```hcl
# Choose Entra ID as authentication provider
auth_provider = "entra_id"

# Add your Entra ID credentials
entra_id_tenant_id = "12345678-1234-1234-1234-123456789012"
entra_id_client_id = "87654321-4321-4321-4321-210987654321"
```

That's it! The infrastructure automatically:
- Skips Cognito resource creation
- Configures Runtime and Gateway with Entra ID discovery URL
- Sets up JWT validation against your Entra ID tenant

### Step 2: Deploy

```bash
terraform init
terraform plan
terraform apply
```

The deployment will:
- Create AgentCore Runtime with Entra ID authentication
- Create AgentCore Gateway with Entra ID authentication
- Skip all Cognito resources (User Pool, Client, Test User)
- Configure both to validate JWT tokens from your Entra ID tenant

## Testing with Entra ID

### Step 1: Get JWT Token

Use the provided script to get a token:

```bash
python get_entra_id_token.py \
  12345678-1234-1234-1234-123456789012 \
  87654321-4321-4321-4321-210987654321 \
  user@example.com \
  MyPassword123!
```

This will output a JWT token. Copy it for the next steps.

### Step 2: Test Runtime Directly

```bash
RUNTIME_ARN=$(terraform output -raw agent_runtime_arn)
REGION=$(terraform output -raw aws_region)

python test_mcp_server.py $RUNTIME_ARN YOUR_JWT_TOKEN $REGION
```

### Step 3: Test Gateway

```bash
GATEWAY_ARN=$(terraform output -raw gateway_arn)
REGION=$(terraform output -raw aws_region)

python test_gateway.py $GATEWAY_ARN YOUR_JWT_TOKEN $REGION
```

## Production Considerations

### Authentication Flows

**For Testing/Development:**
- Resource Owner Password Credentials (ROPC) flow
- Simple username/password authentication
- Requires "Allow public client flows" enabled

**For Production:**

1. **Web Applications**: Authorization Code flow with PKCE
   ```python
   # Use MSAL with redirect URI
   app = ConfidentialClientApplication(
       client_id=client_id,
       client_credential=client_secret,
       authority=authority
   )
   ```

2. **Service-to-Service**: Client Credentials flow
   ```python
   # Use service principal
   result = app.acquire_token_for_client(scopes=["api://your-api/.default"])
   ```

3. **CLI Tools**: Device Code flow
   ```python
   # User authenticates via browser
   flow = app.initiate_device_flow(scopes=scopes)
   ```

### Security Best Practices

1. **Token Validation**:
   - AgentCore validates tokens against the OIDC discovery URL
   - Checks signature, expiration, issuer, and audience

2. **Client ID Restrictions**:
   - Only specified client IDs in `allowed_clients` can access
   - Use different client IDs for different environments

3. **Token Expiration**:
   - Entra ID tokens typically expire after 1 hour
   - Implement token refresh in your application

4. **Network Security**:
   - Use HTTPS for all token exchanges
   - Consider using `network_mode = "PRIVATE"` for VPC deployment

### Multi-Environment Setup

Use different App Registrations per environment:

```hcl
# dev.tfvars
entra_id_client_id = "dev-client-id"

# staging.tfvars
entra_id_client_id = "staging-client-id"

# prod.tfvars
entra_id_client_id = "prod-client-id"
```

## Troubleshooting

### Common Errors

**Error: AADSTS50126 - Invalid username or password**
- Verify credentials are correct
- Check if account is locked or requires password reset

**Error: AADSTS700016 - Application not found**
- Verify Client ID is correct
- Ensure App Registration exists in the correct tenant

**Error: AADSTS90002 - Tenant not found**
- Verify Tenant ID is correct
- Check if you have access to the tenant

**Error: AADSTS65001 - User consent required**
- Enable "Allow public client flows" in App Registration
- Grant necessary API permissions
- Provide admin consent if required

**Error: AADSTS50076 - Multi-factor authentication required**
- ROPC flow doesn't support MFA
- Use Authorization Code flow or Device Code flow instead
- Or disable MFA for test accounts (not recommended for production)

### Token Validation Issues

If tokens are rejected by AgentCore:

1. **Verify Discovery URL**:
   ```bash
   curl https://login.microsoftonline.com/{tenant-id}/v2.0/.well-known/openid-configuration
   ```

2. **Check Token Claims**:
   - Decode token at [jwt.io](https://jwt.io)
   - Verify `aud` (audience) claim
   - Verify `iss` (issuer) claim matches discovery URL
   - Check `exp` (expiration) hasn't passed

3. **Verify Client ID**:
   - Ensure token's `aud` or `appid` claim matches `allowed_clients`

4. **Check CloudWatch Logs**:
   ```bash
   aws logs tail /aws/bedrock-agentcore/runtimes/YOUR_RUNTIME_ID --follow
   ```

### Network Issues

If you can't reach Entra ID endpoints:

1. Check firewall rules allow outbound HTTPS to:
   - `login.microsoftonline.com`
   - `graph.microsoft.com` (if using Graph API)

2. Verify DNS resolution:
   ```bash
   nslookup login.microsoftonline.com
   ```

3. Test connectivity:
   ```bash
   curl -v https://login.microsoftonline.com/{tenant-id}/v2.0/.well-known/openid-configuration
   ```

## Additional Resources

- [Microsoft Entra ID Documentation](https://learn.microsoft.com/en-us/entra/identity/)
- [MSAL Python Documentation](https://msal-python.readthedocs.io/)
- [OAuth 2.0 and OpenID Connect](https://learn.microsoft.com/en-us/entra/identity-platform/v2-protocols)
- [AgentCore Gateway Documentation](https://docs.aws.amazon.com/bedrock/latest/userguide/agentcore-gateway.html)
- [Integration Examples](../../../03-integrations/IDP-examples/) - See EntraID examples in the repository

## Example Files Reference

This directory includes example files for Entra ID configuration:

- `gateway_entra_id.tf.example` - Gateway with Entra ID auth
- `main_entra_id.tf.example` - Runtime with Entra ID auth
- `variables_entra_id.tf.example` - Required variables
- `terraform.tfvars.entra_id.example` - Example values
- `get_entra_id_token.py` - Token acquisition script

Copy and modify these files as needed for your deployment.
