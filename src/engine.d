// date: 2012/04/18

module engine;
import graph;

import std.conv : to;
import std.container : redBlackTree;
import std.typecons : tuple, Tuple;
import std.array : array, insertInPlace, front, back, popFront;
import std.algorithm : min;
import std.string	: join;
import std.format;

enum SearchMode{
  Shortest,
  WideSpread
}

/**
   Search shortest path
 */
void dijkstra_search(Graph g, Node[] via, SearchMode mode){
  auto start_node = via[0];
  auto goal_node = via[$-1];
  
  // push adjacency edge of start node to pq
  Edge[] departures = [];
  foreach(next; g.adjacency_edge(start_node)){
    departures ~= next;
  }
  
  auto rbt = redBlackTree!("a.source.cost + a.weight < b.source.cost + b.weight", true)(departures);
  auto make_delay = (Edge edg, int diff) {
    assert(diff>=0, "diff don't allow minus!! :" ~ to!string(edg) ~ " " ~ to!string(diff));
    DelayTime dly;
    dly.edge = edg;
    dly.diff = diff;
    return dly;
  };
  
  while(!rbt.empty){
    auto edg = rbt.front(); rbt.removeFront();
    //in_loop edg
    
    auto current = edg.target;
    auto cost = edg.source.cost + edg.weight;
    if(current.visited){
      //already visited
      current.visited_edges ~= make_delay(edg, cost - current.cost);
    } else {
      //not visited
      current.visited = true;
      current.cost = cost;
      current.visited_edges ~= make_delay(edg, 0);

      if(mode == SearchMode.Shortest && current == goal_node){
        // "reach goal node and stop"
        break;
      }

      foreach(next; g.adjacency_edge(current)){
        // next
        if(next.target.visited && next.target.is_visited_edge(next)) {
          // "already visited"
          continue;
        }
        rbt.insert(next);
      }      
    }
  }
}

alias Node[] Path;
alias Path[] Pathes;

/**
   Find shortest path
 */
Path dijkstra_path(Graph g, Node[] via) {
  g.dijkstra_search(via, SearchMode.Shortest);
  Node[] answer = [via[$-1]];
  while(!answer[0].visited_edges.empty){
    auto fastest = answer[0].visited_edges[0];
    answer.insertInPlace(0, fastest.edge.source);
  }
  return answer;
}


/**
   Find k-shortest path
 */
