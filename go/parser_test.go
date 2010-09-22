package fig

//import "fmt"
import "testing"

func TestEmptyPackage(t *testing.T) {
	input := `
`
	expected := NewPackageBuilder("test", "1.2.3").Build()
	checkParsePackage(t, input, expected)
}

func TestPackageWithName(t *testing.T) {
	input := "package foo/1.2.3"
	expected := NewPackageBuilder("foo", "1.2.3").Name("foo", "1.2.3").Build()
	checkParsePackage(t, input, expected)
}

func TestPackageWithResource(t *testing.T) {
	input := `
resource foo/bar.baz
`
	expected := NewPackageBuilder("test", "1.2.3").Resource("foo/bar.baz").Build()
	checkParsePackage(t, input, expected)
}

func TestPackageWithArchive(t *testing.T) {
	input := `
archive foo/bar.tar.gz
`
	expected := NewPackageBuilder("test", "1.2.3").Archive("foo/bar.tar.gz").Build()
	checkParsePackage(t, input, expected)
}

func TestPackageWithOneConfig(t *testing.T) {
	input := `
config foo
end
`
	expected := NewPackageBuilder("test", "1.2.3").Config("foo").End().Build()
	checkParsePackage(t, input, expected)
}

func TestEmptyConfig(t *testing.T) {
	input := `
config foo
end
`
	expected := NewConfigBuilder("foo").Build()
	checkParseConfig(t, input, expected)
}

func TestConfigWithOneModifier(t *testing.T) {
	input := `
config foo
  set FOO=BAR
end
`
	expected := NewConfigBuilder("foo").Set("FOO","BAR").Build()
	checkParseConfig(t, input, expected)
}

func TestConfigWithTwoModifier(t *testing.T) {
	input := `
config foo
  set FOO1=BAR1
  path FOO2=BAR2
end
`
	expected := NewConfigBuilder("foo").Set("FOO1","BAR1").Path("FOO2","BAR2").Build() 
	checkParseConfig(t, input, expected)
}

func TestSet(t *testing.T) {
	input := "set FOO=BAR"
	expected := NewModifierStatement(NewSetModifier("FOO", "BAR"))
	checkParseConfigStatement(t, input, expected)
}

func TestInclude(t *testing.T) {
	input := "include foo/1.2.3:bar"
	expected := NewModifierStatement(NewIncludeModifier(NewDescriptor("foo", "1.2.3", "bar")))
	checkParseConfigStatement(t, input, expected)
}

func TestBadKeyword(t *testing.T) {
	checkError(t, "xyzzy a=b", configKeywordError, 1, 1, 5)
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

func checkParsePackage(t *testing.T, s string, expected *Package) {
	parser := NewParser("test", []byte(s))
	pkg, err := parser.ParsePackage("test","1.2.3")
	if err != nil {
		t.Fatal(err)
	}
	checkPackage(t, expected, pkg)
}

func checkParseConfig(t *testing.T, s string, expected *Config) {
	parser := NewParser("test", []byte(s))
	stmt, err := parser.ParsePackageStatement()
	if err != nil {
		t.Fatal(err)
	}
	checkConfig(t, expected, stmt.(*ConfigBlock).Config)
}

func checkParseConfigStatements(t *testing.T, s string, expected []ConfigStatement) {
	parser := NewParser("test", []byte(s))
	stmts, err := parser.ParseConfigStatements()
	if err != nil {
		t.Fatal(err)
	}
	checkConfigStatements(t, expected, stmts)
}

func checkParseConfigStatement(t *testing.T, s string, expected ConfigStatement) {
	parser := NewParser("test", []byte(s))
	stmt, err := parser.ParseConfigStatement()
	if err != nil {
		t.Fatal(err)
	}
	checkConfigStatement(t, expected, stmt)
}

func checkPackage(t *testing.T, expected *Package, actual *Package) {
	if ok, msg := ComparePackage(expected, actual); !ok {
		t.Error(msg)
	}
}

func checkPackageStatements(t *testing.T, expected []PackageStatement, actual []PackageStatement) {
	if ok, msg := ComparePackageStatements(expected, actual); !ok {
		t.Error(msg)
	}
}

func checkConfig(t *testing.T, expected *Config, actual *Config) {
	if ok, msg := CompareConfig(expected, actual); !ok {
		t.Error(msg)
	}
}

func checkConfigStatements(t *testing.T, expected []ConfigStatement, actual []ConfigStatement) {
	if ok, msg := CompareConfigStatements(expected, actual); !ok {		
		t.Error(msg)
	}
}


func checkConfigStatement(t *testing.T, expected ConfigStatement, actual ConfigStatement) {
	if ok, msg := CompareModifier(expected.(*ModifierStatement).Modifier, actual.(*ModifierStatement).Modifier); !ok {
		t.Error(msg)
	}
}

func checkError(t *testing.T, s string, message string, row int, col int, length int) {
	parser := NewParser("test", []byte(s))
	_, err := parser.ParseConfigStatements()
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

