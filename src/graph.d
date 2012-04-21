// date: 2012/04/18

module graph;

import std.algorithm : map, find;
import std.range : empty;
import std.array : array, appender;
import std.typecons : tuple, Tuple;
import std.format;

alias string node_id;
alias string edge_id;

alias Tuple!(Edge, "edge", int , "diff") DelayTime;

class Node{
  immutable node_id id;
  int cost;
  bool visited;
  DelayTime[] visited_edges; // delaytimes . .
  string[string] attributes;

  this(node_id id) {
    this(id, 0);
  }

  this(node_id id, int cost){
    this.id = id;
    this.cost = cost;
  }

  bool is_visited_edge(Edge edg){
    return !find!((a, b) => a.edge == b)(this.visited_edges, edg).empty;
  }
  
  override string toString(){
    auto writer = appender!string();
    formattedWrite(writer, "Node{id:%s,cost:%d,visited:%s}", this.id, this.cost, this.visited);
    return writer.data;
  }
}

class Edge{
  immutable edge_id id;
  Node source;
  Node target;
  int weight;
  string[string] attributes;

  this(edge_id id, Node source, Node target, int weight){
    this.id = id;
    this.source = source;
    this.target = target;
    this.weight = weight;
  }

  this(edge_id id, Node source, Node target){
    this(id, source, target, 0);
  }

  override string toString(){
    auto writer = appender!string();
    formattedWrite(writer, "Edge{id:%s,source:%s,target:%s,weight:%d}", this.id, this.source, this.target, this.weight);
    return writer.data;
  }

}

class Graph{
  Node[node_id] nodes;
  Edge[edge_id] edges;
  Edge[][Node] adjacency_list;

  Node add_node(node_id id) {
    if(!(id in nodes)){
      nodes[id] = new Node(id);
    }
    return nodes[id];
  }
  
  Node[] add_nodes(node_id[] ids ...){
    return array(map!(k => this.add_node(k))(ids));
  }
  
  /**
     Append edge from source and target
     and return edge
  */
  Edge add_edge(Node source, Node target, int weight) {
    auto id = make_edge_id(source, target);
    if(!(id in edges)){
      auto edg = new Edge(id, source, target);
      edg.weight = weight;
      edges[id] = edg;
      this.adjacency_list[source] ~= edg;
    }
    return edges[id];
  }

  Edge add_edge(node_id source,  node_id target, int weight){
    auto source_node = this.add_node(source);
    auto target_node = this.add_node(target);
    return this.add_edge(source_node, target_node, weight);
  }
  
  /**
     Return a list of successor nodes of specified node
   */
  Node[] successors(Node source){
    auto adj = this.adjacency_edge(source);
    return array(map!(e => e.target)(adj));
  }

  // optionでもう少し綺麗にやりたい
  Edge[] adjacency_edge(Node source){
    if(source in adjacency_list){
      return adjacency_list[source];
    }else{
      return [];
    }
  }

  /**
     Return the specified node 
   */
  Node node(node_id id){
    return nodes[id];
  }

  /**
     Return edge
   */
  Edge edge(Node source, Node target){
    return edges[make_edge_id(source, target)];
  }

  
  Node[] nodes_from(node_id[] ids){
    return array(map!(e => this.nodes[e])(ids));
  }
  
 private:
  edge_id make_edge_id(Node s, Node t){
    return s.id ~ "_" ~ t.id;
  }
}

unittest{
  Graph g = new Graph();
  auto nid = "hoge";
  auto node = g.add_node(nid);
  assert(g.nodes[nid].id == nid);
  assert(node.id == nid);
  assert(node.cost == 0);
  assert(node.visited == false);
  
  node.cost = 99;
  assert(g.nodes[nid].cost == 99);

  g.nodes[nid].visited=true;
  assert(node.visited==true);
}

unittest{
  Graph g = new Graph();
  auto nodes = g.add_nodes("A", "b", "C");
  assert(nodes[0].id == "A");
  assert(nodes[1].id == "b");
  assert(nodes[2].id == "C");

  nodes[1].cost = 82;
  assert(g.nodes[nodes[1].id].cost == 82);
}

unittest{
  Graph g = new Graph();
  g.add_nodes("A", "B", "C", "D", "E", "F", "G", "H", "I", "J", "K", "L", "O", "M", "Z");
  g.add_edge(g.node("A"), g.node("B"), 4);
  g.add_edge(g.node("E"), g.node("B"), 5);
  g.add_edge(g.node("B"), g.node("C"), 10);
  g.add_edge(g.node("C"), g.node("F"), 50);
  g.add_edge(g.node("C"), g.node("D"), 10);
  g.add_edge(g.node("D"), g.node("G"), 50);
  g.add_edge(g.node("C"), g.node("G"), 20);
  g.add_edge(g.node("G"), g.node("H"), 1);
  g.add_edge(g.node("H"), g.node("F"), 2);
  g.add_edge(g.node("H"), g.node("I"), 9);
  g.add_edge(g.node("H"), g.node("K"), 8);
  g.add_edge(g.node("H"), g.node("J"), 5);
  g.add_edge(g.node("J"), g.node("L"), 2);
  g.add_edge(g.node("K"), g.node("L"), 4);
  g.add_edge(g.node("I"), g.node("O"), 1);
  g.add_edge(g.node("O"), g.node("M"), 1);
  g.add_edge(g.node("M"), g.node("Z"), 15);
  g.add_edge(g.node("L"), g.node("Z"), 16);
  
  assert(g.adjacency_edge(g.node("Z")) == []);
  assert(g.adjacency_edge(g.node("C")).length == 3);

  auto successors_b = g.successors(g.node("B"));
  assert(successors_b == [g.node("C")]);
  auto successors_c = g.successors(g.node("C"));
  assert(successors_c.length == 3);
  assert(successors_c == [g.node("F"), g.node("D"), g.node("G")]);

  assert(g.edge(g.node("A"), g.node("B")).weight == 4);
}