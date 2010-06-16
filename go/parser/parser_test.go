package parser

//import "fmt"
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
	checkError(t, "xyzzy a=b", keywordError, 1, 1, 5)
}

func TestBadSet(t *testing.T) {
	checkError(t, "set !ab=c", variableNameError, 1, 5, 1)
	checkError(t, "set a@b=c", variableNameError, 1, 6, 1)
	checkError(t, "set ab#=c", variableNameError, 1, 7, 1)

	checkError(t, "set ab =c", nameValueWhitespaceError, 1, 7, 1)
	checkError(t, "set ab= c", nameValueWhitespaceError, 1, 8, 1)

	checkError(t, "set a=$bc", variableValueError, 1, 7, 1)
	checkError(t, "set a=b%c", variableValueError, 1, 8, 1)
	checkError(t, "set a=bc^", variableValueError, 1, 9, 1)
}

func TestBadInclude(t *testing.T) {
	checkError(t, "include &", packageNameError, 1, 9, 1)
	checkError(t, "include a*", packageNameError, 1, 10, 1)
	checkError(t, "include a/(", versionNameError, 1, 11, 1)
	checkError(t, "include a/b)", versionNameError, 1, 12, 1)
	checkError(t, "include a:!", configNameError, 1, 11, 1)
	checkError(t, "include a:b@", configNameError, 1, 12, 1)
}

func checkError(t *testing.T, s string, message string, row int, col int, length int) {
	scanner := NewScanner("test", []byte(s))
	_, err := scanner.Parse()
	if err == nil {
		t.Fatalf("Expected error")
	}
	if err.message != message {
		t.Errorf("Expected error: \"%s\", got: \"%s\"", message, err.message)
	}
	if err.row != row {
		t.Errorf("Expected row: %d, actual: %d", row, err.row)
	}
	if err.col != col {
		t.Errorf("Expected col: %d, actual: %d", col, err.col)
	}
	if err.length != length {
		t.Errorf("Expected length: %d, actual: %d", length, err.length)
	}
//	fmt.Println(err)
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