# Device state sync

Status: **implemented** with an optional Cython accelerator and Python fallback.

The package separates the public synchronization surface by responsibility:

- `parser.py`: running-config parsing
- `interfaces.py`: interface SQLite writers
- `routing.py`: static route, OSPF, and EIGRP writers
- `service.py`: transaction-level orchestration
- `common.py`: shared normalization helpers
- `_engine.py`: single-source implementation compiled by the optional Cython build

`features.devices.sync_state` remains a compatibility module. Existing imports
continue to work without changes.

The normal installation uses `_engine.py`. To build the same implementation as
a native extension:

```shell
uv sync --extra speed
uv run python setup_cython.py build_ext --inplace
```

The resulting `_engine.*.so` (Linux/macOS) or `_engine*.pyd` (Windows) is loaded
automatically before `_engine.py`. Delete only that generated extension to
return to the Python implementation.

`networktools.sh setup` and `networktools.bat setup` attempt this optional build
but fall back to `_engine.py` when a compiler is unavailable or an OS policy
blocks the native module. Use the explicit `build` command when native
acceleration is required and a failed build should return a non-zero status.
On Windows, the batch launcher can replace a blocked accelerated Cython wheel
with Cython's pure-Python compiler, but building the app's `.pyd` still requires
Microsoft Visual C++ 14.0 or newer.

Always benchmark the full synchronization path. Cython primarily helps parsing
and Python control flow; SQLite execution time is already spent in native code.
