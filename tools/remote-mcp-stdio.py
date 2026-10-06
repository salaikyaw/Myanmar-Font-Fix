import asyncio, os, sys
from contextlib import AsyncExitStack
from mcp import ClientSession
from mcp.client.streamable_http import streamablehttp_client
from mcp.server.lowlevel import Server
from mcp.server.stdio import stdio_server

async def main():
    name=sys.argv[1]
    headers={}
    if name=='context7':
        key=os.environ.get('CONTEXT7_API_KEY')
        if key: headers['CONTEXT7_API_KEY']=key
        transport=streamablehttp_client('https://mcp.context7.com/mcp',headers=headers,timeout=45)
    elif name=='cloudflare-docs':
        transport=streamablehttp_client('https://docs.mcp.cloudflare.com/mcp',timeout=45)
    else: raise ValueError('Unsupported fixed upstream')
    async with AsyncExitStack() as stack:
        streams=await stack.enter_async_context(transport)
        session=await stack.enter_async_context(ClientSession(streams[0],streams[1]))
        await session.initialize()
        server=Server('egress-'+name)
        @server.list_tools()
        async def list_tools():
            return (await session.list_tools()).tools
        @server.call_tool()
        async def call_tool(name,arguments):
            return await session.call_tool(name,arguments)
        stdio=await stack.enter_async_context(stdio_server())
        await server.run(stdio[0],stdio[1],server.create_initialization_options())

asyncio.run(main())