Pathes dijkstra_k_path(Graph g, Node[] via, int answer_count){

  enum max_cost_value = 1 << 28;
  
  class ResultTreeNode {
    int index;
    int cost;
    int upper_cost = max_cost_value;
    int lower_cost = max_cost_value;
    DelayTime[] delaytimes;
    ResultTreeNode parent = null;
    ResultTreeNode[] siblings;
    Edge edge;

    override string toString(){
      auto writer = appender!string();
      formattedWrite(writer, "TNode{ix:%d,%s,lower_cost:%d upper_cost:%d}", this.index, this.edge.id, this.lower_cost, this.upper_cost);
      return writer.data;
    }

    override int opCmp(Object o){
      ResultTreeNode other = cast(ResultTreeNode) o;
      if(other is null){
        return -1;
      }else{
        return this.lower_cost < other.lower_cost;
      }
    }
  }
  
  class ResultTree {
    ResultTreeNode[] nodes;
    bool[Node] visited_node;

    void update_lower_cost(ResultTreeNode node){
      /*
                o <- 引数のnode
               / \    ------
              /   \    * * * <- nodeの到達した弧(node.delaytimes)
             /     \  ------
            /       o <- 以前に作成された結果木ノード(node.siblings)
           /
          o <- nodeの到達した弧をもとにつぎにつくられるノード
        
        node.siblings.lower_cost
        次に作られる弧で最小をセット
      */

      auto sibling_cost = max_cost_value;
      if(node.siblings.length != 0){
        sibling_cost = node.siblings[0].lower_cost;
      }
      
      auto next_cost = max_cost_value;
      if(node.delaytimes.length != 0){
        auto head = node.delaytimes[0];
        next_cost = head.diff;
      }
      node.lower_cost = node.cost + min(sibling_cost, next_cost);
    }

    void update_upper_cost(ResultTreeNode node){
      /*
                o <- 親
               / \    ------
              /   \    * * * <- 親の到達した弧
             /     \  ------
            /       o <- 以前に作成された結果木ノード(親.sibling)
           /
          o <-- 引数のnode
         
        親に到達した弧の最小コスト(つぎにつくられそうな子ノード
        親.siblingのlower_cost
        親のupper_cost - 親のcost
        のみっつのうち最小のものを引数nodeのupper_costとする    
      */
      if(node.parent !is null){
        auto parent = node.parent;
        
        auto parent_sibling_cost = max_cost_value;
        if(!parent.siblings.empty){
          parent_sibling_cost = node.parent.siblings[0].lower_cost;
        }

        auto next_sibling_cost = max_cost_value;
        if(!parent.delaytimes.empty){
          next_sibling_cost = parent.delaytimes[0].diff;
        }
        
        auto extended_cost = parent.upper_cost - parent.cost;

        node.upper_cost = min(parent_sibling_cost, next_sibling_cost, extended_cost);
      }
    }
    
    ResultTreeNode add_node(Edge edg, int cost, ResultTreeNode parent){
      auto node = new ResultTreeNode();
      node.index = to!int(this.nodes.length);
      node.cost = cost;
      node.delaytimes = edg.source.visited_edges.dup;
      node.parent = parent;
      node.edge = edg;
      
      this.update_lower_cost(node);
      this.update_upper_cost(node);
      this.nodes ~= node;
      return node;
    }

    void update_sibling(ResultTreeNode target_node, ResultTreeNode sibling){
      if(!target_node.siblings.find(sibling)){
        target_node.siblings ~= sibling;
      }
    }

    bool is_visited(Node node){
      return (node in this.visited_node) !is null;
    }

    void visit(Node node){
      this.visited_node[node]=true;
    }

    void reset_visit(Node node){
      this.visited_node.remove(node);
    }
  }
  
  auto start_node = via[0];
  auto goal_node = via[$-1];

  // start_node | goal_node

  g.dijkstra_search(via, SearchMode.WideSpread);
  
  auto tree = new ResultTree();
  auto goal_tree_node = tree.add_node(new Edge(null, goal_node, new Node(null, int.max), int.max), 0, null);

  auto ix = goal_tree_node.index;
  Node[][] answers;

  while(!(tree.nodes[ix].upper_cost >= max_cost_value && tree.nodes[ix].lower_cost >= max_cost_value)){
    // ix | tree.nodes[ix]
    auto current = tree.nodes[ix];

    if(current.upper_cost >= current.lower_cost){
      // "down"

      auto sibling_cost = max_cost_value;
      if(!current.siblings.empty){
        sibling_cost = current.siblings[0].lower_cost;
      }
      
      if(!current.delaytimes.empty && current.delaytimes[0].diff <= sibling_cost){
        auto delaytime_head = current.delaytimes.front;
        current.delaytimes.popFront();
        
        while(!current.delaytimes.empty && tree.is_visited(current.delaytimes.front.edge.source)) {
          current.delaytimes.popFront();
        }

        auto next_edge = delaytime_head.edge;
        auto next_cost = delaytime_head.diff;

        if (tree.is_visited(next_edge.source)) {
          // already visited, it closed walk
          tree.update_lower_cost(current);
          continue;
        }

        if (next_edge.source == start_node) {
          // "goaal"
          
          auto answer = [start_node];
          auto tmp = current;
          while(true){
            answer ~= tmp.edge.source;
            if(tmp.parent is null){
              break;
            }
            tmp = tmp.parent;
          }
          
          answers ~= answer;
          if(answers.length >= answer_count){
            break;
          }
          tree.update_lower_cost(current);
          
        } else {
          auto next_node = tree.add_node(next_edge, next_cost, current);
          tree.visit(next_edge.source);
          ix = next_node.index;
        }
      } else {
        
        //sort siblings
        // current.siblings
        current.siblings = current.siblings.sort;
        // current.siblings
        
        //and jump to lowest sibling
        auto jump_sibling = current.siblings.front;
        assert(current.lower_cost == jump_sibling.lower_cost, "does not match lower_cost");

        tree.update_upper_cost(jump_sibling);
        tree.update_lower_cost(jump_sibling);

        ix = jump_sibling.index;
      }
    } else {
      // "upp"
      /* 上の結果木ノードに最短経路がふくまれているので、backtrack
        その道上で次の最短時間のヒントを収集していく

                  根
                 /
                o
               / \
              o   o <- ｺｺﾆｻｲﾀﾝﾛ
             /
            o <- ｲﾏｺｺ
        */
      
      auto parent = current.parent;
      tree.reset_visit(current.edge.source);
      tree.update_sibling(parent, current);
      tree.update_lower_cost(parent);
      ix = parent.index;
    }
  }
  
  return answers;
}

