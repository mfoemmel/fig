package fig

import "bytes"
import "testing"

func TestDepsArgs(t *testing.T) {
	checkArgs(t, "fig deps foo/1.2.3", deps("foo","1.2.3"))
}

func TestDepsExecuteNoDeps(t *testing.T) {
	repo := NewMemoryRepository()
	WritePackage(repo, NewPackageBuilder("foo", "1.2.3").Config("default").End().Build())	
	buf := &bytes.Buffer{}
	deps("foo","1.2.3").Execute(repo, buf)
	expected := ""
	if buf.String() != expected {
		t.Fatalf("expected: %s, got: %s", expected, buf.String())
	}
}

func TestDepsExecuteOneDep(t *testing.T) {
	repo := NewMemoryRepository()
	WritePackage(repo, 
		NewPackageBuilder("foo", "1.2.3").
		Config("default").Include("bar","4.5.6","default").End().
		Build())	
	buf := &bytes.Buffer{}
	deps("foo","1.2.3").Execute(repo, buf)
	expected := "bar/4.5.6:default\n"
	if buf.String() != expected {
		t.Fatalf("expected: %s, got: %s", expected, buf.String())
	}
}

func deps(packageName string, versionName string) Command {
	return &DepsCommand{NewDescriptor(packageName,versionName,"")}
}
