FROM ruby:2.4.2

RUN apt-get update && apt-get install unzip

RUN curl -L -o terraform.zip https://releases.hashicorp.com/terraform/0.11.0/terraform_0.11.0_linux_amd64.zip  && \
    unzip terraform.zip && rm terraform.zip && \
    mv terraform /usr/bin/terraform

ADD Gemfile /
ADD terrafying.gemspec /
ADD lib /lib
ADD bin /bin

RUN bundle install
