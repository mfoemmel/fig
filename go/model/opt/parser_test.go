package opt

import "reflect"
import "strings"
import "testing"

//
// Unknown command
//

func TestOptions(t *testing.T) {
	checkError(t, "fig xyzzy", "Unknown command: xyzzy")
}


//
// Help
//

func TestHelp(t *testing.T) {
	check(t, "fig help", help())
}


//
// List
//

func TestListCommand(t *testing.T) {
        check(t, "fig list", list())
}


//
// Publish
//

func TestPublishCommand(t *testing.T) {
        check(t, "fig publish", publish("",""))
}

func TestPublishCommandWithPackageName(t *testing.T) {
        check(t, "fig publish foo", publish("foo",""))
}

func TestPublishCommandWithInvalidPackageName(t *testing.T) {
        checkError(t, "fig publish foo@bar", "Not a valid package name: foo@bar")
}

func TestPublishCommandWithPackageNameAndVersionName(t *testing.T) {
        check(t, "fig publish foo/1.2.3", publish("foo", "1.2.3"))
}

func TestPublishCommandWithPackageNameAndInvalidVersionName(t *testing.T) {
        checkError(t, "fig publish foo/1+2", "Not a valid version name: 1+2")
}

func TestPublishCommandWithIncludePackage(t *testing.T) {
        check(t, "fig publish -i foo", publish("", "", include("foo", "", "")))
}

func TestPublishCommandWithIncludePackageAndVersion(t *testing.T) {
        check(t, "fig publish -i foo/1.2.3", publish("", "", include("foo", "1.2.3", "")))
}

func TestPublishCommandWithIncludePackageAndConfig(t *testing.T) {
        check(t, "fig publish -i foo:debug", publish("", "", include("foo", "", "debug")))
}

func TestPublishCommandWithIncludePackageAndVersionAndConfig(t *testing.T) {
        check(t, "fig publish -i foo/1.2.3:debug", publish("", "", include("foo", "1.2.3", "debug")))
}

func TestPublishCommandWithIncludeConfig(t *testing.T) {
        check(t, "fig publish -i :debug", publish("", "", include("", "", "debug")))
}

//
// Retrieve
//

func TestRetrieveCommand(t *testing.T) {
        check(t, "fig retrieve", retrieve())
}

func TestRetrieveCommandWithExtraArg(t *testing.T) {
        checkError(t, "fig retrieve xyzzy", "Unexpected argument: xyzzy")
}


//
// Run
//

func TestRunCommandNoArgs(t *testing.T) {
        checkError(t, "fig run", "Missing command to run")
}

func TestRunCommandOneArg(t *testing.T) {
        check(t, "fig run foo", run([]string{"foo"}))
}

func TestRunCommandTwoArgs(t *testing.T) {
        check(t, "fig run foo bar", run([]string{"foo", "bar"}))
}

func TestRunCommandWithIncludeBeforeExe(t *testing.T) {
        check(t, "fig run -i somepkg foo", run([]string{"foo"}, include("somepkg", "", "")))
}

func TestRunCommandWithIncludeAfterExe(t *testing.T) {
        check(t, "fig run foo -i somepkg", run([]string{"foo", "-i", "somepkg"}))
}

func TestRunCommandIncludeWithMissingPackage(t *testing.T) {
        checkError(t, "fig run -i", "-i option requires a package specifier")
}


//
// Factories
//

func help() Command {
	return &HelpCommand{}
}

func list() Command {
	return &ListCommand{}
}

func run(command []string, modifiers ...Modifier) Command {
	return &RunCommand{command, modifiers}
}

func publish(packageName string, versionName string, modifiers ...Modifier) Command {
	return &PublishCommand{PackageName(packageName), VersionName(versionName), modifiers}
}

func retrieve() Command {
	return &RetrieveCommand{}
}

func include(packageName string, versionName string, configName string) Modifier{
	return &IncludeModifier{PackageName(packageName), VersionName(versionName), ConfigName(configName)}
}

//
// Helpers
//

func parseCommand(t *testing.T, s string) Command {
        cmd, err := ParseArgs(strings.Split(s, " ", 0))
        assertNil(t, err)
        return cmd
}

func check(t *testing.T, s string, cmd Command) {
        assertDeepEqual(t, parseCommand(t, s), cmd)
}

func checkError(t *testing.T, s string, msg string) {
        cmd, err := ParseArgs(strings.Split(s, " ", 0))
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
