using System.Diagnostics;
using System.IO.Compression;
using System.Text;

// PlaywrightOfflinePackager
// 一鍵將 PlaywrightSampleApp 打包為單一離線 ZIP，內含：
//   - app/                          self-contained .NET runtime + Playwright driver
//   - nuget/                        offline NuGet feed (Microsoft.Playwright + test frameworks)
//   - setup.ps1 / install.ps1 / setup-devpack.ps1  入口腳本
//   - uninstall.ps1 / uninstall-runtime.ps1 / uninstall-devpack.ps1
// 使用方式: dotnet run --project src/PlaywrightOfflinePackager -- [--rid win-x64] [--config Release] [--output output]

string rid = "win-x64";
string config = "Release";
string outputDir = "output";
string sampleProject = "src/PlaywrightSampleApp/PlaywrightSampleApp.csproj";
string assetsDir = "assets";
string assetsDevpackDir = "assets-devpack";
string? versionOverride = null;

for (var i = 0; i < args.Length; i++)
{
    switch (args[i])
    {
        case "--rid": rid = args[++i]; break;
        case "--config": config = args[++i]; break;
        case "--output": outputDir = args[++i]; break;
        case "--project": sampleProject = args[++i]; break;
        case "--assets": assetsDir = args[++i]; break;
        case "--assets-devpack": assetsDevpackDir = args[++i]; break;
        case "--version": versionOverride = args[++i]; break;
        case "-h":
        case "--help":
            PrintHelp();
            return 0;
        default:
            Console.Error.WriteLine($"Unknown arg: {args[i]}");
            PrintHelp();
            return 2;
    }
}

string repoRoot = ResolveRepoRoot();
sampleProject = Path.GetFullPath(Path.Combine(repoRoot, sampleProject));
assetsDir = Path.GetFullPath(Path.Combine(repoRoot, assetsDir));
assetsDevpackDir = Path.GetFullPath(Path.Combine(repoRoot, assetsDevpackDir));
outputDir = Path.GetFullPath(Path.Combine(repoRoot, outputDir));

if (!File.Exists(sampleProject))
{
    Console.Error.WriteLine($"Sample project not found: {sampleProject}");
    return 1;
}
if (!Directory.Exists(assetsDir))
{
    Console.Error.WriteLine($"Assets folder not found: {assetsDir}");
    return 1;
}
if (!Directory.Exists(assetsDevpackDir))
{
    Console.Error.WriteLine($"Dev pack assets folder not found: {assetsDevpackDir}");
    return 1;
}

Directory.CreateDirectory(outputDir);

string packageVersion = ResolvePackageVersion(repoRoot, versionOverride);

string timestamp = DateTime.Now.ToString("yyyyMMdd-HHmmss");
string stagingRoot = Path.Combine(Path.GetTempPath(), $"playwright-offline-{timestamp}");
string appStaging = Path.Combine(stagingRoot, "app");
string nugetStaging = Path.Combine(stagingRoot, "nuget");
string devpackRestoreTmp = Path.Combine(Path.GetTempPath(), $"playwright-devpack-restore-{timestamp}");
Directory.CreateDirectory(appStaging);
Directory.CreateDirectory(nugetStaging);
Directory.CreateDirectory(devpackRestoreTmp);

Console.WriteLine("================================================================");
Console.WriteLine(" Playwright Offline Packager (runtime + dev pack, single ZIP)");
Console.WriteLine("================================================================");
Console.WriteLine($" RID            : {rid}");
Console.WriteLine($" Version        : {packageVersion}");
Console.WriteLine($" Config         : {config}");
Console.WriteLine($" Project        : {sampleProject}");
Console.WriteLine($" Assets         : {assetsDir}");
Console.WriteLine($" Dev pack assets: {assetsDevpackDir}");
Console.WriteLine($" Staging        : {stagingRoot}");
Console.WriteLine($" Output dir     : {outputDir}");
Console.WriteLine("================================================================");

