package fig

import "bytes"
import "testing"
//import "os"

func TestTreeArgs(t *testing.T) {
	checkArgs(t, "fig tree foo/1.2.3:default", tree("foo","1.2.3","default"))
}

func TestTree(t *testing.T) {
	repo := NewMemoryRepository()
	WriteRawPackage(repo, "foo", "1.2.3",`
config default
  include bar/4.5.6
  include baz/4.5.6:runtime
end
`)
	WriteRawPackage(repo, "bar", "4.5.6", `
config default
  include util/7.8.9
end
`)
	WriteRawPackage(repo, "baz", "4.5.6", `
config runtime
  include util/7.8.9
end
`)
	WriteRawPackage(repo, "util", "7.8.9", `
config default
  include :other
end
config other
end
`)

	buf := &bytes.Buffer{}
	tree("foo","1.2.3","default").Execute(repo, buf)
	expected := 
`foo/1.2.3:default
  bar/4.5.6
    util/7.8.9
      :other
  baz/4.5.6:runtime
    util/7.8.9
      :other
`
	if buf.String() != expected {
		t.Fatalf("expected: \n%s\n, got: \n%s\n", expected, buf.String())
	}
}

func tree(packageName string, versionName string, configName string) Command {
	return &TreeCommand{NewDescriptor(packageName,versionName,configName)}
}
