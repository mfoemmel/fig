package parser

//import "fmt"
import "testing"

import . "fig/model"

func TestSet(t *testing.T) {
	input := "set FOO=BAR"
	expected := []Modifier{
		NewSetModifier("FOO", "BAR"),
	}
	checkParse(t, input, expected)
}

func TestInclude(t *testing.T) {
	input := "include foo/1.2.3:bar"
	expected := []Modifier{
		NewIncludeModifier("foo", "1.2.3", "bar"),
	}
	checkParse(t, input, expected)
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

func checkParse(t *testing.T, s string, expected []Modifier) {
	scanner := NewScanner("test", []byte(s))
	modifiers, err := scanner.Parse()
	if err != nil {
		t.Fatal(err)
	}
	checkModifiers(t, expected, modifiers)
}

func checkModifiers(t *testing.T, expected []Modifier, actual []Modifier) {
	if len(expected) != len(actual) {
		t.Fatalf("Expected %d modifier, got %d", len(expected), len(actual))
	}
	for i, _ := range expected {
		checkModifier(t, expected[i], actual[i])
	}
}

func checkModifier(t *testing.T, expected Modifier, actual Modifier) {
	switch a := actual.(type) {
	case *SetModifier:
		e := expected.(*SetModifier)
		if a.Name != e.Name {
			t.Errorf("Expected name: '%s', got '%s'", e.Name, a.Name)
		}
		if a.Value != e.Value {
			t.Errorf("Expected name: '%s', got '%s'", e.Value, a.Value)
		}

	case *IncludeModifier:
		e := expected.(*IncludeModifier)
		if a.PackageName != e.PackageName {
			t.Errorf("Expected package name: %s, got %s", e.PackageName, a.PackageName)
		}
		if a.VersionName != e.VersionName {
			t.Errorf("Expected version name: %s, got %s", e.VersionName, a.VersionName)
		}
		if a.ConfigName != e.ConfigName {
			t.Errorf("Expected config name: %s, got %s", e.ConfigName, a.ConfigName)
		}
	default:
		t.Fatalf("Unexpected modifier type: %v", actual)
	}
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

