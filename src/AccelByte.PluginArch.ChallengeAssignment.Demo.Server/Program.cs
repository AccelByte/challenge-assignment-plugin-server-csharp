// Copyright (c) 2024 AccelByte Inc. All Rights Reserved.
// This is licensed software from AccelByte Inc, for limitations
// and restrictions contact your company contract manager.

using System;
using System.Collections.Generic;
using System.Reflection;

using Microsoft.AspNetCore.Builder;
using Microsoft.AspNetCore.Hosting;
using Microsoft.Extensions.DependencyInjection;
using Microsoft.Extensions.Diagnostics.HealthChecks;
using Microsoft.Extensions.Configuration;

using OpenTelemetry.Resources;
using OpenTelemetry.Trace;
using OpenTelemetry.Metrics;
using OpenTelemetry.Extensions.Propagators;

using Prometheus;
using AccelByte.PluginArch.ChallengeAssignment.Demo.Server.Services;

namespace AccelByte.PluginArch.ChallengeAssignment.Demo.Server
{
    public class Program
    {
        public static int Main(string[] args)
        {
            OpenTelemetry.Sdk.SetDefaultTextMapPropagator(new B3Propagator());
            Metrics.DefaultRegistry.SetStaticLabels(new Dictionary<string, string>()
            {
                { "application", "challenge_assignment_grpcserver" }
            });

            var builder = WebApplication.CreateBuilder(args);
            builder.Configuration.AddEnvironmentVariables("ABSERVER_");
            builder.WebHost.ConfigureKestrel(opt =>
            {
                opt.AllowAlternateSchemes = true;
            });

            string? appResourceName = Environment.GetEnvironmentVariable("APP_RESOURCE_NAME");
            if (appResourceName == null)
                appResourceName = "CHALLENGEASGGRPCSERVICE";

            bool enableAuthorization = builder.Configuration.GetValue<bool>("EnableAuthorization");
            string? strEnableAuth = Environment.GetEnvironmentVariable("PLUGIN_GRPC_SERVER_AUTH_ENABLED");
            if ((strEnableAuth != null) && (strEnableAuth != String.Empty))
                enableAuthorization = (strEnableAuth.Trim().ToLower() == "true");

            builder.Services
                .AddSingleton<IAccelByteServiceProvider, DefaultAccelByteServiceProvider>()
                .AddOpenTelemetry()
                .WithTracing((traceConfig) =>
                {
                    var asVersion = Assembly.GetEntryAssembly()!.GetName().Version;
                    string version = "0.0.0";
                    if (asVersion != null)
                        version = asVersion.ToString();

                    traceConfig
                        .AddSource(appResourceName)
                        .SetResourceBuilder(ResourceBuilder.CreateDefault()
                            .AddService(appResourceName, null, version)
                            .AddTelemetrySdk())
                        .AddZipkinExporter()
                        .AddHttpClientInstrumentation()
                        .AddAspNetCoreInstrumentation();
                });

            // Additional configuration is required to successfully run gRPC on macOS.
            // For instructions on how to configure Kestrel and gRPC clients on macOS, visit https://go.microsoft.com/fwlink/?linkid=2099682

            builder.Services.AddGrpcHealthChecks()
                .AddCheck("Health", () => HealthCheckResult.Healthy());

            builder.Services.AddGrpc((opts) =>
            {
                opts.Interceptors.Add<ExceptionHandlingInterceptor>();
                opts.Interceptors.Add<DebugLoggerServerInterceptor>();
                if (enableAuthorization)
                    opts.Interceptors.Add<AuthorizationInterceptor>();
            });
            builder.Services.AddGrpcReflection();

            var app = builder.Build();
            app.UseGrpcMetrics();
            
            app.MapGrpcService<ChallengeAssignmentService>();
            app.MapGrpcReflectionService();
            app.MapGrpcHealthChecksService();
            app.MapMetrics();
            app.Run();
            return 0;
        }
    }
}