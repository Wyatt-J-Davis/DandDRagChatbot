# Issue 1: FastAPI skeleton: `api/` module + uvicorn launcher

## What to build

Create the `api/` package with a `main.py` that starts a uvicorn server. No routes yet — just the application factory, middleware setup, and a runnable server. This is the foundation every subsequent API slice builds on.

## Acceptance criteria

- [ ] `api/` directory exists as a Python package with `__init__.py` and `main.py`
- [ ] Running `uvicorn api.main:app` starts without errors
- [ ] Server binds to `localhost` on a configurable port (default `8000`)
- [ ] No routes defined yet (404 on all paths is acceptable)

## Blocked by

None — can start immediately.
