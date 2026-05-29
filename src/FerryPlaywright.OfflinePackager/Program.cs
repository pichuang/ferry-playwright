using System.Diagnostics;
using System.IO.Compression;
using System.Text;

// FerryPlaywright.OfflinePackager (v0.7+)
// 將離線 NuGet feed + 三個 sample 原始碼專案打包成單一 ZIP。
//
// ZIP 內容：
//   - nuget/                        offline NuGet feed (.nupkg + INDEX.txt)
//   - samples/{hello-nunit,hello-mstest,hello-console}/  範例原始碼
//   - setup.ps1 / setup-devpack.ps1                      安裝腳本
//   - uninstall.ps1 / uninstall-devpack.ps1
//   - new-playwright-project.ps1 / NuGet.config.template
//   - README.txt / VERSION.txt / BUILD-INFO.txt
//
// 從 v0.6.0 起 ZIP 不再包含預編譯的 FerryPlaywright.SampleApp.exe；範例改成
// 提供原始碼，使用者照 samples/<name>/README.md 即可 build/test。
//
// 使用方式: dotnet run --project src/FerryPlaywright.OfflinePackager
//           -- [--rid win-x64] [--config Release] [--output output]

string rid = "win-x64";
string config = "Release";
string outputDir = "output";
string assetsDir = "assets";
string assetsDevpackDir = "assets-devpack";
string assetsSamplesDir = "assets-samples";
string? versionOverride = null;

