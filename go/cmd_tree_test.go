package fig

import "testing"
//import "os"

func TestTreeArgs(t *testing.T) {
	checkArgs(t, "fig tree foo/1.2.3:default", tree("foo","1.2.3","default"))
}

func TestTree(t *testing.T) {
	ctx, out, _ := NewTestContext()
	WriteRawPackage(ctx.repo, "foo", "1.2.3",`
config default
  include bar/4.5.6
  include baz/4.5.6:runtime
end
`)
	WriteRawPackage(ctx.repo, "bar", "4.5.6", `
config default
  include util/7.8.9
end
`)
	WriteRawPackage(ctx.repo, "baz", "4.5.6", `
config runtime
  include util/7.8.9
end
`)
	WriteRawPackage(ctx.repo, "util", "7.8.9", `
config default
  include :other
end
config other
end
`)

	tree("foo","1.2.3","default").Execute(ctx)
	expected := 
`foo/1.2.3:default
  bar/4.5.6
    util/7.8.9
      :other
  baz/4.5.6:runtime
    util/7.8.9
      :other
`
	if out.String() != expected {
		t.Fatalf("expected: \n%s\n, got: \n%s\n", expected, out.String())
	}
}

func tree(packageName string, versionName string, configName string) Command {
	return &TreeCommand{NewDescriptor(packageName,versionName,configName)}
}
