import asyncio
import json
import uuid

import websockets


async def player_task(player_id: str, send_queue: asyncio.Queue):
    uri = f"ws://localhost:8000/ws/{player_id}"
    async with websockets.connect(uri) as ws:
        # First message for new player should be state_sync
        msg = await ws.recv()
        print(f"[{player_id}] recv: {msg}")

        async def sender():
            while True:
                data = await send_queue.get()
                if data is None:
                    return
                await ws.send(json.dumps(data))
                print(f"[{player_id}] sent: {data}")

        sender_task = asyncio.create_task(sender())

        try:
            # Receive a stream for a bit; print everything (MVP debug)
            while True:
                incoming = await ws.recv()
                print(f"[{player_id}] recv: {incoming}")
        except asyncio.CancelledError:
            pass
        finally:
            sender_task.cancel()


async def main():
    # Unique ids so you can run multiple times without collisions.
    p1 = f"player_{uuid.uuid4().hex[:6]}"
    p2 = f"player_{uuid.uuid4().hex[:6]}"

    q1: asyncio.Queue = asyncio.Queue()
    q2: asyncio.Queue = asyncio.Queue()

    t1 = asyncio.create_task(player_task(p1, q1))
    t2 = asyncio.create_task(player_task(p2, q2))

    # Give the server a moment to register both connections.
    await asyncio.sleep(0.5)

    # Start the game from player 1.
    await q1.put({"type": "start_game"})

    # Periodically send positions from both players.
    for i in range(6):
        await q1.put({"type": "position_update", "position": {"x": i, "y": i}})
        await q2.put({"type": "position_update", "position": {"x": -i, "y": i}})
        await asyncio.sleep(1.0)

    # Send a couple fuse events to test player→server→broadcast.
    await q1.put({"type": "fuse_found"})
    await q2.put({"type": "fuse_found"})

    # Keep reading for a short while so ghost loop broadcasts show up.
    await asyncio.sleep(10)

    # Shutdown tasks.
    for q in (q1, q2):
        await q.put(None)
    t1.cancel()
    t2.cancel()


if __name__ == "__main__":
    asyncio.run(main())

