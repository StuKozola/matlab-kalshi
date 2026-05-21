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
