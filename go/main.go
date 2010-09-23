package main

//import "fmt"
import "os"

import "fig"

func main() {
	repo := fig.NewFileRepository("../repos")
	space := fig.NewFileWorkspace("../space")
	ctx := fig.NewContext(nil, repo, space, os.Stdout, os.Stdin)
	cmd, err := fig.ParseArgs(os.Args)
	if err != nil {
		os.Stderr.Write([]byte(err.String() + "\n"))
		os.Exit(1)
	}
	rc := cmd.Execute(ctx)
	os.Exit(rc)
}