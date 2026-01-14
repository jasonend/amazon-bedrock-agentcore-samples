#!/usr/bin/env python3
"""
Get JWT token from Entra ID (Azure AD) for testing AgentCore Gateway/Runtime.

This script uses the OAuth 2.0 Resource Owner Password Credentials (ROPC) flow
to obtain an access token from Entra ID.

Prerequisites:
    pip install msal

Usage:
    python get_entra_id_token.py <tenant_id> <client_id> <username> <password> [scope]

Example:
    python get_entra_id_token.py 12345678-1234-1234-1234-123456789012 \
        87654321-4321-4321-4321-210987654321 \
        user@example.com \
        MyPassword123!

Note: ROPC flow should only be used for testing. For production, use:
    - Authorization Code flow with PKCE (web apps)
    - Client Credentials flow (service-to-service)
    - Device Code flow (CLI tools)
"""

import sys
import json
from msal import PublicClientApplication

def get_entra_id_token(tenant_id: str, client_id: str, username: str, password: str, scope: str = None):
    """
    Get JWT access token from Entra ID using ROPC flow.
    
    Args:
        tenant_id: Entra ID Tenant ID
        client_id: Application (Client) ID
        username: User's email/username
        password: User's password
        scope: Optional scope (default: openid profile)
    
    Returns:
        Access token string
    """
    
    # Default scope if not provided
    if not scope:
        scope = ["openid", "profile"]
    elif isinstance(scope, str):
        scope = [scope]
    
    # Authority URL for Entra ID
    authority = f"https://login.microsoftonline.com/{tenant_id}"
    
    print(f"🔐 Authenticating with Entra ID...")
    print(f"   Tenant: {tenant_id}")
    print(f"   Client: {client_id}")
    print(f"   User: {username}")
    print()
    
    # Create MSAL Public Client Application
    app = PublicClientApplication(
        client_id=client_id,
        authority=authority
    )
    
    # Acquire token using Resource Owner Password Credentials flow
    result = app.acquire_token_by_username_password(
        username=username,
        password=password,
        scopes=scope
    )
    
    if "access_token" in result:
        print("✅ Successfully obtained access token!")
        print()
        print("=" * 80)
        print("ACCESS TOKEN:")
        print("=" * 80)
        print(result["access_token"])
        print("=" * 80)
        print()
        print("Token Details:")
        print(f"  Expires in: {result.get('expires_in', 'N/A')} seconds")
        print(f"  Token type: {result.get('token_type', 'N/A')}")
        print(f"  Scope: {result.get('scope', 'N/A')}")
        print()
        print("💡 Copy the token above to use with test_mcp_server.py or test_gateway.py")
        print()
        
        return result["access_token"]
    else:
        print("❌ Failed to obtain access token!")
        print()
        print("Error Details:")
        print(json.dumps(result, indent=2))
        print()
        
        # Common error messages
        if "error" in result:
            error = result["error"]
            error_desc = result.get("error_description", "")
            
            print("Troubleshooting:")
            if "AADSTS50126" in error_desc:
                print("  • Invalid username or password")
            elif "AADSTS700016" in error_desc:
                print("  • Invalid client ID or application not found")
            elif "AADSTS90002" in error_desc:
                print("  • Invalid tenant ID")
            elif "AADSTS65001" in error_desc:
                print("  • User consent required - ROPC flow may not be enabled")
                print("  • Enable 'Allow public client flows' in App Registration > Authentication")
            else:
                print(f"  • Error code: {error}")
                print(f"  • Description: {error_desc}")
        
        sys.exit(1)

def main():
    if len(sys.argv) < 5:
        print("Usage: python get_entra_id_token.py <tenant_id> <client_id> <username> <password> [scope]")
        print()
        print("Example:")
        print("  python get_entra_id_token.py \\")
        print("    12345678-1234-1234-1234-123456789012 \\")
        print("    87654321-4321-4321-4321-210987654321 \\")
        print("    user@example.com \\")
        print("    MyPassword123!")
        print()
        print("Prerequisites:")
        print("  pip install msal")
        print()
        print("Entra ID App Registration Setup:")
        print("  1. Go to Azure Portal > App Registrations")
        print("  2. Create or select your application")
        print("  3. Note the Application (client) ID and Directory (tenant) ID")
        print("  4. Go to Authentication > Advanced settings")
        print("  5. Enable 'Allow public client flows' (for ROPC)")
        print()
        print("⚠️  ROPC flow is for testing only. Use Authorization Code flow for production.")
        sys.exit(1)
    
    tenant_id = sys.argv[1]
    client_id = sys.argv[2]
    username = sys.argv[3]
    password = sys.argv[4]
    scope = sys.argv[5] if len(sys.argv) > 5 else None
    
    get_entra_id_token(tenant_id, client_id, username, password, scope)

if __name__ == "__main__":
    main()
