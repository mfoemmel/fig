package model



//
// Package
//

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



