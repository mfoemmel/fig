package fig

import "fmt"

type Package struct {
	PackageName PackageName
	VersionName VersionName
	Statements  []PackageStatement
}

type PackageStatement interface {
	Accept(handler PackageStatementHandler)
}

type PackageStatementHandler interface {
	NameStatement(PackageName, VersionName)
	ResourceStatement(path string)
	ArchiveStatement(path string)
	ConfigBlock(*Config)
}

func NewPackage(packageName PackageName, versionName VersionName, configs []PackageStatement) *Package {
	return &Package{packageName, versionName, configs}
}

func (pkg *Package) FindConfig(configName ConfigName) *Config {
	for _, config := range pkg.Statements {
		if block, ok := config.(*ConfigBlock); ok && block.Config.ConfigName == configName {
			return block.Config
		}
	}
	return nil
}

// NameStatement

type NameStatement struct {
	PackageName PackageName
	VersionName VersionName
}

func NewNameStatement(packageName PackageName, versionName VersionName) *NameStatement {
	return &NameStatement{packageName, versionName}
}

func (ns *NameStatement) Accept(handler PackageStatementHandler) {
	handler.NameStatement(ns.PackageName, ns.VersionName)
}

// ResourceStatement

type ResourceStatement struct {
	Path string
}

func NewResourceStatement(path string) *ResourceStatement {
	return &ResourceStatement{path}
}

func (rs *ResourceStatement) Accept(handler PackageStatementHandler) {
	handler.ResourceStatement(rs.Path)
}

// ArchiveStatement

type ArchiveStatement struct {
	Path string
}

func NewArchiveStatement(path string) *ArchiveStatement {
	return &ArchiveStatement{path}
}

func (as *ArchiveStatement) Accept(handler PackageStatementHandler) {
	handler.ArchiveStatement(as.Path)
}

// ConfigBlock

type ConfigBlock struct {
	Config *Config
}

func NewConfigBlock(c *Config) *ConfigBlock {
	return &ConfigBlock{c}
}

func (cb *ConfigBlock) Accept(handler PackageStatementHandler) {
	handler.ConfigBlock(cb.Config)
}

// Testing

func ComparePackage(expected *Package, actual *Package) (bool, string) {
	if expected.PackageName != actual.PackageName {
		return false, fmt.Sprintf("PackageName mismatch: %s != %s", expected.PackageName, actual.PackageName)
	}
	if expected.VersionName != actual.VersionName {
		return false, fmt.Sprintf("VersionName mismatch: %s != %s", expected.VersionName, actual.VersionName)
	}
	if len(expected.Statements) != len(actual.Statements) {
		return false, fmt.Sprintf("Expected %d statements, got %d", len(expected.Statements), len(actual.Statements))
	}
	ok, msg := ComparePackageStatements(expected.Statements, actual.Statements)
	if !ok {
		return ok, msg
	}
	return true, ""
}

func ComparePackageStatements(expected []PackageStatement, actual []PackageStatement) (bool, string) {
	for i, _ := range expected {
		if ok, msg := ComparePackageStatement(expected[i], actual[i]); !ok {
			return ok, msg
		}
	}
	return true, ""
}

func ComparePackageStatement(expected PackageStatement, actual PackageStatement) (bool, string) {
	switch actual := actual.(type) {
	case *NameStatement:
		if actual.PackageName != expected.(*NameStatement).PackageName {
			return false, fmt.Sprintf("Expected package name \"%s\", got \"%s\"", actual.PackageName, expected.(*NameStatement).PackageName)
		}
		if actual.VersionName != expected.(*NameStatement).VersionName {
			return false, fmt.Sprintf("Expected version name \"%s\", got \"%s\"", actual.VersionName, expected.(*NameStatement).VersionName)
		}
		return true, ""
	case *ResourceStatement:
		if actual.Path != expected.(*ResourceStatement).Path {
			return false, fmt.Sprintf("Expected path \"%s\", got \"%s\"", actual.Path, expected.(*ResourceStatement).Path)
		}
		return true, ""
	case *ArchiveStatement:
		if actual.Path != expected.(*ArchiveStatement).Path {
			return false, fmt.Sprintf("Expected path \"%s\", got \"%s\"", actual.Path, expected.(*ArchiveStatement).Path)
		}
		return true, ""
	case *ConfigBlock:
		if ok, msg := CompareConfig(expected.(*ConfigBlock).Config, actual.Config); !ok {
			return ok, msg
		}
	default:
		panic("unexpected package statement type")
	}
	return true, ""
}