try
{
    // STEP 1: dotnet restore
    Step("Restore", () => RunDotnet(repoRoot, "restore", sampleProject));

    // STEP 2: dotnet publish (self-contained)
    Step("Publish", () => RunDotnet(repoRoot,
        "publish", sampleProject,
        "-c", config,
        "-r", rid,
        "--self-contained", "true",
        "-p:PublishSingleFile=false",
        "-p:PublishReadyToRun=false",
        "-o", appStaging));

    // STEP 3: sanity check — Playwright node driver must be inside publish output
    Step("Verify Playwright driver present", () =>
    {
        var driverProbe = Path.Combine(appStaging, ".playwright", "node");
        if (!Directory.Exists(driverProbe))
            throw new InvalidOperationException(
                $"Playwright driver folder not found at '{driverProbe}'. " +
                "Microsoft.Playwright NuGet may not have copied driver assets to publish output.");
        var nodeExe = Directory.GetFiles(driverProbe, "node.exe", SearchOption.AllDirectories);
        if (nodeExe.Length == 0)
            throw new InvalidOperationException(
                "node.exe (Playwright driver host) not found under .playwright/node. " +
                "Offline package would fail at runtime.");
        Console.WriteLine($"   Found driver: {nodeExe[0]}");
    });

    // STEP 4: synthesize shell project and restore the full Playwright + test-framework graph
    Step("Restore dev pack (NuGet graph)", () =>
    {
        string shellDir = Path.Combine(devpackRestoreTmp, "shell");
        Directory.CreateDirectory(shellDir);
        string shellCsproj = Path.Combine(shellDir, "shell.csproj");
        File.WriteAllText(shellCsproj, """
            <Project Sdk="Microsoft.NET.Sdk">
              <PropertyGroup>
                <TargetFramework>net10.0</TargetFramework>
                <IsPackable>false</IsPackable>
                <Nullable>enable</Nullable>
              </PropertyGroup>
              <ItemGroup>
                <PackageReference Include="Microsoft.Playwright"        Version="1.60.0" />
                <PackageReference Include="Microsoft.Playwright.NUnit"  Version="1.60.0" />
                <PackageReference Include="Microsoft.Playwright.MSTest" Version="1.60.0" />
                <PackageReference Include="Microsoft.NET.Test.Sdk"      Version="17.11.1" />
                <PackageReference Include="NUnit"                       Version="4.2.2" />
                <PackageReference Include="NUnit3TestAdapter"           Version="4.6.0" />
                <PackageReference Include="MSTest.TestFramework"        Version="3.6.4" />
                <PackageReference Include="MSTest.TestAdapter"          Version="3.6.4" />
              </ItemGroup>
            </Project>
            """);

        string packagesDir = Path.Combine(devpackRestoreTmp, "packages");
        RunDotnet(shellDir,
            "restore", shellCsproj,
            "--packages", packagesDir,
            "--runtime", rid,
            "--no-cache",
            "--verbosity", "minimal");
    });

    // STEP 5: flatten .nupkg files to <staging>/nuget/ and write INDEX.txt
    Step("Collect .nupkg files", () =>
    {
        string packagesDir = Path.Combine(devpackRestoreTmp, "packages");
        if (!Directory.Exists(packagesDir))
            throw new InvalidOperationException($"Packages dir missing after restore: {packagesDir}");

        var nupkgs = Directory.GetFiles(packagesDir, "*.nupkg", SearchOption.AllDirectories);
        if (nupkgs.Length == 0)
            throw new InvalidOperationException("Restore completed but produced zero .nupkg files.");

        var collected = new SortedSet<string>(StringComparer.OrdinalIgnoreCase);
        foreach (var src in nupkgs)
        {
            var name = Path.GetFileName(src);
            if (collected.Add(name))
            {
                File.Copy(src, Path.Combine(nugetStaging, name), overwrite: true);
            }
        }
        var index = new StringBuilder();
        index.AppendLine("# Playwright Offline Dev Pack — bundled .nupkg files");
        index.AppendLine($"# Generated: {DateTime.Now:yyyy-MM-dd HH:mm:ss zzz}");
        index.AppendLine($"# PackageVersion: {packageVersion}");
        index.AppendLine($"# Count: {collected.Count}");
        foreach (var n in collected) index.AppendLine(n);
        File.WriteAllText(Path.Combine(nugetStaging, "INDEX.txt"), index.ToString());
        Console.WriteLine($"   Collected {collected.Count} unique .nupkg files.");
    });

    // STEP 6: copy assets (setup.ps1, install.ps1, uninstall*, README.txt, cmd wrappers) into staging root
    Step("Stage runtime assets", () => CopyDirectory(assetsDir, stagingRoot, overwrite: true));

    // STEP 7: copy dev pack assets (setup-devpack.ps1, uninstall-devpack.ps1) into staging root
    Step("Stage dev pack assets", () => CopyDirectory(assetsDevpackDir, stagingRoot, overwrite: true));

    // STEP 8: write build metadata
    Step("Write build metadata", () =>
    {
        var meta = $"""
            Playwright Offline Package (runtime + dev pack)
            ================================================
            Version     : {packageVersion}
            Built on    : {DateTime.Now:yyyy-MM-dd HH:mm:ss zzz}
            RID         : {rid}
            Configuration: {config}
            Source      : {Path.GetFileName(sampleProject)}
            Contents    : app/ (runtime), nuget/ (offline NuGet feed)
            """;
        File.WriteAllText(Path.Combine(stagingRoot, "BUILD-INFO.txt"), meta);
        File.WriteAllText(Path.Combine(stagingRoot, "VERSION.txt"), packageVersion + Environment.NewLine);
    });

    // STEP 9: zip
    string zipName = $"PlaywrightOffline-v{packageVersion}-{rid}-{timestamp}.zip";
    string zipPath = Path.Combine(outputDir, zipName);
    Step("Create ZIP", () =>
    {
        if (File.Exists(zipPath)) File.Delete(zipPath);
        ZipFile.CreateFromDirectory(stagingRoot, zipPath, CompressionLevel.Optimal, includeBaseDirectory: false, Encoding.UTF8);
        var size = new FileInfo(zipPath).Length;
        Console.WriteLine($"   ZIP size: {FormatBytes(size)}");
    });

    Console.WriteLine();
    Console.WriteLine("================================================================");
    Console.WriteLine(" SUCCESS");
    Console.WriteLine("================================================================");
    Console.WriteLine($" ZIP : {zipPath}");
    Console.WriteLine();
    Console.WriteLine(" Transfer this ZIP to the offline Windows machine,");
    Console.WriteLine(" extract it, then double-click '點擊兩下-setup.cmd'");
    Console.WriteLine(" to install runtime + dev pack in one shot.");
    return 0;
}
catch (Exception ex)
{
    Console.Error.WriteLine();
    Console.Error.WriteLine("================================================================");
    Console.Error.WriteLine(" FAILED");
    Console.Error.WriteLine("================================================================");
    Console.Error.WriteLine(ex.Message);
    return 1;
}
finally
{
    try
    {
        if (Directory.Exists(stagingRoot))
            Directory.Delete(stagingRoot, recursive: true);
    }
    catch (Exception cleanupEx)
    {
        Console.Error.WriteLine($"(Warning) Could not clean staging '{stagingRoot}': {cleanupEx.Message}");
    }
    try
    {
        if (Directory.Exists(devpackRestoreTmp))
            Directory.Delete(devpackRestoreTmp, recursive: true);
    }
    catch (Exception cleanupEx)
    {
        Console.Error.WriteLine($"(Warning) Could not clean devpack restore tmp '{devpackRestoreTmp}': {cleanupEx.Message}");
    }
}

