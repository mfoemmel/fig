package fig

import "testing"

func TestListArgs(t *testing.T) {
	checkArgs(t, "fig list", list())
}

func TestListExecuteNoPackages(t *testing.T) {
	ctx, out, _ := NewTestContext()
	list().Execute(ctx)
	if out.String() != "" {
		t.Fatalf("expected empty list, got: %s", out.String())
	}
}

func TestListExecuteOnePackage(t *testing.T) {
	ctx, out, _ := NewTestContext()
	WritePackage(ctx.repo, NewPackageBuilder("foo", "1.2.3").Build())
	list().Execute(ctx)
	expected := "foo/1.2.3\n"
	if out.String() != expected {
		t.Fatalf("expected: %s, got: %s", expected, out.String())
	}
}

func list() Command {
	return &ListCommand{}
}
