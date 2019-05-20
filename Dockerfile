FROM ruby:2.6.3-alpine3.9

ARG TERRAFYING_VERSION=0.0.0

RUN wget -O terraform.zip https://releases.hashicorp.com/terraform/0.11.14/terraform_0.11.14_linux_amd64.zip \
 && unzip terraform.zip \
 && install -m 755 terraform /usr/bin/terraform \
 && install -d ${HOME}/.terraform.d/plugins/linux_amd64 \
 && rm terraform terraform.zip

COPY pkg /tmp

RUN apk add --update --no-cache --virtual .terra-builddeps build-base ruby-dev \
 && apk add --update --no-cache --virtual .terra-rundeps git bash \
 && gem install /tmp/terrafying-${TERRAFYING_VERSION}.gem \
 && install -d /terra \
 && apk del .terra-builddeps \
 && rm -rf /var/cache/apk/*

WORKDIR /terra

ENTRYPOINT []
CMD ["/bin/bash"]
