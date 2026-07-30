FROM ruby:3.4.8-alpine3.23 AS builder

ARG TERRAFYING_VERSION=0.0.0

RUN wget -O terraform.zip https://releases.hashicorp.com/terraform/0.11.14/terraform_0.11.14_linux_amd64.zip \
 && unzip terraform.zip \
 && install -m 755 terraform /usr/bin/terraform \
 && install -d ${HOME}/.terraform.d/plugins/linux_amd64 \
 && rm terraform terraform.zip

COPY pkg /tmp

RUN apk add --update --no-cache --virtual .terra-builddeps build-base ruby-dev
RUN apk add --update --no-cache --virtual .terra-rundeps git bash
RUN gem install --install-dir /opt/gems --bindir /opt/gems/bin /tmp/terrafying-${TERRAFYING_VERSION}.gem
RUN install -d /terra
RUN apk del .terra-builddeps
RUN rm -rf /var/cache/apk/*

FROM dhi.io/ruby:3.4-alpine3.23

ENV GEM_HOME=/opt/gems GEM_PATH=/opt/gems PATH=/opt/gems/bin:$PATH HOME=/terra

COPY --from=builder /usr/bin/terraform /usr/bin/terraform
COPY --from=builder --chown=65532:65532 /root/.terraform.d /terra/.terraform.d
COPY --from=builder /opt/gems /opt/gems
COPY --from=builder --chown=65532:65532 /terra /terra

WORKDIR /terra

ENTRYPOINT []
CMD ["ruby", "/opt/gems/bin/terrafying"]
