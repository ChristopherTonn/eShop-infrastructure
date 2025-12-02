using Microsoft.AspNetCore.OpenApi;
using Microsoft.Extensions.DependencyInjection;

namespace eShop.ServiceDefaults;

internal static class OpenApiOptionsExtensions
{
    public static OpenApiOptions ApplySecuritySchemeDefinitions(this OpenApiOptions options)
    {
        // NOTE: IOpenApiDocumentTransformer is only available in .NET 10+
        // Skipping security scheme registration for .NET 9 compatibility
        return options;
    }
}
