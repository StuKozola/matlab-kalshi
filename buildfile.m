function plan = buildfile
%buildfile Build tasks for matlab-kalshi.

    plan = buildplan(localfunctions);
    plan.DefaultTasks = "test";
end

function testTask(~)
%testTask Run MATLAB unit tests.

    addpath("src");
    results = runtests("tests");
    assertSuccess(results);
end

function integrationTestTask(~)
%integrationTestTask Run live Kalshi integration tests when explicitly enabled.

    addpath("src");
    assert(strcmpi(getenv("KALSHI_RUN_INTEGRATION"), "true"), ...
        "Set KALSHI_RUN_INTEGRATION=true before running live integration tests.");
    results = runtests(fullfile("tests", "integration"));
    assertSuccess(results);
end
