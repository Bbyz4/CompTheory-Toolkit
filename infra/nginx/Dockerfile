FROM nginx:1.27-alpine

RUN mkdir -p /opt/recognita-nginx /etc/nginx/certs

COPY infra/nginx/default.http.conf.template /opt/recognita-nginx/default.http.conf.template
COPY infra/nginx/default.tls.conf.template /opt/recognita-nginx/default.tls.conf.template
COPY infra/nginx/docker-entrypoint.d/19-select-nginx-template.sh /docker-entrypoint.d/19-select-nginx-template.sh

RUN chmod 755 /docker-entrypoint.d/19-select-nginx-template.sh
