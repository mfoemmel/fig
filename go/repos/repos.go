package repos

import "os"
import "path"

import . "fig/model"

type fileRepository struct {
	baseDir string
}

func (r *fileRepository) ListPackages() (<-chan Descriptor) {
	c := make(chan Descriptor)
	go func() {
		reposDir, err := os.Open(r.baseDir, os.O_RDONLY, 0)
		if err != nil {
			panic(err)
		}
		packageDirNames, err := reposDir.Readdirnames(-1)
		if err != nil {
			panic(err)
		}
		for _, packageDirName := range packageDirNames {
			packageDir, err := os.Open(path.Join(r.baseDir, packageDirName), os.O_RDONLY, 0)
			if err != nil {
				panic(err)
			}
			versionDirNames, err := packageDir.Readdirnames(-1)
			for _, versionDirName := range versionDirNames {
				c <- NewDescriptor(packageDirName, versionDirName, "")
			}
		}
		close(c)
	}()
	return c
}
