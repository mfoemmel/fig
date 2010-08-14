package main

//import "fmt"
import "os"

import "fig"

func main() {
	repo := fig.NewFileRepository("../repos")
	pkg := fig.ReadPackage(repo, fig.PackageName(os.Args[1]), fig.VersionName(os.Args[2]))
	fig.NewUnparser(os.Stdout).UnparsePackage(pkg)
}
