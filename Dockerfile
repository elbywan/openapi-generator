FROM crystallang/crystal:1.0.0-alpine

WORKDIR /app
ENV SHARDS_OPTS=--ignore-crystal-version

# Copy shard files and install shards
COPY shard.* ./
COPY spec spec
COPY src src

# Format
RUN crystal tool format --check

# Core
RUN shards install
RUN crystal spec ./spec/core && \
    crystal spec ./spec/amber && \
    crystal spec ./spec/lucky && \
    crystal spec ./spec/spider-gazelle

ENTRYPOINT exit 0