unittest{
  Graph build_network(){
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
    return g;
  }

  auto g = build_network();
  auto path = g.dijkstra_path([g.node("B"), g.node("F")]);
  assert(path == [g.node("B"), g.node("C"), g.node("G"), g.node("H"), g.node("F")]);
}

unittest{
  import std.array;
  
  alias Tuple!(string, string, int) Edg;
  Graph build_network(Edg[] edgs){
    Graph g = new Graph();
    foreach(edg;edgs){
      // tupleが展開されればな..
      // g.add_edge(edg);
      g.add_edge(edg[0], edg[1], edg[2]);
    }
    return g;
  }
  
  auto g = build_network([
      tuple("A", "B", 20), 
      tuple("A", "G", 10),
      tuple("G", "B", 5),
      tuple("A", "H", 1),
      tuple("B", "C", 6),
      tuple("H", "C", 5),
      tuple("H", "F", 2),
      tuple("H", "E", 50),
      tuple("C", "D", 4),
      tuple("F", "D", 3),
      tuple("D", "E", 8)]);
  auto result = g.dijkstra_k_path([g.node("A"), g.node("E")], 5);
  assert(result.length == 5);
  assert(result == [
      g.nodes_from(["A", "H", "F", "D", "E"]), 
      g.nodes_from(["A", "H", "C", "D", "E"]), 
      g.nodes_from(["A", "G", "B", "C", "D", "E"]), 
      g.nodes_from(["A", "B", "C", "D", "E"]), 
      g.nodes_from(["A", "H", "E"])]);


  auto g2 = build_network([
      tuple("A", "G", 10),
      tuple("A", "B", 10),
      tuple("G", "B", 50),
      tuple("B", "C", 20),
      tuple("A", "F", 60),
      tuple("F", "E", 10),
      tuple("E", "C", 5),
      tuple("C", "D", 30),
      tuple("E", "D", 10),
      tuple("A", "H", 70),
      tuple("H", "E", 10)]);

  auto result2 = g2.dijkstra_k_path([g2.node("A"), g2.node("D")], 10);
  // foreach(Node[] r;result2){
  //   foreach(Node n;r){
  //     stderr.write(n.id ~ " ");
  //   }
  //   stderr.writeln("");
  // }
  
  assert(result2 == [
      g2.nodes_from(["A", "B", "C", "D"]), 
      g2.nodes_from(["A", "F", "E", "D"]), 
      g2.nodes_from(["A", "H", "E", "D"]), 
      g2.nodes_from(["A", "F", "E", "C", "D"]), 
      g2.nodes_from(["A", "G", "B", "C", "D"])]);
}