static void Step(string name, Action body)
{
    Console.WriteLine();
    Console.WriteLine($"[STEP] {name}");
    var sw = Stopwatch.StartNew();
    body();
    sw.Stop();
    Console.WriteLine($"   ✓ done in {sw.Elapsed.TotalSeconds:F1}s");
}

static void RunDotnet(string cwd, params string[] arguments)
{
    var psi = new ProcessStartInfo("dotnet")
    {
        WorkingDirectory = cwd,
        UseShellExecute = false,
        RedirectStandardOutput = false,
        RedirectStandardError = false,
    };
    foreach (var a in arguments) psi.ArgumentList.Add(a);

    Console.WriteLine($"   $ dotnet {string.Join(' ', arguments)}");
    using var proc = Process.Start(psi)
        ?? throw new InvalidOperationException("Failed to start dotnet process.");
    proc.WaitForExit();
    if (proc.ExitCode != 0)
        throw new InvalidOperationException($"dotnet exited with code {proc.ExitCode}.");
}

static void CopyDirectory(string source, string destination, bool overwrite)
{
    Directory.CreateDirectory(destination);
    foreach (var file in Directory.GetFiles(source))
    {
        var target = Path.Combine(destination, Path.GetFileName(file));
        File.Copy(file, target, overwrite);
    }
    foreach (var sub in Directory.GetDirectories(source))
    {
        var targetSub = Path.Combine(destination, Path.GetFileName(sub));
        CopyDirectory(sub, targetSub, overwrite);
    }
}

