using System.Diagnostics;
using System.IO.Compression;
using System.Text;

// PlaywrightOfflinePackager
// 一鍵將 PlaywrightSampleApp 打包為離線 ZIP（含 self-contained .NET runtime 與 Playwright driver）。
// 使用方式: dotnet run --project src/PlaywrightOfflinePackager -- [--rid win-x64] [--config Release] [--output output]

string rid = "win-x64";
string config = "Release";
string outputDir = "output";
string sampleProject = "src/PlaywrightSampleApp/PlaywrightSampleApp.csproj";
string assetsDir = "assets";

for (var i = 0; i < args.Length; i++)
{
    switch (args[i])
    {
        case "--rid": rid = args[++i]; break;
        case "--config": config = args[++i]; break;
        case "--output": outputDir = args[++i]; break;
        case "--project": sampleProject = args[++i]; break;
        case "--assets": assetsDir = args[++i]; break;
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

Directory.CreateDirectory(outputDir);

string timestamp = DateTime.Now.ToString("yyyyMMdd-HHmmss");
string stagingRoot = Path.Combine(Path.GetTempPath(), $"playwright-offline-{timestamp}");
string appStaging = Path.Combine(stagingRoot, "app");
Directory.CreateDirectory(appStaging);

Console.WriteLine("================================================================");
Console.WriteLine(" Playwright Offline Packager");
Console.WriteLine("================================================================");
Console.WriteLine($" RID         : {rid}");
Console.WriteLine($" Config      : {config}");
Console.WriteLine($" Project     : {sampleProject}");
Console.WriteLine($" Assets      : {assetsDir}");
Console.WriteLine($" Staging     : {stagingRoot}");
Console.WriteLine($" Output dir  : {outputDir}");
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

    // STEP 4: copy assets (install.ps1, uninstall.ps1, README.txt) into staging root
    Step("Stage assets", () => CopyDirectory(assetsDir, stagingRoot, overwrite: true));

    // STEP 5: write build metadata
    Step("Write build metadata", () =>
    {
        var meta = $"""
            Playwright Offline Package
            ===========================
            Built on    : {DateTime.Now:yyyy-MM-dd HH:mm:ss zzz}
            RID         : {rid}
            Configuration: {config}
            Source      : {Path.GetFileName(sampleProject)}
            """;
        File.WriteAllText(Path.Combine(stagingRoot, "BUILD-INFO.txt"), meta);
    });

    // STEP 6: zip
    string zipName = $"PlaywrightOffline-{rid}-{timestamp}.zip";
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
    Console.WriteLine($" Output: {zipPath}");
    Console.WriteLine();
    Console.WriteLine(" Transfer this ZIP to the offline Windows machine,");
    Console.WriteLine(" extract it, then double-click '點擊兩下-install.cmd'.");
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

static void PrintHelp()
{
    Console.WriteLine("Usage: dotnet run --project src/PlaywrightOfflinePackager -- [options]");
    Console.WriteLine();
    Console.WriteLine("Options:");
    Console.WriteLine("  --rid <id>          Runtime identifier (default: win-x64)");
    Console.WriteLine("  --config <name>     Build configuration (default: Release)");
    Console.WriteLine("  --output <dir>      Output directory relative to repo root (default: output)");
    Console.WriteLine("  --project <path>    Sample project to publish (default: src/PlaywrightSampleApp/PlaywrightSampleApp.csproj)");
    Console.WriteLine("  --assets <dir>      Assets folder to bundle (default: assets)");
    Console.WriteLine("  -h, --help          Show this help");
}
