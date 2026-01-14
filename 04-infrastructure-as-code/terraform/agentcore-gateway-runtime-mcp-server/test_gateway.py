#!/usr/bin/env python3
"""
Test script for AgentCore Gateway that targets the MCP Server Runtime.

This script demonstrates how to:
1. Initialize an MCP session with the Gateway
2. List available tools exposed through the Gateway
3. Invoke tools through the Gateway

Usage:
    python test_gateway.py <gateway_arn> <jwt_token> [aws_region]

Example:
    python test_gateway.py arn:aws:bedrock-agentcore:us-west-2:123456789012:gateway/GATEWAY123 eyJraWQ... us-west-2
"""

import sys
import json
import boto3
from mcp import ClientSession, StdioServerParameters
from mcp.client.stdio import stdio_client

def test_gateway(gateway_arn: str, jwt_token: str, region: str = "us-west-2"):
    """Test the AgentCore Gateway by invoking MCP tools."""
    
    print("🔄 Initializing MCP session with Gateway...")
    
    # Create Bedrock AgentCore client
    client = boto3.client('bedrock-agentcore', region_name=region)
    
    # Initialize MCP session through Gateway
    try:
        session_response = client.invoke_gateway(
            gatewayArn=gateway_arn,
            headers={
                'Authorization': f'Bearer {jwt_token}',
                'Content-Type': 'application/json'
            },
            body=json.dumps({
                "jsonrpc": "2.0",
                "method": "initialize",
                "params": {
                    "protocolVersion": "2024-11-05",
                    "capabilities": {},
                    "clientInfo": {
                        "name": "test-client",
                        "version": "1.0.0"
                    }
                },
                "id": 1
            })
        )
        
        session_id = session_response.get('sessionId')
        print(f"✓ MCP session initialized: {session_id}\n")
        
    except Exception as e:
        print(f"❌ Failed to initialize session: {e}")
        return
    
    # List available tools
    print("🔄 Listing available tools through Gateway...\n")
    
    try:
        tools_response = client.invoke_gateway(
            gatewayArn=gateway_arn,
            sessionId=session_id,
            headers={
                'Authorization': f'Bearer {jwt_token}',
                'Content-Type': 'application/json'
            },
            body=json.dumps({
                "jsonrpc": "2.0",
                "method": "tools/list",
                "params": {},
                "id": 2
            })
        )
        
        response_body = json.loads(tools_response['body'].read())
        tools = response_body.get('result', {}).get('tools', [])
        
        print("📋 Available MCP Tools (via Gateway):")
        print("=" * 50)
        for tool in tools:
            print(f"🔧 {tool['name']}: {tool.get('description', 'No description')}")
        
        print("\n🧪 Testing MCP Tools through Gateway:")
        print("=" * 50)
        
        # Test 1: add_numbers
        print("\n➕ Testing add_numbers(5, 3) via Gateway...")
        result = invoke_tool(client, gateway_arn, session_id, jwt_token, 
                           "add_numbers", {"a": 5, "b": 3})
        print(f"   Result: {result}")
        
        # Test 2: multiply_numbers
        print("\n✖️  Testing multiply_numbers(4, 7) via Gateway...")
        result = invoke_tool(client, gateway_arn, session_id, jwt_token,
                           "multiply_numbers", {"a": 4, "b": 7})
        print(f"   Result: {result}")
        
        # Test 3: greet_user
        print("\n👋 Testing greet_user('Alice') via Gateway...")
        result = invoke_tool(client, gateway_arn, session_id, jwt_token,
                           "greet_user", {"name": "Alice"})
        print(f"   Result: {result}")
        
        print("\n✅ Gateway tool testing completed!")
        
    except Exception as e:
        print(f"❌ Error during tool testing: {e}")
        import traceback
        traceback.print_exc()

def invoke_tool(client, gateway_arn: str, session_id: str, jwt_token: str, 
                tool_name: str, arguments: dict):
    """Invoke a tool through the Gateway."""
    
    response = client.invoke_gateway(
        gatewayArn=gateway_arn,
        sessionId=session_id,
        headers={
            'Authorization': f'Bearer {jwt_token}',
            'Content-Type': 'application/json'
        },
        body=json.dumps({
            "jsonrpc": "2.0",
            "method": "tools/call",
            "params": {
                "name": tool_name,
                "arguments": arguments
            },
            "id": 3
        })
    )
    
    response_body = json.loads(response['body'].read())
    return response_body.get('result', {}).get('content', [{}])[0].get('text', 'No result')

if __name__ == "__main__":
    if len(sys.argv) < 3:
        print("Usage: python test_gateway.py <gateway_arn> <jwt_token> [aws_region]")
        print("\nExample:")
        print("  python test_gateway.py arn:aws:bedrock-agentcore:us-west-2:123456789012:gateway/GATEWAY123 eyJraWQ... us-west-2")
        sys.exit(1)
    
    gateway_arn = sys.argv[1]
    jwt_token = sys.argv[2]
    region = sys.argv[3] if len(sys.argv) > 3 else "us-west-2"
    
    test_gateway(gateway_arn, jwt_token, region)
