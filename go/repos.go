package fig

import "io"
import "os"

type Repository interface {
	ListPackages() (<-chan Descriptor) 
	NewPackageReader(PackageName, VersionName) PackageReader
	NewPackageWriter(PackageName, VersionName) PackageWriter
}

type PackageReader interface {
	ReadStatements() ([]PackageStatement, os.Error)
	OpenResource(path string) io.ReadCloser
	Close()
}

type PackageWriter interface {
	WriteStatements([]PackageStatement)
	OpenResource(path string) io.WriteCloser
	Commit()
	Close()
}

func ReadPackage(repo Repository, packageName PackageName, versionName VersionName) (*Package, os.Error) {
	r := repo.NewPackageReader(packageName, versionName)
	defer r.Close()
	stmts, err := r.ReadStatements()
	if err != nil {
		return nil, err
	}
	return NewPackage(packageName, versionName, stmts), nil
}

func WritePackage(repo Repository, pkg *Package) {
	w := repo.NewPackageWriter(pkg.PackageName, pkg.VersionName)
	defer w.Close()
	w.WriteStatements(pkg.Statements)
	w.Commit()
}

func WriteRawPackage(repo Repository, packageName PackageName, versionName VersionName, contents string) os.Error {
	pkg, err := NewParser("", []byte(contents)).ParsePackage(packageName, versionName)
	if err != nil {
		panic(err)
	}
	WritePackage(repo, pkg)
	return nil
}

