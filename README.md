# IKM Infra

Docker build for the Tinkar service, including RocksDB data.

## Prerequisites

- Docker
- A pre-extracted RocksDB data folder (e.g., `SOLOR-GUDID-FULL-20250915 RocksKb`) placed in this directory

## Git Branches

The Docker build clones the following repos/branches during the build stage:

| Repository | Branch                  |
|---|-------------------------|
| [rocks-kb](https://github.com/ikmdev/rocks-kb) | `feature/grpc-service`  |
| [tinkar-schema](https://github.com/ikmdev/tinkar-schema) | default branch (`main`) |
| [tinkar-core](https://github.com/ikmdev/tinkar-core) | `feature/service`       |

## Build

1. Unzip your RocksDB data into this directory:

   ```bash
   unzip "SOLOR-GUDID-FULL-20250915 RocksKb.zip"
   ```

2. Build the image:

   ```bash
   docker build -t tinkar-service .
   ```

   If your data folder has a different name, pass it as a build arg:

   ```bash
   docker build --build-arg ROCKSDB_DATA_DIR="Your-Folder-Name" -t tinkar-service .
   ```

   To force a fresh build (no cache):

   ```bash
   docker build --no-cache -t tinkar-service .
   ```

## Run

```bash
docker run -p 8085:8085 -p 9095:9095 tinkar-service
```

- **8085** - REST API
- **9095** - gRPC

## Notes

- The build targets `linux/amd64` because RocksDB only ships x86_64 native libraries.
- The unzipped data folder can be large (~6GB+). Make sure it is listed in `.gitignore` and not committed.
