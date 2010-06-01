package opt

import "fmt"
import "os"
import "regexp"
import "strings"

func ParseArgs(args []string) (Command, os.Error) {
	iter := &ArgIterator{args, -1}

	if !iter.Next() {
		panic("Missing executable name")
	}

	if !iter.Next() {
		return nil, os.NewError("Please specify a command to run")
	}

	switch iter.Get() {
	case "help":
		return &HelpCommand{}, nil
	case "list":
		return parseList(iter)
	case "publish":
		return parsePublish(iter)
	case "retrieve":
		return parseRetrieve(iter)
	case "run":
		return parseRun(iter)
	}

	return nil, os.NewError(fmt.Sprintf("Unknown command: %s", args[1]))
}

func parseList(iter *ArgIterator) (Command, os.Error) {
        if iter.Next() {
                return nil, os.NewError(fmt.Sprintf("Unexpected argument: %s", iter.Get()))
        }
        return &ListCommand{}, nil
}

func parsePublish(iter *ArgIterator) (Command, os.Error) {
        packageName := ""
        versionName := ""
        modifiers := make([]Modifier, 0, 10)
        for iter.Next() {
                modifier, err := parseModifier(iter)
                if err != nil {
                        return nil, err
                } else if modifier != nil {
                        addModifier(&modifiers, modifier)
                } else if packageName == "" {
                        if packageName, versionName, err = parsePackageAndVersion(iter.Get()); err != nil {
				return nil, err
			}
                } else {
                        return nil, os.NewError(fmt.Sprintf("Unexpected argument: %s", iter.Get()))
                }
        }
        return &PublishCommand{PackageName(packageName), VersionName(versionName), modifiers}, nil
}

func parseRetrieve(iter *ArgIterator) (Command, os.Error) {
        if iter.Next() {
                return nil, os.NewError(fmt.Sprintf("Unexpected argument: %s", iter.Get()))
        }
        return &RetrieveCommand{}, nil
}

func parseRun(iter *ArgIterator) (Command, os.Error) {
	modifiers := make([]Modifier, 0, 10)
	for iter.Next() {
		modifier, err := parseModifier(iter)
		if err != nil {
			return nil, err
		}
		if modifier != nil {
			addModifier(&modifiers, modifier)
		} else {
			return &RunCommand{iter.Rest(), modifiers}, nil
		}
	}
	return nil, os.NewError("Missing command to run")
}

func parseModifier(iter *ArgIterator) (Modifier, os.Error) {
        switch iter.Get() {
        case "-i", "--include":
                if !iter.Next() {
                        return nil, os.NewError(fmt.Sprintf("%s option requires a package specifier", iter.Get()))
                }
                packageName, versionName, configName, _ := parseDescriptor(iter.Get())
                return &IncludeModifier{PackageName(packageName), VersionName(versionName), ConfigName(configName)}, nil
        }
        return nil, nil
}

func parseDescriptor(descriptor string) (PackageName, VersionName, ConfigName, os.Error) {
        var parts []string
        var packageName, versionName, configName string

        parts = strings.Split(descriptor, ":", 0)
        if len(parts) == 1 {
                configName = ""
        } else {
                configName = parts[1]
                descriptor = parts[0]
        }
        parts = strings.Split(descriptor, "/", 0)
        if len(parts) == 1 {
                versionName = ""
        } else {
                versionName = parts[1]
                descriptor = parts[0]
        }

        packageName = descriptor

        return PackageName(packageName), VersionName(versionName), ConfigName(configName), nil
}

func parsePackageAndVersion(s string) (string, string, os.Error) {
        packageName, versionName := splitVersionName(s)
        if match, _ := regexp.MatchString("^"+PackageNamePattern+"$", packageName); !match {
                return "", "", os.NewError(fmt.Sprintf("Not a valid package name: %s", packageName))
        }
        if versionName != "" {
                if match, _ := regexp.MatchString("^"+VersionNamePattern+"$", versionName); !match {
                        return "", "", os.NewError(fmt.Sprintf("Not a valid version name: %s", versionName))
                }
        }
	return packageName, versionName, nil
}

func addModifier(modifiers *[]Modifier, modifier Modifier) {
        *modifiers = (*modifiers)[0 : 1+len(*modifiers)]
        (*modifiers)[len(*modifiers)-1] = modifier
}

func splitVersionName(descriptor string) (string, string) {
        parts := strings.Split(descriptor, "/", 0)
        if len(parts) == 1 {
                return parts[0], ""
        }
        return parts[0], parts[1]
}
