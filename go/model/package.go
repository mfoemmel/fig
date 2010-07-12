package model

import "fmt"

type Package struct {
	PackageName PackageName
	VersionName VersionName
	Directory   string
	Configs     []*Config
}

func NewPackage(packageName PackageName, versionName VersionName, directory string, configs []*Config) *Package {
	return &Package{packageName, versionName, directory, configs}
}

func (pkg *Package) FindConfig(configName ConfigName) *Config {
	for _, config := range pkg.Configs {
		if config.ConfigName == configName {
			return config
		}
	}
	return nil
}

// Testing

func ComparePackage(expected *Package, actual *Package) (bool,string) {
	if expected.PackageName != actual.PackageName {
		return false, fmt.Sprintf("PackageName mismatch: %s != %s", expected.PackageName, actual.PackageName)
	}
	if expected.VersionName != actual.VersionName {
		return false, fmt.Sprintf("VersionName mismatch: %s != %s", expected.VersionName, actual.VersionName)
	}
	if expected.Directory != actual.Directory {
		return false, fmt.Sprintf("Directory mismatch: %s != %s", expected.Directory, actual.Directory)
	}
	if len(expected.Configs) != len(actual.Configs) {
		return false, fmt.Sprintf("Expected %d configs, got %d", len(expected.Configs), len(actual.Configs))
	}
	for i, _ := range expected.Configs {
		if ok, msg := CompareConfig(expected.Configs[i], actual.Configs[i]); !ok {
			return ok, msg
		}
	}
	return true, ""
}


