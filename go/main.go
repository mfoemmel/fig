package main

import "fmt"

import "fig"

func main() {
	fmt.Printf("Hello, world %v\n", fig.NewPackage("A","b",[]fig.PackageStatement{}))
}
