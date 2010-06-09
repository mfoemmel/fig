package parser

import "testing"

import . "fig/model"

func TestKeyword(t *testing.T) {
	scanner := NewScanner("test", []byte("include foo/1.2.3:bar"))
	modifiers := scanner.Parse()
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

/*	if keyword := scanner.ReadKeyword(); keyword != "include" {
		t.Errorf("Expected: hello, got: %s", keyword)
	}
*/
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