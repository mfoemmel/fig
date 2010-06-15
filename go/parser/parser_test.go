package parser

import "testing"

import . "fig/model"

func TestSet(t *testing.T) {
	scanner := NewScanner("test", []byte("\nset FOO=BAR"))
	modifiers, err := scanner.Parse()
	if err != nil {
		t.Fatal(err)
	}
	if l := len(modifiers); l != 1 {
		t.Fatalf("Expected 1 modifier, got: %d", l)
	}		
	if name := modifiers[0].(*SetModifier).Name; name != "FOO" {
		t.Errorf("Expected name: '%s', got '%s'", "FOO", name)
	}
	if value := modifiers[0].(*SetModifier).Value; value != "BAR" {
		t.Errorf("Expected value: %s, got %s", "BAR", value)
	}
}

func TestInclude(t *testing.T) {
	scanner := NewScanner("test", []byte("include foo/1.2.3:bar"))
	modifiers, err := scanner.Parse()
	if err != nil {
		t.Fatal(err)
	}
	if l := len(modifiers); l != 1 {
		t.Fatalf("Expected 1 modifier, got: %d", l)
	}		
	if packageName := modifiers[0].(*IncludeModifier).PackageName; packageName != "foo" {
		t.Errorf("Expected package name: %s, got %s", "foo", packageName)
	}
	if versionName := modifiers[0].(*IncludeModifier).VersionName; versionName != "1.2.3" {
		t.Errorf("Expected version name: %s, got %s", "1.2.3", versionName)
	}
	if configName := modifiers[0].(*IncludeModifier).ConfigName; configName != "bar" {
		t.Errorf("Expected config name: %s, got %s", "bar", configName)
	}

}

func TestBadKeyword(t *testing.T) {
	scanner := NewScanner("test", []byte("xyzzy a=b"))
	_, err := scanner.Parse()
	if err == nil {
		t.Errorf("Expected error")
	}
	if err.message != keywordError {
		t.Errorf(err.message)
	}
	if err.row != 1 {
		t.Errorf("Expected row: %d, actual: %d", 1, err.row)
	}
	if err.col != 1 {
		t.Errorf("Expected col: %d, actual: %d", 1, err.col)
	}
	if err.length != 5 {
		t.Errorf("Expected length: %d, actual: %d", 5, err.length)
	}
//	t.Error(err.String())
}

/*
func TestDescriptor(t *testing.T) {
	scanner := NewScanner([]byte("foo/1.2.3:bar"))
	if scanner.Next() != PackageName {
		t.Fatal("Expected package name")
	}
	packageName, versionName, configName := scanner.ReadDescriptor()
	if packageName != "foo" {
		t.Errorf("Expected package name: foo, got: %s", packageName)
	}
	if versionName != "foo" {
		t.Errorf("Expected package name: foo, got: %s", packageName)
	}
	if configName != "foo" {
		t.Errorf("Expected package name: foo, got: %s", packageName)
	}
}
*/