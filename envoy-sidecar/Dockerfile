FROM envoyproxy/envoy:v1.27-latest

RUN mkdir /sidecar
RUN chown envoy /sidecar
COPY ./envoy.yaml /sidecar/envoy.yaml
RUN chown envoy /sidecar/envoy.yaml
COPY ./runit /runit
EXPOSE 8080

CMD ["/runit"]
