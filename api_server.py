from __future__ import annotations

import uvicorn
from fastapi import BackgroundTasks, FastAPI

from backend.PyCode.router_layer3.interface.main import interface_dispatcher
from backend.PyCode.router_layer3.routing.main import routing_dispatcher
from backend.PyCode.router_layer3.service.nat.main import nat_dispatcher
from backend.PyCode.security.main import security_dispatcher


app = FastAPI(
    title="Network Master API",
    description="Trung tâm quản lý toàn bộ URL kết nối với Frontend",
)


@app.post("/api/v1/network/interfaces")
def trigger_interface(bg_tasks: BackgroundTasks, target: str = "all") -> dict[str, str]:
    """Nhận request API và kích hoạt push cấu hình Interface."""
    bg_tasks.add_task(interface_dispatcher, target)
    return {"status": "success", "message": f"Đang đẩy lệnh Interface xuống {target}..."}


@app.post("/api/v1/network/ospf")
def trigger_ospf(bg_tasks: BackgroundTasks, target: str = "all") -> dict[str, str]:
    bg_tasks.add_task(routing_dispatcher, target, "ospf")
    return {"status": "success", "message": f"Đang đẩy lệnh OSPF xuống {target}..."}


@app.post("/api/v1/network/eigrp")
def trigger_eigrp(bg_tasks: BackgroundTasks, target: str = "all") -> dict[str, str]:
    bg_tasks.add_task(routing_dispatcher, target, "eigrp")
    return {"status": "success", "message": f"Đang đẩy lệnh EIGRP xuống {target}..."}


@app.post("/api/v1/network/static")
def trigger_static(bg_tasks: BackgroundTasks, target: str = "all") -> dict[str, str]:
    bg_tasks.add_task(routing_dispatcher, target, "static")
    return {"status": "success", "message": f"Đang đẩy lệnh Static Route xuống {target}..."}


@app.post("/api/v1/network/acl")
def trigger_acl(
    bg_tasks: BackgroundTasks,
    target: str = "all",
    acl_id: int | None = None,
) -> dict[str, str]:
    """Kích hoạt cấu hình ACL theo ID hoặc quét toàn bộ tác vụ chờ."""
    bg_tasks.add_task(security_dispatcher, target, "acl", acl_id)

    msg = (
        f"Đang đẩy lệnh ACL (ID: {acl_id}) xuống {target}..."
        if acl_id is not None
        else f"Đang quét và đẩy toàn bộ ACL chờ xử lý xuống {target}..."
    )
    return {"status": "success", "message": msg}


@app.post("/api/v1/network/nat")
def trigger_nat(bg_tasks: BackgroundTasks, target: str = "all") -> dict[str, str]:
    """Kích hoạt cấu hình toàn bộ khối NAT (NAT ACL và NAT Engine)."""
    bg_tasks.add_task(nat_dispatcher, target)
    return {"status": "success", "message": f"Đang quét và đẩy lệnh NAT xuống {target}..."}


if __name__ == "__main__":
    uvicorn.run("api_server:app", host="127.0.0.1", port=8000, reload=True)
