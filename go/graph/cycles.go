package graph

// FindCycles returns a list of all cycles within the graph, using
// the Tarjan algorithm (http://en.wikipedia.org/wiki/Tarjan's_strongly_connected_components_algorithm)

func FindCycles(node Node) []*NodeList {
	t :=  &tarjanState{0, nil, make([]*NodeList, 10)[0:0], make(map[string]*nodeState)}
	return t.run(node)
}

type tarjanState struct {
	index int
	stack *NodeList
	cycles []*NodeList
	states map[string] *nodeState
}

type nodeState struct {
	index int
	lowlink int
}

func (t *tarjanState) run(node Node) []*NodeList {
	state := &nodeState{t.index, t.index}
	t.states[node.Id()] = state
	t.index++
	t.push(node)
	node.EachChild(func(child Node) {
		if t.states[child.Id()] == nil {
			t.run(child)
			state.lowlink = min(state.lowlink, t.states[child.Id()].lowlink)
		} else if contains(t.stack, child){
			state.lowlink = min(state.lowlink, t.states[child.Id()].index)
		}
	})
	if state.lowlink == state.index {
		var cycle *NodeList
		for {
			cycle = &NodeList{t.stack.node,cycle}
			t.stack = t.stack.parent
			if cycle.node == node { break }
		}

		// Skip "cycles" with just one node
		if cycle.parent != nil {
			l := len(t.cycles)
			t.cycles = t.cycles[0:l+1]
			t.cycles[l] = cycle
		}
	}
	return t.cycles
}

func (t *tarjanState) push(node Node) {
	t.stack = &NodeList{node, t.stack}
}

func contains(nodes *NodeList, node Node) bool {
	if nodes == nil { return false}
	if nodes.node == node { return true}
	
	return contains(nodes.parent, node)
}

func min(a int, b int) int {
	if a < b { return a }
	return b
}

