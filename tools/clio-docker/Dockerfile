FROM mcr.microsoft.com/dotnet/sdk:8.0


RUN dotnet tool install -g clio \
 && ln -s /root/.dotnet/tools/clio /usr/local/bin/clio

WORKDIR /work
ENTRYPOINT ["clio"]
CMD ["-h"]
