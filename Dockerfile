FROM crystallang/crystal:0.36.1-alpine

WORKDIR /app

# Copy shard files and install shards
COPY shard.* .
COPY spec spec
COPY src src

# Format
RUN crystal tool format --check

# Core
RUN shards install
RUN crystal spec ./spec/core

# Amber
RUN rm shard.yml && rm shard.lock && cp shard.amber.yml ./shard.yml && shards install
RUN crystal spec ./spec/helpers/amber_spec.cr
RUN crystal spec ./spec/providers/amber_spec.cr

# Lucky
RUN rm shard.yml && rm shard.lock && cp shard.lucky.yml ./shard.yml && shards install
RUN crystal spec ./spec/helpers/lucky_spec.cr
RUN crystal spec ./spec/providers/lucky_spec.cr

ENTRYPOINT exit 0