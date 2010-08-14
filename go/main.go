package main

//import "fmt"
import "os"

import "fig"

func main() {
	repo := fig.NewFileRepository("../repos")
	cmd, err := fig.ParseArgs(os.Args)
	if err != nil {
		os.Stderr.Write([]byte(err.String() + "\n"))
		os.Exit(1)
	}
	cmd.Execute(repo, os.Stdout)
}
