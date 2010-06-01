package model

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

