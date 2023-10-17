FROM alpine:latest

COPY ./apigee-remote-service-envoy /apigee-remote-service-envoy
COPY ./config.yaml /config.yaml
COPY ./runit /runit
RUN chmod 755 /runit

CMD ["/runit"] #/apigee-remote-service-envoy -c /config.yaml -l $DEBUG
