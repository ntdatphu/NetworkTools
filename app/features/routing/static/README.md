# Static routing

**implemented** cho static/default routes. QML `qml/features/routing/static/StaticRoutingForm.qml`; persistence `features/routing/static_route.py`, `static_default.py`; worker/template trong `features/routing/worker.py`. Validate prefix/next-hop/distance và device ownership; save/delete dùng transaction. Test: `test_database_routing_contract.py` và dev-mode worker. Backlog: tách repository/service vào thư mục con này.
