package fig

import "io/ioutil"
import "testing"

func TestPublishArgs(t *testing.T) {
	checkArgs(t, "fig publish", publish())
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

	expected := NewPackageBuilder("foo","1.2.3").Name("foo", "1.2.3").
		Resource("foo.txt").
		Config("default").
		Set("FOO","BAR").
		End().Build()
	checkPackageStatements(t, expected.Statements, stmts)

	archive, err := r.OpenArchive()
	if err != nil {
		t.Fatal(err)
	}
	content, err := ioutil.ReadAll(archive)
	if err != nil {
		t.Fatal(err)
	}
	if string(content) != "foo contents" {
		t.Fatalf("expected: %s, got: %s", "foo contents", content)
	}
}

func publish() Command {
	return &PublishCommand{}
}
