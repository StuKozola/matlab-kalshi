%% packageToolbox Package matlab-kalshi as an installable MATLAB toolbox.
% Run from the repository root with:
%   run("tools/packageToolbox.m")
%
% Requires MATLAB R2023a or later for ToolboxOptions.

repoRoot = fileparts(fileparts(mfilename("fullpath")));
toolboxName = "matlab-kalshi";
toolboxFolder = fullfile(repoRoot, "build", "toolbox", toolboxName);
outputFile = fullfile(repoRoot, "release", toolboxName + ".mltbx");
toolboxUUID = "c9b13e06-5af3-43a7-9afc-f8a3a0a7acaf";

if isfolder(toolboxFolder)
    rmdir(toolboxFolder, "s");
end

mkdir(toolboxFolder);
copyfile(fullfile(repoRoot, "src"), fullfile(toolboxFolder, "src"));
copyfile(fullfile(repoRoot, "examples"), fullfile(toolboxFolder, "examples"));
copyfile(fullfile(repoRoot, "docs"), fullfile(toolboxFolder, "docs"));
copyfile(fullfile(repoRoot, "README.md"), fullfile(toolboxFolder, "README.md"));
copyfile(fullfile(repoRoot, "AGENTS.md"), fullfile(toolboxFolder, "AGENTS.md"));

if ~isfolder(fileparts(outputFile))
    mkdir(fileparts(outputFile));
end

opts = matlab.addons.toolbox.ToolboxOptions(toolboxFolder, toolboxUUID);
opts.ToolboxName = "matlab-kalshi";
opts.ToolboxVersion = "0.1.0";
opts.AuthorName = "Stu Kozola";
opts.AuthorEmail = "stuart.kozola@gmail.com";
opts.Summary = "MATLAB interface for the Kalshi Trade API.";
opts.Description = "REST and WebSocket MATLAB client for Kalshi market data, portfolio reads, " + ...
    "demo-safe trading workflows, and toolbox packaging.";
opts.OutputFile = outputFile;
opts.ToolboxMatlabPath = fullfile(toolboxFolder, "src");
opts.MinimumMatlabRelease = "R2024b";

matlab.addons.toolbox.packageToolbox(opts);
fprintf("Toolbox packaged: %s\n", outputFile);
