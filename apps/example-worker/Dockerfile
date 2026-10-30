FROM public.ecr.aws/docker/library/python:3.13-slim AS build
WORKDIR /src
COPY pyproject.toml uv.lock ./
RUN --mount=type=cache,target=/root/.cache/uv \
    --mount=type=secret,id=pip_index_url,env=PIP_INDEX_URL,required=false \
    pip install --no-cache-dir uv && uv sync --frozen --no-dev
COPY . .

FROM public.ecr.aws/docker/library/python:3.13-slim
WORKDIR /app
COPY --from=build /src /app
USER 65532
ENV PATH=/app/.venv/bin:$PATH
CMD ["python", "-m", "worker"]
