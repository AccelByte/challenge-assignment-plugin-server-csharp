// Copyright (c) 2023-2025 AccelByte Inc. All Rights Reserved.
// This is licensed software from AccelByte Inc, for limitations
// and restrictions contact your company contract manager.

using System;
using Microsoft.Extensions.Configuration;

using AccelByte.Sdk.Core.Logging;
using AccelByte.Sdk.Core.Repository;

namespace AccelByte.PluginArch.ChallengeAssignment.Demo.Server
{
    public class AppSettingConfigRepository : IConfigRepository
    {
        public string BaseUrl { get; set; } = "";

        public string ClientId { get; set; } = "";

        public string ClientSecret { get; set; } = "";

        public string AppName { get; set; } = "";

        public string TraceIdVersion { get; set; } = "";

        public string Namespace { get; set; } = "";

        public bool EnableTraceId { get; set; } = false;

        public bool EnableUserAgentInfo { get; set; } = false;

        public string ResourceName { get; set; } = "";

        public string ServiceName { get; set; } = "";

        public IHttpLogger? Logger { get; set; } = null;

        public void ReadEnvironmentVariables()
        {
            string? abBaseUrl = Environment.GetEnvironmentVariable("AB_BASE_URL");
            if ((abBaseUrl != null) && (abBaseUrl.Trim() != ""))
                BaseUrl = abBaseUrl.Trim();

            string? abClientId = Environment.GetEnvironmentVariable("AB_CLIENT_ID");
            if ((abClientId != null) && (abClientId.Trim() != ""))
                ClientId = abClientId.Trim();

            string? abClientSecret = Environment.GetEnvironmentVariable("AB_CLIENT_SECRET");
            if ((abClientSecret != null) && (abClientSecret.Trim() != ""))
                ClientSecret = abClientSecret.Trim();

            string? abNamespace = Environment.GetEnvironmentVariable("AB_NAMESPACE");
            if ((abNamespace != null) && (abNamespace.Trim() != ""))
                Namespace = abNamespace.Trim();

            string? appServiceName = Environment.GetEnvironmentVariable("OTEL_SERVICE_NAME");
            if (appServiceName == null)
                ServiceName = "extend-app-challenge-assignment";
            else
                ServiceName = $"extend-app-{appServiceName.Trim().ToLower()}";

            string? appResourceName = Environment.GetEnvironmentVariable("APP_RESOURCE_NAME");
            if (appResourceName == null)
                appResourceName = "CHALLENGEASGEXTENDAPP";
            ResourceName = appResourceName;            
        }
    }
}