static string ResolveRepoRoot()
{
    var dir = new DirectoryInfo(AppContext.BaseDirectory);
    while (dir is not null)
    {
        if (File.Exists(Path.Combine(dir.FullName, "ferry-playwright.sln"))
         || File.Exists(Path.Combine(dir.FullName, "ferry-playwright.slnx")))
            return dir.FullName;
        dir = dir.Parent;
    }
    // Fallback: current working dir
    return Directory.GetCurrentDirectory();
}

static string FormatBytes(long bytes)
{
    string[] units = { "B", "KB", "MB", "GB" };
    double size = bytes;
    int u = 0;
    while (size >= 1024 && u < units.Length - 1) { size /= 1024; u++; }
    return $"{size:F2} {units[u]}";
}

static string ResolvePackageVersion(string repoRoot, string? overrideVersion)
{
    static string Sanitize(string s)
    {
        s = s.Trim();
        if (s.StartsWith("v", StringComparison.OrdinalIgnoreCase)) s = s.Substring(1);
        return s;
    }

    if (!string.IsNullOrWhiteSpace(overrideVersion))
        return Sanitize(overrideVersion);

    var env = Environment.GetEnvironmentVariable("PACKAGE_VERSION");
    if (!string.IsNullOrWhiteSpace(env))
        return Sanitize(env);

    try
    {
        var psi = new ProcessStartInfo("git")
        {
            WorkingDirectory = repoRoot,
            UseShellExecute = false,
            RedirectStandardOutput = true,
            RedirectStandardError = true,
        };
        psi.ArgumentList.Add("describe");
        psi.ArgumentList.Add("--tags");
        psi.ArgumentList.Add("--always");
        psi.ArgumentList.Add("--dirty");
        using var p = Process.Start(psi);
        if (p is not null)
        {
            var output = p.StandardOutput.ReadToEnd().Trim();
            p.WaitForExit();
            if (p.ExitCode == 0 && !string.IsNullOrWhiteSpace(output))
                return Sanitize(output);
        }
    }
    catch
    {
        // git not available — fall through
    }

    return "0.0.0-dev";
}

static void PrintHelp()
{
    Console.WriteLine("Usage: dotnet run --project src/PlaywrightOfflinePackager -- [options]");
    Console.WriteLine();
    Console.WriteLine("Options:");
    Console.WriteLine("  --rid <id>              Runtime identifier (default: win-x64)");
    Console.WriteLine("  --config <name>         Build configuration (default: Release)");
    Console.WriteLine("  --output <dir>          Output directory relative to repo root (default: output)");
    Console.WriteLine("  --project <path>        Sample project to publish");
    Console.WriteLine("                          (default: src/PlaywrightSampleApp/PlaywrightSampleApp.csproj)");
    Console.WriteLine("  --assets <dir>          Runtime assets folder (default: assets)");
    Console.WriteLine("  --assets-devpack <dir>  Dev pack assets folder (default: assets-devpack)");
    Console.WriteLine("  --version <semver>      Package version stamped into VERSION.txt / BUILD-INFO.txt");
    Console.WriteLine("                          (default: $PACKAGE_VERSION env > git describe > 0.0.0-dev)");
    Console.WriteLine("  -h, --help              Show this help");
    Console.WriteLine();
    Console.WriteLine("Produces a single ZIP combining runtime + offline NuGet dev pack.");
}
