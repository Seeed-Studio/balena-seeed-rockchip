#!/usr/bin/env python3
"""TCP relay for balenaCloud VPN (office network blocks direct AWS access).

Listens on the gadget interface and forwards to the balenaCloud VPN endpoint;
outbound side rides the host's default route (FlClash TUN) which can reach AWS.
"""
import asyncio, sys

LISTEN_HOST, LISTEN_PORT = "10.55.0.10", 10443
UPSTREAM_HOST, UPSTREAM_PORT = "18.211.77.233", 443

async def pipe(reader, writer, tag):
    try:
        while data := await reader.read(65536):
            writer.write(data)
            await writer.drain()
    except Exception:
        pass
    finally:
        try:
            writer.close()
        except Exception:
            pass
        print(f"[{tag}] closed", flush=True)

async def handle(client_r, client_w):
    peer = client_w.get_extra_info("peername")
    print(f"[relay] connection from {peer}", flush=True)
    try:
        up_r, up_w = await asyncio.open_connection(UPSTREAM_HOST, UPSTREAM_PORT)
    except Exception as e:
        print(f"[relay] upstream connect failed: {e}", flush=True)
        client_w.close()
        return
    print(f"[relay] upstream connected to {UPSTREAM_HOST}:{UPSTREAM_PORT}", flush=True)
    await asyncio.gather(pipe(client_r, up_w, "c->u"), pipe(up_r, client_w, "u->c"))

async def main():
    server = await asyncio.start_server(handle, LISTEN_HOST, LISTEN_PORT)
    print(f"[relay] listening on {LISTEN_HOST}:{LISTEN_PORT} -> {UPSTREAM_HOST}:{UPSTREAM_PORT}", flush=True)
    async with server:
        await server.serve_forever()

if __name__ == "__main__":
    try:
        asyncio.run(main())
    except KeyboardInterrupt:
        sys.exit(0)
