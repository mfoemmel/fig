package fig

type MemoryWorkspace struct {
	installed map[string]bool
}

func NewMemoryWorkspace() Workspace {
	return &MemoryWorkspace{make(map[string]bool)}
}

func (space *MemoryWorkspace) Install(packageName PackageName, versionName VersionName) {
	space.installed[makeKey(packageName, versionName)] = true
}

func (space *MemoryWorkspace) IsInstalled(packageName PackageName, versionName VersionName) bool {
	return space.installed[makeKey(packageName, versionName)]
}
