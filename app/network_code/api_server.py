from fastapi import FastAPI, BackgroundTasks
import uvicorn
import sys
import os

# 1. KẾT NỐI API VỚI THƯ MỤC BACKEND
# Nhúng đường dẫn vào hệ thống để API có thể "nhìn thấy" đống code Python bên trong



#gọi module routing_dispatcher từ file main.py trong thư mục backend/PyCode/router_layer3/routing
from backend.PyCode.router_layer3.routing.main import routing_dispatcher 
#gọi module interface_dispatcher từ file main.py trong thư mục backend/PyCode/router_layer3/interface
from backend.PyCode.router_layer3.interface.main import interface_dispatcher


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
    """Nhận request API và kích hoạt push cấu hình Interface."""
    if bg_tasks:
        bg_tasks.add_task(interface_dispatcher, target)
    else:
        interface_dispatcher(target)
    return {"status": "success", "message": f"Đang đẩy lệnh Interface xuống {target}..."}


#=============== API CỦA MODULE ROUTING LAYER 3 ========================

# --- API CỦA OSPF ------------- 
@app.post("/api/v1/network/ospf")
def trigger_ospf(target: str = "all", bg_tasks: BackgroundTasks = None):
    """Nhận request API và kích hoạt push cấu hình OSPF."""
    if bg_tasks:
        # Truyền thêm tham số "ospf" vào hàm
        bg_tasks.add_task(routing_dispatcher, target, "ospf")
    else:
        routing_dispatcher(target, "ospf")
    return {"status": "success", "message": f"Đang đẩy lệnh OSPF xuống {target}..."}

#------API CỦA EIGRP -------------
@app.post("/api/v1/network/eigrp")
def trigger_eigrp(target: str = "all", bg_tasks: BackgroundTasks = None):
    """Nhận request API và kích hoạt push cấu hình EIGRP."""
    if bg_tasks:
        # Truyền thêm tham số "eigrp" vào hàm
        bg_tasks.add_task(routing_dispatcher, target, "eigrp")
    else:
        routing_dispatcher(target, "eigrp")
    return {"status": "success", "message": f"Đang đẩy lệnh EIGRP xuống {target}..."}

# =====================================================================

#------API CỦA STATIC ROUTE -------------
@app.post("/api/v1/network/static")
def trigger_static(target: str = "all", bg_tasks: BackgroundTasks = None):
    """Nhận request API và kích hoạt push cấu hình Static Route."""
    if bg_tasks:
        # Truyền tham số "static" vào hàm điều phối
        bg_tasks.add_task(routing_dispatcher, target, "static")
    else:
        routing_dispatcher(target, "static")
    return {"status": "success", "message": f"Đang đẩy lệnh Static Route xuống {target}..."}

if __name__ == "__main__":
    # Khởi động server (reload=True để khi sếp sửa file này, server tự cập nhật)
    uvicorn.run("api_server:app", host="127.0.0.1", port=8000, reload=True)
