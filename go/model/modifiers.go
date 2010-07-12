package model

import "fmt"
import "os"

//
// Modifiers
//

type ModifierHandler interface {
	HandleSet(name string, value string) os.Error
	HandlePath(name string, value string) os.Error
	HandleInclude(packageName PackageName, versionName VersionName, configName ConfigName) os.Error
}

type Modifier interface {
	Accept(handler ModifierHandler) os.Error
}


//                                                                                                                                                                 // Set Modifier
//

type SetModifier struct {
	Name  string
	Value string
}

func NewSetModifier(name string, value string) Modifier {
	return &SetModifier{name, value}
}

func (sm *SetModifier) Accept(handler ModifierHandler) os.Error {
	return handler.HandlePath(sm.Name, sm.Value)
}

//
// PathModifier
//

type PathModifier struct {
	Name  string
	Value string
}

func NewPathModifier(name string, value string) Modifier {
	return &PathModifier{name, value}
}

func (pm *PathModifier) Accept(handler ModifierHandler) os.Error {
	return handler.HandlePath(pm.Name, pm.Value)
}


//
// IncludeModifier
//

type IncludeModifier struct {
	PackageName PackageName
	VersionName VersionName
	ConfigName  ConfigName
}

func NewIncludeModifier(packageName PackageName, versionName VersionName, configName ConfigName) Modifier {
	return &IncludeModifier{packageName, versionName, configName}
}

func (im *IncludeModifier) Accept(handler ModifierHandler) os.Error {
	return handler.HandleInclude(im.PackageName, im.VersionName, im.ConfigName)
}

func (im *IncludeModifier) Descriptor() Descriptor {
	return Descriptor{im.PackageName, im.VersionName, im.ConfigName}
}

// Testing

func CompareModifier(expected Modifier, actual Modifier) (bool, string) {
	switch a := actual.(type) {
	case *SetModifier:
		e := expected.(*SetModifier)
		if a.Name != e.Name {
			return false, fmt.Sprintf("Expected name: '%s', got '%s'", e.Name, a.Name)
		}
		if a.Value != e.Value {
			return false, fmt.Sprintf("Expected name: '%s', got '%s'", e.Value, a.Value)
		}
	case *IncludeModifier:
		e := expected.(*IncludeModifier)
		if a.PackageName != e.PackageName {
			return false, fmt.Sprintf("Expected package name: %s, got %s", e.PackageName, a.PackageName)
		}
		if a.VersionName != e.VersionName {
			return false, fmt.Sprintf("Expected version name: %s, got %s", e.VersionName, a.VersionName)
		}
		if a.ConfigName != e.ConfigName {
			return false, fmt.Sprintf("Expected config name: %s, got %s", e.ConfigName, a.ConfigName)
		}
	default:
		panic(fmt.Sprintf("Unexpected modifier type: %v", actual))
	}
	return true, ""
}
