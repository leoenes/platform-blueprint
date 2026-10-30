FROM public.ecr.aws/docker/library/golang:1.25-bookworm AS build
WORKDIR /src
COPY . .
RUN --mount=type=cache,target=/root/.cache/go-build go build -o /out/app ./...

FROM gcr.io/distroless/static-debian12:nonroot
COPY --from=build /out/app /app
USER nonroot
EXPOSE 8080
ENTRYPOINT ["/app"]
