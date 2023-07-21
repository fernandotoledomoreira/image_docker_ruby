FROM ruby:2.7
WORKDIR /image-linux-ruby-backend-qa
COPY . /image-linux-ruby-backend-qa

RUN wget -q https://github.com/allure-framework/allure2/releases/download/2.19.0/allure-2.19.0.tgz
RUN tar -zxvf allure-2.19.0.tgz -C /opt/
RUN ln -s /opt/allure-2.19.0/bin/allure /usr/bin/allure

RUN apt update
RUN apt install -y vim
RUN apt install -y python3-pip
RUN apt install -y bash
RUN apt install -y awscli
RUN apt install -y git
RUN apt install -y default-jre

RUN apt-get install -y tzdata
ENV TZ America/Sao_Paulo

RUN mkdir /root/.ssh/
ADD keygit /root/.ssh/id_rsa
RUN touch /root/.ssh/known_hosts && chmod 600 /root/.ssh/id_rsa
RUN ssh-keyscan github.com >> /root/.ssh/known_hosts

RUN bundle install
RUN chmod 777 -R /image-linux-ruby-backend-qa
