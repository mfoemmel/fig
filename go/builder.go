package fig

import "container/vector"

type PackageBuilder struct {
	packageName PackageName
	versionName VersionName
	statements vector.Vector
}

type ConfigBuilder struct {
	packageBuilder *PackageBuilder
	configName ConfigName
	statements vector.Vector
}

func NewPackageBuilder(packageName string, versionName string) *PackageBuilder {
	return &PackageBuilder{PackageName(packageName), VersionName(versionName), vector.Vector{}}
}

func NewConfigBuilder(configName string) *ConfigBuilder {
	return &ConfigBuilder{nil, ConfigName(configName), vector.Vector{}}
}

func (packageBuilder *PackageBuilder) Build() *Package {
	statements := make([]PackageStatement, packageBuilder.statements.Len())
	for i, statement := range packageBuilder.statements {
		statements[i] = statement.(PackageStatement)
	}
	return NewPackage(packageBuilder.packageName, packageBuilder.versionName, statements)
}

func (packageBuilder *PackageBuilder) Name(packageName string, versionName string) *PackageBuilder {
	packageBuilder.statements.Push(NewNameStatement(PackageName(packageName), VersionName(versionName)))
	return packageBuilder
}
func (packageBuilder *PackageBuilder) Resource(path string) *PackageBuilder {
	packageBuilder.statements.Push(NewResourceStatement(path))
	return packageBuilder
}

func (packageBuilder *PackageBuilder) Archive(path string) *PackageBuilder {
	packageBuilder.statements.Push(NewArchiveStatement(path))
	return packageBuilder
}

func (packageBuilder *PackageBuilder) Config(name string) *ConfigBuilder {
	return &ConfigBuilder{packageBuilder, ConfigName(name), vector.Vector{}}
}

func (configBuilder *ConfigBuilder) Set(name string, value string) *ConfigBuilder {
	configBuilder.statements.Push(NewModifierStatement(NewSetModifier(name, value)))
	return configBuilder
}

func (configBuilder *ConfigBuilder) Path(name string, value string) *ConfigBuilder {
	configBuilder.statements.Push(NewModifierStatement(NewPathModifier("", name, value)))
	return configBuilder
}

func (configBuilder *ConfigBuilder) Include(packageName string, versionName string, configName string) *ConfigBuilder {
	desc := NewDescriptor(packageName,versionName,configName)
	configBuilder.statements.Push(NewModifierStatement(NewIncludeModifier(desc)))
	return configBuilder
}

func (configBuilder *ConfigBuilder) Build() *Config{
	statements := make([]ConfigStatement, configBuilder.statements.Len())
	for i, statement := range configBuilder.statements {
		statements[i] = statement.(ConfigStatement)
	}
	return NewConfig(configBuilder.configName, statements)
}

func (configBuilder *ConfigBuilder) End() *PackageBuilder{
	packageBuilder := configBuilder.packageBuilder
	packageBuilder.statements.Push(NewConfigBlock(configBuilder.Build()))
	return packageBuilder
}