for (var i = 0; i < args.Length; i++)
{
    switch (args[i])
    {
        case "--rid": rid = args[++i]; break;
        case "--config": config = args[++i]; break;
        case "--output": outputDir = args[++i]; break;
        case "--assets": assetsDir = args[++i]; break;
        case "--assets-devpack": assetsDevpackDir = args[++i]; break;
        case "--assets-samples": assetsSamplesDir = args[++i]; break;
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
assetsDir = Path.GetFullPath(Path.Combine(repoRoot, assetsDir));
assetsDevpackDir = Path.GetFullPath(Path.Combine(repoRoot, assetsDevpackDir));
assetsSamplesDir = Path.GetFullPath(Path.Combine(repoRoot, assetsSamplesDir));
outputDir = Path.GetFullPath(Path.Combine(repoRoot, outputDir));

foreach (var (label, path) in new[]
{
    ("assets", assetsDir),
    ("assets-devpack", assetsDevpackDir),
    ("assets-samples", assetsSamplesDir),
})
{
    if (!Directory.Exists(path))
    {
        Console.Error.WriteLine($"{label} folder not found: {path}");
        return 1;
    }
}

Directory.CreateDirectory(outputDir);

string packageVersion = ResolvePackageVersion(repoRoot, versionOverride);

string timestamp = DateTime.Now.ToString("yyyyMMdd-HHmmss");
string stagingRoot = Path.Combine(Path.GetTempPath(), $"ferry-playwright-{timestamp}");
string nugetStaging = Path.Combine(stagingRoot, "nuget");
string samplesStaging = Path.Combine(stagingRoot, "samples");
string devpackRestoreTmp = Path.Combine(Path.GetTempPath(), $"ferry-playwright-devpack-restore-{timestamp}");
Directory.CreateDirectory(nugetStaging);
Directory.CreateDirectory(samplesStaging);
Directory.CreateDirectory(devpackRestoreTmp);

Console.WriteLine("================================================================");
Console.WriteLine(" ferry-playwright Offline Packager (dev pack + sample sources)");
Console.WriteLine("================================================================");
Console.WriteLine($" RID            : {rid}");
Console.WriteLine($" Version        : {packageVersion}");
Console.WriteLine($" Config         : {config}");
Console.WriteLine($" Assets         : {assetsDir}");
Console.WriteLine($" Dev pack assets: {assetsDevpackDir}");
Console.WriteLine($" Samples        : {assetsSamplesDir}");
Console.WriteLine($" Staging        : {stagingRoot}");
Console.WriteLine($" Output dir     : {outputDir}");
Console.WriteLine("================================================================");

try
{
    // STEP 1: synthesize shell project and restore the full Playwright + test-framework graph
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
                <PackageReference Include="coverlet.collector"          Version="6.0.2" />
                <PackageReference Include="NUnit.Analyzers"             Version="4.4.0" />
                <PackageReference Include="MSTest.Analyzers"            Version="3.6.4" />
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

    // STEP 2: flatten .nupkg files to <staging>/nuget/ and write INDEX.txt
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
        index.AppendLine("# ferry-playwright Offline Dev Pack — bundled .nupkg files");
        index.AppendLine($"# Generated: {DateTime.Now:yyyy-MM-dd HH:mm:ss zzz}");
        index.AppendLine($"# PackageVersion: {packageVersion}");
        index.AppendLine($"# Count: {collected.Count}");
        foreach (var n in collected) index.AppendLine(n);
        File.WriteAllText(Path.Combine(nugetStaging, "INDEX.txt"), index.ToString());
        Console.WriteLine($"   Collected {collected.Count} unique .nupkg files.");
    });

    // STEP 3: copy assets-samples/ → staging samples/ (the three reference projects)
    Step("Stage sample projects", () =>
    {
        CopyDirectory(assetsSamplesDir, samplesStaging, overwrite: true);
        var dirs = Directory.GetDirectories(samplesStaging);
        Console.WriteLine($"   Staged {dirs.Length} sample project(s): "
            + string.Join(", ", dirs.Select(Path.GetFileName)));
    });

    // STEP 4: copy assets (setup.ps1, uninstall.ps1, README.txt, cmd wrappers, helper script)
    Step("Stage runtime assets", () => CopyDirectory(assetsDir, stagingRoot, overwrite: true));

    // STEP 5: copy dev pack assets (setup-devpack.ps1, uninstall-devpack.ps1)
    Step("Stage dev pack assets", () => CopyDirectory(assetsDevpackDir, stagingRoot, overwrite: true));

    // STEP 6: write build metadata
    Step("Write build metadata", () =>
    {
        var meta = $"""
            ferry-playwright Offline Package (dev pack + sample sources)
            ============================================================
            Version       : {packageVersion}
            Built on      : {DateTime.Now:yyyy-MM-dd HH:mm:ss zzz}
            RID           : {rid}
            Configuration : {config}
            Contents      : nuget/ (offline NuGet feed),
                            samples/ (hello-nunit, hello-mstest, hello-console)

            From v0.6.0 onward this ZIP does NOT contain a precompiled
            FerryPlaywright.SampleApp.exe. Use the sample source projects under
            samples/ as the reference for building your own offline tests.
            """;
        File.WriteAllText(Path.Combine(stagingRoot, "BUILD-INFO.txt"), meta);
        File.WriteAllText(Path.Combine(stagingRoot, "VERSION.txt"), packageVersion + Environment.NewLine);
    });

    // STEP 7: zip
    string zipName = $"ferry-playwright-v{packageVersion}-{rid}-{timestamp}.zip";
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
    Console.WriteLine(" extract it, then double-click '點擊兩下-完整安裝(推薦).cmd'");
    Console.WriteLine(" to install the dev pack. Sample source under samples/.");
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
    Console.WriteLine("Usage: dotnet run --project src/FerryPlaywright.OfflinePackager -- [options]");
    Console.WriteLine();
    Console.WriteLine("Options:");
    Console.WriteLine("  --rid <id>              Runtime identifier (default: win-x64)");
    Console.WriteLine("  --config <name>         Build configuration (default: Release)");
    Console.WriteLine("  --output <dir>          Output directory relative to repo root (default: output)");
    Console.WriteLine("  --assets <dir>          Runtime assets folder (default: assets)");
    Console.WriteLine("  --assets-devpack <dir>  Dev pack assets folder (default: assets-devpack)");
    Console.WriteLine("  --assets-samples <dir>  Sample projects folder (default: assets-samples)");
    Console.WriteLine("  --version <semver>      Package version stamped into VERSION.txt / BUILD-INFO.txt");
    Console.WriteLine("                          (default: $PACKAGE_VERSION env > git describe > 0.0.0-dev)");
    Console.WriteLine("  -h, --help              Show this help");
    Console.WriteLine();
    Console.WriteLine("Produces a single ZIP containing the offline NuGet dev pack and");
    Console.WriteLine("three reference sample projects under samples/.");
}
