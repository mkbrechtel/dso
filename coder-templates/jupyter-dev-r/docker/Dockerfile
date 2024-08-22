FROM codercom/enterprise-jupyter:ubuntu

#ENV http_proxy=http://193.197.95.183:2080
#ENV https_proxy=http://193.197.95.183:2080

ADD *.crt /usr/local/share/ca-certificates/

RUN sudo update-ca-certificates
