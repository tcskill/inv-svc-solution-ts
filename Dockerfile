FROM quay.io/ibmgaragecloud/gradle:jdk11 AS builder

WORKDIR /home/gradle
COPY . .
RUN ./gradlew assemble copyJarToServerJar --no-daemon

# Stage and thin the application 
FROM icr.io/appcafe/websphere-liberty:full-java11-openj9-ubi as staging


COPY --chown=1001:0 --from=builder /home/gradle/build/libs/server.jar \
                    /staging/fat-server.jar

RUN springBootUtility thin \
 --sourceAppPath=/staging/fat-server.jar \
 --targetThinAppPath=/staging/thin-server.jar \
 --targetLibCachePath=/staging/lib.index.cache

# Build the image
FROM icr.io/appcafe/websphere-liberty:full-java11-openj9-ubi

LABEL \
  vendor="IBM" \
  name="inventory app" \
  version="1.4" \
  summary="Example of a spring boot microservice app running in WebSphere Liberty" \
  description="This image contains a spring boot microservice app running with the WebSphere Liberty runtime."

RUN cp /opt/ibm/wlp/templates/servers/springBoot2/server.xml /config/server.xml



COPY --from=staging --chown=1001:0 /staging/lib.index.cache /lib.index.cache
COPY --from=staging --chown=1001:0 /staging/thin-server.jar \
                    /config/dropins/spring/thin-server.jar

ARG VERBOSE=true
RUN configure.sh 

