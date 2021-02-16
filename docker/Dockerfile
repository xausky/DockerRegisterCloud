FROM debian:stable
RUN apt-get update && apt-get install -y ca-certificates
COPY drcd /
COPY entrypoint.sh /
COPY web /build/web
RUN chmod +x /entrypoint.sh
RUN chmod +x /drcd
EXPOSE 3000
ENTRYPOINT ["sh", "-c", "/entrypoint.sh"]
