package fig

import "bytes"
import "reflect"
import "strings"
import "testing"

//
// Unknown command
//

func TestUnknownCommand(t *testing.T) {
	checkArgsError(t, "fig xyzzy", "Unknown command: xyzzy")
}


//
// Help
//

func TestHelp(t *testing.T) {
	checkArgs(t, "fig help", help())
}


//
// Show
//
func TestShow(t *testing.T) {
	checkArgs(t, "fig show test/1.2.3", show("test", "1.2.3"))
}

//
// Helpers
//

func parseCommand(t *testing.T, s string) Command {
	cmd, err := ParseArgs(strings.Split(s, " ", -1))
	assertNil(t, err)
	return cmd
}

func checkArgs(t *testing.T, s string, cmd Command) {
	assertDeepEqual(t, parseCommand(t, s), cmd)
}

func checkArgsError(t *testing.T, s string, msg string) {
	cmd, err := ParseArgs(strings.Split(s, " ", -1))
	assertNil(t, cmd)
	assertEquals(t, err.String(), msg)
}

func assertEquals(t *testing.T, a interface{}, b interface{}) {
	if a != b {
		t.Errorf("Expected: \"%v\", got: \"%v\"", a, b)
	}
}

func assertDeepEqual(t *testing.T, a interface{}, b interface{}) {
	if !reflect.DeepEqual(a, b) {
		t.Errorf("Expected: \"%v\", got: \"%v\"", a, b)
	}
}

func assertNil(t *testing.T, val interface{}) {
	if val != nil {
		t.Fatalf("Expected <nil>, got: \"%v\"", val)
	}
}

//
// Factories
//

func help() Command {
	return &HelpCommand{}
}

func show(packageName string, versionName string) Command {
	return &ShowCommand{PackageName(packageName), VersionName(versionName)}
}

//
// Context
//

func NewTestContext() (*Context, *bytes.Buffer, *bytes.Buffer) {
	fs := NewMemoryFileSystem()
	repo := NewMemoryRepository()
	space := NewMemoryWorkspace()
	out := bytes.NewBuffer(nil)
	err := bytes.NewBuffer(nil)
	return &Context{fs, repo, space, out, err}, out, err
}
