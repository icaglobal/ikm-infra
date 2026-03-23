# ============================================
# Stage 1: Build rocks-kb and tinkar-core
# ============================================
# Force amd64 platform - RocksDB only has linux64 (x86_64) natives, not ARM64
FROM --platform=linux/amd64 eclipse-temurin:25-jdk AS builder

WORKDIR /build

# Install protoc, protoc-gen-doc, and git (required for proto file generation and cloning repos)
RUN apt-get update && apt-get install -y --no-install-recommends \
    protobuf-compiler \
    curl \
    git \
    && rm -rf /var/lib/apt/lists/*

# Install protoc-gen-doc
RUN curl -sSL https://github.com/pseudomuto/protoc-gen-doc/releases/download/v1.5.1/protoc-gen-doc_1.5.1_linux_amd64.tar.gz \
    | tar -xz -C /usr/local/bin

# Clone rocks-kb first (it's a dependency for tinkar-core)
RUN git clone --depth 1 --branch feature/grpc-service https://github.com/ikmdev/rocks-kb.git /build/rocks-kb/

# Build and install rocks-kb to local Maven repo
WORKDIR /build/rocks-kb
RUN ./mvnw install -DskipTests -B -q

# Clone tinkar-schema (needed by protobuf plugin in tinkar-core/service)
RUN git clone --depth 1 https://github.com/ikmdev/tinkar-schema.git /build/tinkar-schema/

# Clone tinkar-core
RUN git clone --depth 1 --branch feature/service https://github.com/ikmdev/tinkar-core.git /build/tinkar-core/

# Build tinkar-core (skip Javadoc to avoid preview feature issues)
WORKDIR /build/tinkar-core
RUN ./mvnw install -DskipTests -Dmaven.javadoc.skip=true -B -q

# ============================================
# Stage 2: Runtime
# ============================================
# Force amd64 platform to match the build
FROM --platform=linux/amd64 eclipse-temurin:25-jre

WORKDIR /app

# Create non-root user for security
RUN groupadd --system tinkar && \
    useradd --system --gid tinkar --shell /bin/false tinkar

# Copy the Spring Boot fat jar from builder
COPY --from=builder /build/tinkar-core/service/target/service-*.jar app.jar

# Copy pre-extracted RocksDB data
# Users: set ROCKSDB_DATA_DIR to the name of your unzipped data folder
ARG ROCKSDB_DATA_DIR="SOLOR-GUDID-FULL-20250915 RocksKb"
COPY ${ROCKSDB_DATA_DIR}/ /app/data/gudid/

# Fix ownership
RUN chown -R tinkar:tinkar /app

# Switch to non-root user
USER tinkar

# Expose REST (8085) and gRPC (9095) ports
EXPOSE 8085 9095

# Health check for REST endpoint
HEALTHCHECK --interval=30s --timeout=10s --start-period=60s --retries=3 \
    CMD curl -f http://localhost:8085/actuator/health || exit 1

# Remove stale Lucene lock files that may have been baked in from a previous run,
# then start the application.
ENTRYPOINT ["sh", "-c", "find /app/data -name 'write.lock' -delete && exec java --enable-preview -jar app.jar \"$@\"", "--"]
