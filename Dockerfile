FROM ruby:2.4.2

RUN apt-get update && apt-get install unzip

RUN curl -L -o terraform.zip https://releases.hashicorp.com/terraform/0.10.8/terraform_0.10.8_linux_amd64.zip  && \
    unzip terraform.zip && rm terraform.zip && \
    mv terraform /usr/bin/terraform

ADD Gemfile /
ADD terrafying.gemspec /
ADD lib /lib
ADD bin /bin

RUN bundle install
