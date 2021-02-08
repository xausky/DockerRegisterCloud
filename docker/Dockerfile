FROM debian:stable
RUN apt-get update && apt-get install -y ca-certificates
COPY entrypoint.sh /
RUN chmod +x /entrypoint.sh
COPY drcd /
COPY web /build/web
EXPOSE 3000
ENTRYPOINT ["sh", "-c", "/entrypoint.sh"]
