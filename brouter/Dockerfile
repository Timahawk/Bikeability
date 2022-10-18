FROM ubuntu:latest

RUN apt-get update
# RUN apt-get install -y wget
RUN apt-get install -y git
RUN apt-get install -y gradle

WORKDIR /var/www/

RUN git clone https://github.com/abrensch/brouter.git

WORKDIR "/var/www/brouter"

RUN ./gradlew clean build

RUN mkdir /var/www/brouter/misc/segments4

# ADD ./segments4 /var/www/brouter/misc/segments4

# E5_N45 -> Karlsruhe
# E10_N45 -> Augsburg
# E_10_N55 -> Kopenhagen
# RUN wget -O /var/www/brouter/misc/segments4/E5_N50.rd5  http://brouter.de/brouter/segments4/E5_N50.rd5

RUN chmod +x  /var/www/brouter/misc/scripts/standalone/server.sh

CMD ./misc/scripts/standalone/server.sh

EXPOSE 17777