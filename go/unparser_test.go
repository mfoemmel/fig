package fig

import "bytes"
import "testing"

func TestUnparsePackage(t *testing.T) {
	expected := 
`config default
  set FOO=BAR
end
config debug
  set DEBUG=true
end
`
	input := NewPackageBuilder("foo","1.2.3").
		Config("default").Set("FOO","BAR").End().
		Config("debug").Set("DEBUG","true").End().
		Build()

	checkUnparsePackage(t, input, expected)
}

func TestUnparseConfig(t *testing.T) {
	expected := 
`config default
  set FOO=BAR
end
`
	checkUnparseConfig(t, NewConfigBuilder("default").Set("FOO","BAR").Build(), expected)
}

func TestUnparseSetModifier(t *testing.T) {
	checkUnparseModifier(t, NewSetModifier("FOO","BAR"), "  set FOO=BAR\n")
}

func TestUnparsePathModifier(t *testing.T) {
	checkUnparseModifier(t, NewPathModifier("FOO","BAR"), "  path FOO=BAR\n")
}

func TestUnparseIncludeModifier(t *testing.T) {
	checkUnparseModifier(t, NewIncludeModifier(NewDescriptor("foo","1.2.3","debug")), "  include foo/1.2.3:debug\n")
}

func checkUnparsePackage(t *testing.T, pkg *Package, expected string) {
	buf := &bytes.Buffer{}
	u := NewUnparser(buf)
	u.UnparsePackage(pkg)
	actual := buf.String()
	if expected != actual {
		t.Errorf("Expected: %s, got: %s", expected, actual)
	}	
}

func checkUnparseConfig(t *testing.T, config *Config, expected string) {
	buf := &bytes.Buffer{}
	u := NewUnparser(buf)
	u.UnparseConfig(config)
	actual := buf.String()
	if expected != actual {
		t.Errorf("Expected: %s, got: %s", expected, actual)
	}	
}

func checkUnparseModifier(t *testing.T, mod Modifier, expected string) {
	buf := &bytes.Buffer{}
	u := NewUnparser(buf)
	u.UnparseModifier(mod)
	actual := buf.String()
	if expected != actual {
		t.Errorf("Expected: %s, got: %s", expected, actual)
	}	
}
