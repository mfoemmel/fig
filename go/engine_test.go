package fig

import "bytes"
//import "os"
import "testing"

func TestShow(t *testing.T) {
	repo := NewMemoryRepository()
	WritePackage(repo, NewPackageBuilder("foo", "1.2.3").Config("default").End().Build())
	expected := 
`config default
end
`
	buf := &bytes.Buffer{}
	NewEngine(buf, repo).Show("foo", "1.2.3")
	if buf.String() != expected {
		t.Fatalf("Expected %s, got %s", expected, buf.String())
	}
}
