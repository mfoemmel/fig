package fig

import "io"
import "io/ioutil"
import "os"
import "path"

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

type fileRepositoryPackageReader struct {
    repos *fileRepository
    packageName PackageName
    versionName VersionName
}

type fileRepositoryPackageWriter struct {
	repos *fileRepository
	packageName PackageName
	versionName VersionName
}

func (r *fileRepositoryPackageReader) ReadStatements() []PackageStatement {
	packageDir := path.Join(r.repos.baseDir, string(r.packageName), string(r.versionName))
	filename := path.Join(packageDir, "package.fig")
	buf, err := ioutil.ReadFile(filename)
	if err != nil {
		panic(err)
	}
	pkg, err2 := NewParser(filename, buf).ParsePackage()
	if err2 != nil {
		panic(err2.String())
	}
	return pkg.Statements
}

func (w *fileRepositoryPackageWriter) WriteStatements(stmts []PackageStatement) {
	packageDir := path.Join(w.repos.baseDir, string(w.packageName), string(w.versionName))
	err := os.MkdirAll(packageDir, 0777)
	if err != nil {
		panic(err)
	}
	file, err := os.Open(path.Join(packageDir, "package.fig"), os.O_WRONLY|os.O_CREAT|os.O_EXCL, 0666)
	if err != nil {
		panic(err)
	}
	NewUnparser(file).UnparsePackageStatements(stmts)

}

func (r *fileRepository) NewPackageReader(packageName PackageName, versionName VersionName) PackageReader {
    return &fileRepositoryPackageReader{r, packageName, versionName}
}

func (r *fileRepositoryPackageReader) Close() {
}

func (r *fileRepositoryPackageReader) OpenResource(res string) io.ReadCloser {
	return nil
}

func (w *fileRepositoryPackageWriter) OpenResource(res string) io.WriteCloser {
	file, err := os.Open(path.Join(w.repos.baseDir, res), os.O_WRONLY|os.O_CREAT, 0666)
	if err != nil {
		panic(err)
	}
	return file
}

func (w *fileRepositoryPackageWriter) Commit() {
}

func (w *fileRepositoryPackageWriter) Close() {
}

func (r *fileRepository) NewPackageWriter(packageName PackageName, versionName VersionName) PackageWriter {
	return &fileRepositoryPackageWriter{r, packageName, versionName}
}
