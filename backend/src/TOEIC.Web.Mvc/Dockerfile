FROM mcr.microsoft.com/dotnet/sdk:8.0 AS build

RUN dotnet tool install -g Microsoft.Web.LibraryManager.Cli
RUN ln -s ~/.dotnet/tools/libman /usr/local/bin/libman

WORKDIR /src
COPY ["src/TOEIC.Web.Mvc/TOEIC.Web.Mvc.csproj", "src/TOEIC.Web.Mvc/"]
COPY ["src/TOEIC.Web.Core/TOEIC.Web.Core.csproj", "src/TOEIC.Web.Core/"]
COPY ["src/TOEIC.Application/TOEIC.Application.csproj", "src/TOEIC.Application/"]
COPY ["src/TOEIC.Core/TOEIC.Core.csproj", "src/TOEIC.Core/"]
COPY ["src/TOEIC.EntityFrameworkCore/TOEIC.EntityFrameworkCore.csproj", "src/TOEIC.EntityFrameworkCore/"]
WORKDIR "/src/src/TOEIC.Web.Mvc"
RUN dotnet restore 

WORKDIR /src
COPY ["src/TOEIC.Web.Mvc", "src/TOEIC.Web.Mvc"]
COPY ["src/TOEIC.Web.Core", "src/TOEIC.Web.Core"]
COPY ["src/TOEIC.Application", "src/TOEIC.Application"]
COPY ["src/TOEIC.Core", "src/TOEIC.Core"]
COPY ["src/TOEIC.EntityFrameworkCore", "src/TOEIC.EntityFrameworkCore"]
WORKDIR "/src/src/TOEIC.Web.Mvc"
RUN libman restore
RUN dotnet publish -c Release -o /publish --no-restore

FROM mcr.microsoft.com/dotnet/aspnet:8.0
EXPOSE 80
WORKDIR /app
COPY --from=build /publish .
ENTRYPOINT ["dotnet", "TOEIC.Web.Mvc.dll"]
