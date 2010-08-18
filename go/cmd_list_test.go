package fig

import "bytes"
import "testing"

func TestListArgs(t *testing.T) {
	checkArgs(t, "fig list", list())
}

func TestListExecuteNoPackages(t *testing.T) {
	repo := NewMemoryRepository()
	buf := &bytes.Buffer{}
	list().Execute(repo, buf)
	if buf.String() != "" {
		t.Fatalf("expected empty list, got: %s", buf.String())
	}
}

func TestListExecuteOnePackage(t *testing.T) {
	repo := NewMemoryRepository()
	WritePackage(repo, NewPackageBuilder("foo", "1.2.3").Build())	
	buf := &bytes.Buffer{}
	list().Execute(repo, buf)
	expected := "foo/1.2.3\n"
	if buf.String() != expected {
		t.Fatalf("expected: %s, got: %s", expected, buf.String())
	}
}

func list() Command {
	return &ListCommand{}
}
