package repos

import "io"
//import "fmt"
import "os"
import "path"

import . "fig/model"
import . "fig/parser"

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

func (r *fileRepository) LoadPackage(packageName PackageName, versionName VersionName) *Package {
	packageDir := path.Join(r.baseDir, string(packageName), string(versionName))
	file, err := os.Open(path.Join(packageDir, "package.fig"), os.O_RDONLY, 0)
	if err != nil {
		panic(err)
	}
	stat, err := file.Stat()
	if err != nil {
		panic(err)
	}
	buf := make([]byte, stat.Size)
	_, err = file.Read(buf)
	if err != nil {
		panic(err)
	}
	pkg, err2 := NewParser(file.Name(), buf).ParsePackage()
	if err2 != nil {
		panic(err2.String())
	}
	pkg.PackageName = packageName
	pkg.VersionName = versionName
	return pkg
}

type PackageReader interface {
	ReadStatements() []PackageStatement
	OpenResource(path string) io.ReadCloser
	Close()
}

type PackageWriter interface {
	WriteStatements([]PackageStatement)
	OpenResource(path string) io.WriteCloser
	Commit()
	Close()
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
	file, err := os.Open(path.Join(packageDir, "package.fig"), os.O_RDONLY, 0)
	if err != nil {
		panic(err)
	}
	stat, err := file.Stat()
	if err != nil {
		panic(err)
	}
	buf := make([]byte, stat.Size)
	_, err = file.Read(buf)
	if err != nil {
		panic(err)
	}
	pkg, err2 := NewParser(file.Name(), buf).ParsePackage()
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
