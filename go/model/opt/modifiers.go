package opt

type PackageName string
type VersionName string
type ConfigName string

const PackageNamePattern = "[a-z]+"
const VersionNamePattern = "[0-9.]+"

type Modifier interface {}

type IncludeModifier struct {
	packageName PackageName
	versionName VersionName
	configName  ConfigName
}
