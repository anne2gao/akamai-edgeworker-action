FROM akamai/shell

LABEL "com.github.actions.name"="Akamai Edgeworkers"
LABEL "com.github.actions.description"="Deploy Edgeworkers via the Akamai API's"
LABEL "com.github.actions.icon"="cloud-lightning"
LABEL "com.github.actions.color"="orange"

LABEL version="0.1.0"
LABEL repository="https://github.com/cantire-corp/akamai-edgeworker-action"
LABEL homepage=""
LABEL maintainer="Anne Gao <anne.gao@cantire.com>"

ADD entrypoint.sh /entrypoint.sh
RUN chmod +x /entrypoint.sh
ENTRYPOINT ["/entrypoint.sh"]
