package fig

type FileWorkspace struct {
}

func NewFileWorkspace(installDir string) *FileWorkspace {
	return &FileWorkspace{}
}

func (space* FileWorkspace) Install(packageName PackageName, versionName VersionName)  {
}

func (space* FileWorkspace) IsInstalled(packageName PackageName, versionName VersionName) bool {
	return false
}

