package fig

// Types that implement the Node interface can be used with the 
// directed graph algorithms supplied in this package. 
type Node interface {

	// An arbitrary value that uniquely identifies
	// the node with the graph.
	Id() string

	// Calls the specified function for each node that 
	// this node depends on.
	EachChild(func(Node))
}

// An immutable, linked list of Nodes.
type NodeList struct {
	node   Node
	parent *NodeList
}

// Calculates the number of nodes in the list.
func (ns *NodeList) Len() int {
	l := 0
	for ; ns != nil; ns = ns.parent {
		l++
	}
	return l
}

// Concantenates the list of node ids using an arrow ("-->") separator.
func (nodes *NodeList) String() string {
	s := ""
	if nodes.parent != nil {
		s += nodes.parent.String()
		s += " --> "
	}
	s += nodes.node.Id()
	return s
}

func (nodes *NodeList) Slice() []Node {
	slice := make([]Node, nodes.Len())
	for i, _ := range slice {
		slice[i] = nodes.node
		nodes = nodes.parent
	}
	return slice
}
