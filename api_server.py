from fastapi import FastAPI, BackgroundTasks
import uvicorn
import sys
import os

# 1. KẾT NỐI API VỚI THƯ MỤC BACKEND
from backend.PyCode.router_layer3.routing.main import routing_dispatcher 
from backend.PyCode.router_layer3.interface.main import interface_dispatcher

# BỔ SUNG IMPORT CHO MODULE SECURITY (ACL)

from backend.PyCode.security.main import security_dispatcher
#import nat
from backend.PyCode.router_layer3.service.nat.main import nat_dispatcher
app = FastAPI(
    title="Network Master API",
    description="Trung tâm quản lý toàn bộ URL kết nối với Frontend"
)

# =====================================================================
# 📍 KHU VỰC QUẢN LÝ URL (chỉ cần bảo trì chỗ này)
# =====================================================================

#============= API CỦA MODULE INTERFACE ROUTER LAYER 3=========================
@app.post("/api/v1/network/interfaces")
def trigger_interface(target: str = "all", bg_tasks: BackgroundTasks = None):
    """ API kích hoạt cấu hình Interface """
    if bg_tasks:
        bg_tasks.add_task(interface_dispatcher, target)
    else:
        interface_dispatcher(target)
    return {"status": "success", "message": f"Đang đẩy lệnh Interface xuống {target}..."}


#=============== API CỦA MODULE ROUTING LAYER 3 ========================
@app.post("/api/v1/network/ospf")
def trigger_ospf(target: str = "all", bg_tasks: BackgroundTasks = None):
    if bg_tasks:
        bg_tasks.add_task(routing_dispatcher, target, "ospf")
    else:
        routing_dispatcher(target, "ospf")
    return {"status": "success", "message": f"Đang đẩy lệnh OSPF xuống {target}..."}

@app.post("/api/v1/network/eigrp")
def trigger_eigrp(target: str = "all", bg_tasks: BackgroundTasks = None):
    if bg_tasks:
        bg_tasks.add_task(routing_dispatcher, target, "eigrp")
    else:
        routing_dispatcher(target, "eigrp")
    return {"status": "success", "message": f"Đang đẩy lệnh EIGRP xuống {target}..."}

@app.post("/api/v1/network/static")
def trigger_static(target: str = "all", bg_tasks: BackgroundTasks = None):
    if bg_tasks:
        bg_tasks.add_task(routing_dispatcher, target, "static")
    else:
        routing_dispatcher(target, "static")
    return {"status": "success", "message": f"Đang đẩy lệnh Static Route xuống {target}..."}


#=============== API CỦA MODULE SECURITY (ACL) ========================
@app.post("/api/v1/network/acl")
def trigger_acl(target: str = "all", acl_id: int = None, bg_tasks: BackgroundTasks = None):
    """ API kích hoạt cấu hình ACL (Có thể gọi đích danh ID hoặc quét toàn bộ) """
    if bg_tasks:
        # Truyền thêm tham số "acl" và acl_id vào hàm điều phối
        bg_tasks.add_task(security_dispatcher, target, "acl", acl_id)
    else:
        security_dispatcher(target, "acl", acl_id)
        
    msg = f"Đang đẩy lệnh ACL (ID: {acl_id}) xuống {target}..." if acl_id else f"Đang quét và đẩy toàn bộ ACL chờ xử lý xuống {target}..."
    return {"status": "success", "message": msg}

#=============== API CỦA MODULE NAT ========================
@app.post("/api/v1/network/nat")
def trigger_nat(target: str = "all", bg_tasks: BackgroundTasks = None):
    """ API kích hoạt cấu hình toàn bộ khối NAT (NAT ACL & NAT Engine) """
    if bg_tasks:
        bg_tasks.add_task(nat_dispatcher, target)
    else:
        nat_dispatcher(target)
        
    return {"status": "success", "message": f"Đang quét và đẩy lệnh NAT xuống {target}..."}

if __name__ == "__main__":
    uvicorn.run("api_server:app", host="127.0.0.1", port=8000, reload=True)