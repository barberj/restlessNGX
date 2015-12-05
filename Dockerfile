FROM ficusio/openresty:latest

ADD https://releases.hashicorp.com/consul-template/0.11.1/consul-template_0.11.1_linux_amd64.zip .
RUN unzip consul-template_0.11.1_linux_amd64.zip -d /usr/local/bin

ENTRYPOINT ["consul-template"]
