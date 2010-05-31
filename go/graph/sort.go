package graph

import "container/vector"

// Performs a topological sort on all nodes reachable from the supplied node. Nodes are returned
// in order such that a node will only appear in the last after all of its dependents have appeared
// (assuming there are no cycles in the graph).
func Sort(node Node) []Node {
	sorter := &sorter{make(map[string]bool),make(vector.Vector,0)}
	sorter.visit(node)
	nodes := make([]Node, sorter.sorted.Len())
	for i := 0; i < sorter.sorted.Len(); i++ { nodes[i] = sorter.sorted.At(i).(Node) }
	return nodes
}

type sorter struct {
	visited map[string] bool
	sorted vector.Vector
}

func (s *sorter) visit(node Node) {
	if s.visited[node.Id()] { return }

	s.visited[node.Id()] = true
	node.EachChild(func(child Node) {
		s.visit(child)
	})
	s.sorted.Push(node)
}
