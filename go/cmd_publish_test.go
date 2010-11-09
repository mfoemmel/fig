package fig

import "archive/tar"
import "compress/gzip"
import "io/ioutil"
import "os"
import "testing"
//import "fmt"

func TestPublishArgs(t *testing.T) {
	checkArgs(t, "fig publish", publish())
}

func TestPublishMissingPackageFile(t *testing.T) {
	ctx, _, err := NewTestContext()

	publish().Execute(ctx)

	expected := "File not found: package.fig\n"
	if expected != err.String() {
		t.Fatalf("expected: %s, got: %s", expected, err.String())
	}
}

func TestPublish(t *testing.T) {
	local :=
		`package foo/1.2.3
config default
  set FOO=BAR
end
`
	ctx, _, _ := NewTestContext()
	WriteFile(ctx.fs, "package.fig", []byte(local))

	publish().Execute(ctx)

	pkg, err := ReadPackage(ctx.repo, "foo", "1.2.3")
	if err != nil {
		t.Fatal(err)
	}

	expected := NewPackageBuilder("foo","1.2.3").Name("foo", "1.2.3").Config("default").Set("FOO","BAR").End().Build()

	checkPackage(t, expected, pkg)
}

func TestPublishWithResource(t *testing.T) {
	local :=
		`package foo/1.2.3
resource foo.txt
config default
  set FOO=BAR
end
`
	ctx, _, _ := NewTestContext()
	WriteFile(ctx.fs, "package.fig", []byte(local))
	WriteFile(ctx.fs, "foo.txt", []byte("foo contents"))

	publish().Execute(ctx)

	r := ctx.repo.NewPackageReader("foo", "1.2.3")
	stmts, err := r.ReadStatements()
	if err != nil {
		t.Fatal(err)
	}

	expected := NewPackageBuilder("foo", "1.2.3").Name("foo", "1.2.3").
		Resource("foo.txt").
		Config("default").
		Set("FOO", "BAR").
		End().Build()

	checkPackageStatements(t, expected.Statements, stmts)

	checkArchive(t, r, map[string]string{"foo.txt":"foo contents"})
}

/*
func TestPublishWithPathDir(t *testing.T) {
	local := 
`package foo/1.2.3
config default
  path PATH=bin
end
`
	ctx, _, _ := NewTestContext()
	WriteFile(ctx.fs, "package.fig", []byte(local))
	ctx.fs.Mkdir("bin")
	WriteFile(ctx.fs, "bin/foo", []byte("foo contents"))
	WriteFile(ctx.fs, "bin/bar", []byte("bar contents"))

	publish().Execute(ctx)

	r := ctx.repo.NewPackageReader("foo", "1.2.3")
	stmts, err := r.ReadStatements()
	if err != nil {
		t.Fatalf("error reading statements: %s", err)
	}

	expected := NewPackageBuilder("foo", "1.2.3").Name("foo", "1.2.3").
		Config("default").
		Path("PATH","bin").
		End().Build()

	checkPackageStatements(t, expected.Statements, stmts)

	checkArchive(t, r, map[string]string{"bin/foo":"bin contents","bin/bar":"bar contents"})
}
*/

func checkArchive(t *testing.T, r PackageReader, files map[string] string) {
	in, err := r.OpenArchive()
	if err != nil {
		t.Fatal(err)
	}

	zipin, err := gzip.NewReader(in)
	if err != nil {
		t.Fatal(err)
	}

	archive := tar.NewReader(zipin)

	for {
		header, err := archive.Next()
		if err == os.EOF {
			break
		}
//		println("*" + header.Name)
		if err != nil {
			t.Fatalf("archive.Next(): %s", err)
		}
		expected, ok := files[header.Name]
		if !ok {
			t.Fatalf("unexpected file in archive: %s", header.Name)
		}
		
		files[header.Name] = "", false

		actual, err := ioutil.ReadAll(archive)
		if err != nil {
			t.Fatal(err)
		}
		
		if string(actual) != expected {
			t.Fatalf("expected: '%s', got: '%s'", expected, string(actual))
		}
	}

	if len(files) != 0 {
		for path, _ := range files {
			t.Fatalf("missing file in archive: %s", path)
		}
	}
}


func publish() Command {
	return &PublishCommand{}
}
