# Ordering.API Dockerfile
FROM mcr.microsoft.com/dotnet/aspnet:9.0 AS base
WORKDIR /app
EXPOSE 8080

FROM mcr.microsoft.com/dotnet/sdk:9.0 AS build
WORKDIR /src

# Copy project files
COPY ["src/Ordering.API/Ordering.API.csproj", "src/Ordering.API/"]
COPY ["src/Ordering.Domain/Ordering.Domain.csproj", "src/Ordering.Domain/"]
COPY ["src/Ordering.Infrastructure/Ordering.Infrastructure.csproj", "src/Ordering.Infrastructure/"]
COPY ["src/EventBus/EventBus.csproj", "src/EventBus/"]
COPY ["src/EventBusRabbitMQ/EventBusRabbitMQ.csproj", "src/EventBusRabbitMQ/"]
COPY ["src/IntegrationEventLogEF/IntegrationEventLogEF.csproj", "src/IntegrationEventLogEF/"]
COPY ["src/eShop.ServiceDefaults/eShop.ServiceDefaults.csproj", "src/eShop.ServiceDefaults/"]

# Restore dependencies
RUN dotnet restore "src/Ordering.API/Ordering.API.csproj"

# Copy source code
COPY . .
WORKDIR "/src/src/Ordering.API"

# Build
RUN dotnet build "Ordering.API.csproj" -c Release -o /app/build

FROM build AS publish
RUN dotnet publish "Ordering.API.csproj" -c Release -o /app/publish

FROM base AS final
WORKDIR /app
COPY --from=publish /app/publish .
ENTRYPOINT ["dotnet", "Ordering.API.dll"]