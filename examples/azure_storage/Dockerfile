FROM ubuntu:18.04

RUN apt update && apt install -y wget

# Install azcopy
RUN wget -O azcopy_v10.tar.gz https://azcopyvnext.azureedge.net/release20210616/azcopy_linux_amd64_10.11.0.tar.gz \
    && tar -xf azcopy_v10.tar.gz --strip-components=1 \
    && mv azcopy /usr/local/bin/ \
    && azcopy --version
