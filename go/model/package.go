package model

import "fmt"

type Package struct {
	PackageName PackageName
	VersionName VersionName
	Directory   string
	Statements  []PackageStatement
}

type PackageStatement interface {
	Accept(handler PackageStatementHandler)
}

type PackageStatementHandler interface {
	ConfigBlock(*Config)
}

func NewPackage(packageName PackageName, versionName VersionName, directory string, configs []PackageStatement) *Package {
	return &Package{packageName, versionName, directory, configs}
}

func (pkg *Package) FindConfig(configName ConfigName) *Config {
	for _, config := range pkg.Statements {
		if config.(*ConfigBlock).Config.ConfigName == configName {
			return config.(*ConfigBlock).Config
		}
	}
	return nil
}

type ConfigBlock struct {
	Config *Config
}

func (cb *ConfigBlock) Accept(handler PackageStatementHandler) {
	handler.ConfigBlock(cb.Config)
}

func NewConfigBlock(c *Config) *ConfigBlock {
	return &ConfigBlock{c}
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
	if len(expected.Statements) != len(actual.Statements) {
		return false, fmt.Sprintf("Expected %d statements, got %d", len(expected.Statements), len(actual.Statements))
	}
	for i, _ := range expected.Statements {
		if ok, msg := ComparePackageStatement(expected.Statements[i], actual.Statements[i]); !ok {
			return ok, msg
		}
	}
	return true, ""
}

func ComparePackageStatement(expected PackageStatement, actual PackageStatement) (bool,string) {
	switch actual := actual.(type) {
	case *ConfigBlock:
		if ok, msg := CompareConfig(expected.(*ConfigBlock).Config, actual.Config); !ok {
			return ok, msg
		}		
	default:
		panic("unexpected package statement type")
	}
	return true, ""
}
