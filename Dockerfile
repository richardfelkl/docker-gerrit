FROM openjdk:8-jre-alpine

MAINTAINER zsx <thinkernel@gmail.com>

# Overridable defaults
ENV GERRIT_HOME /var/gerrit
ENV GERRIT_SITE ${GERRIT_HOME}/review_site
ENV GERRIT_WAR ${GERRIT_HOME}/gerrit.war
ENV GERRIT_VERSION 2.13.6
ENV GERRIT_USER gerrit2
ENV GERRIT_INIT_ARGS ""
ENV GOSU_VERSION 1.9
ENV PLUGIN_VERSION=stable-2.13
ENV GERRITFORGE_URL=https://gerrit-ci.gerritforge.com
ENV GERRITFORGE_ARTIFACT_DIR=lastSuccessfulBuild/artifact/buck-out/gen/plugins
ENV BOUNCY_CASTLE_VERSION 1.52
ENV BOUNCY_CASTLE_URL http://central.maven.org/maven2/org/bouncycastle
ENV MYSQL_CONNECTOR_VERSION 5.1.21

# Add our user and group first to make sure their IDs get assigned consistently, regardless of whatever dependencies get added
RUN adduser -D -h "${GERRIT_HOME}" -g "Gerrit User" -s /sbin/nologin "${GERRIT_USER}"

RUN set -x \
    && apk add --update --no-cache git openssh openssl bash perl perl-cgi git-gitweb mysql-client

# Grab gosu for easy step-down from root
RUN set -x \
    && apk add --no-cache --virtual .gosu-deps \
        dpkg \
        gnupg \
    && wget -O /usr/local/bin/gosu "https://github.com/tianon/gosu/releases/download/$GOSU_VERSION/gosu-$(dpkg --print-architecture | sed s/musl-linux-//)" \
    && wget -O /usr/local/bin/gosu.asc "https://github.com/tianon/gosu/releases/download/$GOSU_VERSION/gosu-$(dpkg --print-architecture  | sed s/musl-linux-//).asc" \
    && export GNUPGHOME="$(mktemp -d)" \
    && gpg --keyserver ha.pool.sks-keyservers.net --recv-keys B42F6819007F00F88E364FD4036A9C25BF357DD4 \
    && gpg --batch --verify /usr/local/bin/gosu.asc /usr/local/bin/gosu \
    && rm -r "$GNUPGHOME" /usr/local/bin/gosu.asc \
    && chmod +x /usr/local/bin/gosu \
    && gosu nobody true \
    && apk del .gosu-deps

RUN mkdir /docker-entrypoint-init.d

#Download gerrit.war TEMPORARY URL for fix with iframe
RUN wget https://www.gerritcodereview.com/download/gerrit-${GERRIT_VERSION}.war -O $GERRIT_WAR
#Only for local test
#COPY gerrit-${GERRIT_VERSION}.war $GERRIT_WAR

#Download Plugins
#delete-project
RUN wget \
    ${GERRITFORGE_URL}/job/plugin-delete-project-${PLUGIN_VERSION}/${GERRITFORGE_ARTIFACT_DIR}/delete-project/delete-project.jar \
    -O ${GERRIT_HOME}/delete-project.jar

#events-log
#This plugin is required by gerrit-trigger plugin of Jenkins.
RUN wget \
    ${GERRITFORGE_URL}/job/plugin-events-log-stable-2.12/${GERRITFORGE_ARTIFACT_DIR}/events-log/events-log.jar \
    -O ${GERRIT_HOME}/events-log.jar

#oauth2 plugin
RUN wget \
    ${GERRITFORGE_URL}/job/plugin-oauth-${PLUGIN_VERSION}/${GERRITFORGE_ARTIFACT_DIR}/oauth/oauth.jar \
    -O ${GERRIT_HOME}/gerrit-oauth-provider.jar

#download bouncy castle
RUN wget \
    ${BOUNCY_CASTLE_URL}/bcprov-jdk15on/${BOUNCY_CASTLE_VERSION}/bcprov-jdk15on-${BOUNCY_CASTLE_VERSION}.jar \
    -O ${GERRIT_HOME}/bcprov-jdk15on-${BOUNCY_CASTLE_VERSION}.jar

RUN wget \
    ${BOUNCY_CASTLE_URL}/bcpkix-jdk15on/${BOUNCY_CASTLE_VERSION}/bcpkix-jdk15on-${BOUNCY_CASTLE_VERSION}.jar \
    -O ${GERRIT_HOME}/bcpkix-jdk15on-${BOUNCY_CASTLE_VERSION}.jar

RUN wget \
    https://repo1.maven.org/maven2/mysql/mysql-connector-java/${MYSQL_CONNECTOR_VERSION}/mysql-connector-java-${MYSQL_CONNECTOR_VERSION}.jar  \
    -O ${GERRIT_HOME}/mysql-connector-java-${MYSQL_CONNECTOR_VERSION}.jar

# Ensure the entrypoint scripts are in a fixed location
COPY gerrit-entrypoint.sh /
COPY gerrit-start.sh /
RUN chmod +x /gerrit*.sh

#A directory has to be created before a volume is mounted to it.
#So gerrit user can own this directory.
RUN gosu ${GERRIT_USER} mkdir -p $GERRIT_SITE

#Gerrit site directory is a volume, so configuration and repositories
#can be persisted and survive image upgrades.
VOLUME $GERRIT_SITE

#Copy custom gerrit theme css
COPY GerritSite.css /tmp/

ENTRYPOINT ["/gerrit-entrypoint.sh"]

EXPOSE 8080 29418

CMD ["/gerrit-start.sh"]
