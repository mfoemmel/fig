package fig

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

func publish() Command {
	return &PublishCommand{}
}
