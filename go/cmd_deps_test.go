package fig

import "testing"

func TestDepsArgs(t *testing.T) {
	checkArgs(t, "fig deps foo/1.2.3", deps("foo", "1.2.3"))
}

func TestDepsExecuteNoDeps(t *testing.T) {
	ctx, out, _ := NewTestContext()
	WritePackage(ctx.repo, NewPackageBuilder("foo", "1.2.3").Config("default").End().Build())
	deps("foo", "1.2.3").Execute(ctx)
	expected := ""
	if out.String() != expected {
		t.Fatalf("expected: %s, got: %s", expected, out.String())
	}
}

func TestDepsExecuteOneDep(t *testing.T) {
	ctx, out, _ := NewTestContext()
	WritePackage(ctx.repo,
		NewPackageBuilder("foo", "1.2.3").
			Config("default").Include("bar", "4.5.6", "default").End().
			Build())
	deps("foo", "1.2.3").Execute(ctx)
	expected := "bar/4.5.6:default\n"
	if out.String() != expected {
		t.Fatalf("expected: %s, got: %s", expected, out.String())
	}
}

func deps(packageName string, versionName string) Command {
	return &DepsCommand{NewDescriptor(packageName, versionName, "")}
}
