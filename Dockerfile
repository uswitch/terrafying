FROM ruby:2.4-alpine3.7

RUN apk --update add --no-cache --virtual .azure-builddeps build-base python2-dev \
 && apk add --no-cache --virtual .azure-rundeps python2 py-setuptools py2-pip bash \
 && pip install --no-cache-dir azure-cli-profile azure-cli-role \
 && pip install --no-cache-dir --no-deps azure-cli \
 && apk del .azure-builddeps \
 && rm -rf /var/cache/apk/*

RUN wget -O terraform.zip https://releases.hashicorp.com/terraform/0.11.2/terraform_0.11.2_linux_amd64.zip \
 && unzip terraform.zip \
 && install -m 755 terraform /usr/bin/terraform \
 && install -d ${HOME}/.terraform.d/plugins/linux_amd64 \
 && rm terraform terraform.zip

RUN wget -O terraform-provider-aws https://github.com/uswitch/terraform-provider-aws/releases/download/private-link/terraform-provider-aws \
 && install -m 755 terraform-provider-aws /root/.terraform.d/plugins/linux_amd64/terraform-provider-aws_v1.7.0 \
 && rm terraform-provider-aws

RUN wget -O terraform-provider-acme.zip https://github.com/paybyphone/terraform-provider-acme/releases/download/v0.4.0/terraform-provider-acme_v0.4.0_linux_amd64.zip \
 && unzip terraform-provider-acme.zip \
 && install -m 755 terraform-provider-acme /root/.terraform.d/plugins/linux_amd64/terraform-provider-acme_v0.4.0 \
 && rm terraform-provider-acme terraform-provider-acme.zip

COPY . /usr/src/app

RUN apk add --update --no-cache --virtual .terra-builddeps build-base ruby-dev \
 && apk add --update --no-cache --virtual .terra-rundeps git \
 && cd /usr/src/app \
 && bundle install \
 && install -d /terra \
 && apk del .terra-builddeps \
 && rm -rf /var/cache/apk/*

WORKDIR /terra

CMD ["help"]
ENTRYPOINT ["/usr/src/app/bin/entrypoint.sh"]
