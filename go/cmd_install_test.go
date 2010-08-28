package fig

import "testing"

func TestInstallArgs(t *testing.T) {
	checkArgs(t, "fig install foo/1.2.3", install("foo","1.2.3"))
}

func TestInstallNoResources(t *testing.T) {
	ctx, _, _ := NewTestContext()
	WriteRawPackage(ctx.repo, "foo", "1.2.3",`
config default
  set A=B
end
`)
	install("foo","1.2.3").Execute(ctx)
	if !ctx.space.IsInstalled(PackageName("foo"), VersionName("1.2.3")) {
		t.Fatalf("expected package to be installed")
	}
}

func install(packageName string, versionName string) Command {
	return &InstallCommand{PackageName(packageName), VersionName(versionName)}
}
