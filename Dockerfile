# ============================================
# Stage 1: Build rocks-kb and tinkar-core
# ============================================
# Force amd64 platform - RocksDB only has linux64 (x86_64) natives, not ARM64
FROM --platform=linux/amd64 eclipse-temurin:25-jdk AS builder

WORKDIR /build

# Install protoc, protoc-gen-doc, and git (required for proto file generation and cloning repos)
RUN apt-get update && apt-get install -y --no-install-recommends \
    curl \
    git \
    && rm -rf /var/lib/apt/lists/*

# Clone tinkar-service
RUN git clone --depth 1 https://github.com/icaglobal/tinkar-service.git /build/tinkar-service/

# Build tinkar-service (skip Javadoc to avoid preview feature issues)
WORKDIR /build/tinkar-service
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
COPY --from=builder /build/tinkar-service/target/tinkar-service-*.jar app.jar

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
