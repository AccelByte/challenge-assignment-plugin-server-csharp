// Copyright (c) 2024 AccelByte Inc. All Rights Reserved.
// This is licensed software from AccelByte Inc, for limitations
// and restrictions contact your company contract manager.

using System;
using System.Collections.Generic;
using System.Linq;
using System.Text;
using System.Text.Json;
using System.Threading.Tasks;

using Microsoft.Extensions.Logging;
using Microsoft.Extensions.Configuration;

using Grpc.Core;
using AccelByte.Challenge.AssignmentFunction;

namespace AccelByte.PluginArch.ChallengeAssignment.Demo.Server.Services
{
    public class ChallengeAssignmentService : AssignmentFunction.AssignmentFunctionBase
    {
        private readonly ILogger<ChallengeAssignmentService> _Logger;

        private readonly Random _Random;

        public ChallengeAssignmentService(ILogger<ChallengeAssignmentService> logger)
        {
            _Logger = logger;
            _Random = new Random();
        }

        public override async Task<AssignmentResponse> Assign(AssignmentRequest request, ServerCallContext context)
        {
            if (request.Goals.Count == 0)
                throw new RpcException(new Status(StatusCode.InvalidArgument, "No active goals is available to be assigned"));

            var response = new AssignmentResponse();
            response.UserId = request.UserId;
            response.Namespace = request.Namespace;

            int randIdx = _Random.Next(0, request.Goals.Count);
            var theGoal = request.Goals[randIdx];
            response.AssignedGoals.Add(theGoal);

            return await Task.FromResult(response);
        }
    }
}
