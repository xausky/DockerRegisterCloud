FROM debian
COPY drcd /
COPY entrypoint.sh /
COPY web /build/web
RUN chmod +x /entrypoint.sh
EXPOSE 3000
ENTRYPOINT ["sh","-c","/entrypoint.sh"]