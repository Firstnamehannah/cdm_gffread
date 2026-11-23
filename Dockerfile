# =============================================================================
# CTS Tool Skeleton — Dockerfile
# =============================================================================
#
# OPTION A: Wrap an existing public image (preferred when one exists)
#
#   FROM public-registry/tool-name:version
#   ENTRYPOINT ["tool-command"]
#
# OPTION B: Build from scratch
#
#   FROM ubuntu:24.04 AS build
#   RUN apt-get update && apt-get install -y wget
#   RUN wget https://example.com/tool-v1.0.tar.gz && tar xzf tool-v1.0.tar.gz
#
#   FROM ubuntu:24.04
#   COPY --from=build /tool /usr/local/bin/tool
#   ENTRYPOINT ["tool"]
#
# CTS CONTAINER REQUIREMENTS:
#   - Must be publicly accessible (no auth)
#   - Must run as non-root
#   - Must have /bin/bash
#   - Must define ENTRYPOINT
#   - Must write ALL output to the output_mount_point only (/out by default)
#   - Must NOT download external files at runtime
#   - Must NOT hardlink between input and output directories
#
# =============================================================================

# Option A: wrap the WILDS image used by the ww-gffread module.
FROM getwilds/gffread:0.12.7@sha256:ea407cbb15265e4f5d56c9e18673d0e248752e5969638c0c4786567c95a506ce 

# The module's tasks are two commands each (awk filter, then gffread); CTS runs one.
COPY gtf_prep.sh /usr/local/bin/gtf_prep
RUN chmod 755 /usr/local/bin/gtf_prep

# CTS requires non-root. Ubuntu 24.04 already has uid 1000 ("ubuntu"), so reuse it.
# CTS only allows writes to /out and temp, so HOME points at /tmp.
RUN id -u 1000 >/dev/null 2>&1 || useradd --create-home --uid 1000 cts
ENV HOME=/tmp
WORKDIR /tmp
USER 1000

ENTRYPOINT ["gtf_prep"]

