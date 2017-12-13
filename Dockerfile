FROM ruby:2.4.2

RUN apt-get update && \
    apt-get install -y apt-transport-https unzip

RUN echo "deb [arch=amd64] https://packages.microsoft.com/repos/azure-cli/ wheezy main" | \
     tee /etc/apt/sources.list.d/azure-cli.list && \
    apt-key adv --keyserver packages.microsoft.com --recv-keys 52E16F86FEE04B979B07E28DB02C46DF417A0893 && \
    apt-get update && \
    apt-get install -y azure-cli

RUN curl -L -o terraform.zip https://releases.hashicorp.com/terraform/0.11.0/terraform_0.11.0_linux_amd64.zip  && \
    unzip terraform.zip && rm terraform.zip && \
    mv terraform /usr/bin/terraform

ADD Gemfile /
ADD terrafying.gemspec /
ADD lib /lib
ADD bin /bin

RUN bundle install
