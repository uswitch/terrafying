FROM ruby:2.4

RUN apt-get update \
    && apt-get install -y apt-transport-https unzip \
    && echo "deb [arch=amd64] https://packages.microsoft.com/repos/azure-cli/ wheezy main" | tee /etc/apt/sources.list.d/azure-cli.list \
    && apt-key adv --keyserver packages.microsoft.com --recv-keys 52E16F86FEE04B979B07E28DB02C46DF417A0893 \
    && apt-get update \
    && apt-get install -y azure-cli \
    && apt-get autoremove -y \
    && rm -rf /var/lib/apt/lists/* \
    && rm -rf /tmp/* /var/tmp/* \
    && mkdir -p /usr/src/app

RUN curl -L -o terraform.zip https://releases.hashicorp.com/terraform/0.11.1/terraform_0.11.1_linux_amd64.zip  && \
    unzip terraform.zip && rm terraform.zip && \
    mv terraform /usr/bin/terraform

RUN mkdir -p /root/.terraform.d/plugins/linux_amd64

RUN curl -L -o terraform-provider-acme.zip https://github.com/paybyphone/terraform-provider-acme/releases/download/v0.4.0/terraform-provider-acme_v0.4.0_linux_amd64.zip && \
    unzip terraform-provider-acme.zip && rm terraform-provider-acme.zip && \
    mv terraform-provider-acme /root/.terraform.d/plugins/linux_amd64/terraform-provider-acme_v0.4.0 && \
    chmod +x /root/.terraform.d/plugins/linux_amd64/terraform-provider-acme_v0.4.0

RUN curl -L -o /root/.terraform.d/plugins/linux_amd64/terraform-provider-aws_v1.7.0 \
    https://github.com/uswitch/terraform-provider-aws/releases/download/private-link/terraform-provider-aws && \
    chmod +x /root/.terraform.d/plugins/linux_amd64/terraform-provider-aws_v1.7.0

COPY . /usr/src/app
WORKDIR /usr/src/app

RUN bundle install

CMD ["bash"]
ENTRYPOINT []
