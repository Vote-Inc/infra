FROM nginx:1.27-alpine
COPY limits.conf  /etc/nginx/conf.d/limits.conf
COPY nginx.conf   /etc/nginx/conf.d/default.conf

RUN rm -f /etc/nginx/conf.d/default.conf.bak
