FROM alpine:3.24 AS builder
WORKDIR /app
COPY . .
RUN apk add zig
RUN zig build -Doptimize=ReleaseSafe

FROM alpine:3.24
RUN apk add ffmpeg
COPY --from=builder /app/zig-out/bin/daingestd /usr/local/bin/daingestd
ENV DAINGEST_INPUT=/input \
    DAINGEST_OUTPUT=/output
VOLUME ["/input", "/output"]
ENTRYPOINT ["/usr/local/bin/daingestd"]
