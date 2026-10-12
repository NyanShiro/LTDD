FROM mcr.microsoft.com/dotnet/sdk:8.0 AS build

WORKDIR /src
COPY ["src/TOEIC.Web.Host/TOEIC.Web.Host.csproj", "src/TOEIC.Web.Host/"]
COPY ["src/TOEIC.Web.Core/TOEIC.Web.Core.csproj", "src/TOEIC.Web.Core/"]
COPY ["src/TOEIC.Application/TOEIC.Application.csproj", "src/TOEIC.Application/"]
COPY ["src/TOEIC.Core/TOEIC.Core.csproj", "src/TOEIC.Core/"]
COPY ["src/TOEIC.EntityFrameworkCore/TOEIC.EntityFrameworkCore.csproj", "src/TOEIC.EntityFrameworkCore/"]
WORKDIR "/src/src/TOEIC.Web.Host"
RUN dotnet restore 

WORKDIR /src
COPY ["src/TOEIC.Web.Host", "src/TOEIC.Web.Host"]
COPY ["src/TOEIC.Web.Core", "src/TOEIC.Web.Core"]
COPY ["src/TOEIC.Application", "src/TOEIC.Application"]
COPY ["src/TOEIC.Core", "src/TOEIC.Core"]
COPY ["src/TOEIC.EntityFrameworkCore", "src/TOEIC.EntityFrameworkCore"]
WORKDIR "/src/src/TOEIC.Web.Host"
RUN dotnet publish -c Release -o /publish --no-restore

FROM mcr.microsoft.com/dotnet/aspnet:8.0
EXPOSE 80
WORKDIR /app
COPY --from=build /publish .
ENTRYPOINT ["dotnet", "TOEIC.Web.Host.dll"]
