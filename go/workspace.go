package fig

type Workspace interface {
	Install(PackageName, VersionName)
	IsInstalled(PackageName, VersionName) bool
}
