-module(elixir_tree_helpers).
-export([build_bin/2, build_list/4, build_list/5, build_method_call/4, handle_new_call/4,
  build_var_name/2, convert_to_boolean/3]).
-include("elixir.hrl").

% Build a list transforming each expression and accumulating
% vars in one pass. It uses tail-recursive form.
%
% It receives a function to transform each expression given
% in Exprs, a Line used to build the List and the variables
% scope V is passed down item by item.
%
% The function needs to return a tuple where the first element
% is an erlang abstract form and the second is the new variables
% list.
build_list(Fun, Exprs, Line, S) ->
  build_list(Fun, Exprs, Line, S, {nil, Line}).

build_list(Fun, Exprs, Line, S, Tail) ->
  build_list_each(Fun, lists:reverse(Exprs), Line, S, Tail).

build_list_each(Fun, [], Line, S, Acc) ->
  { Acc, S };

build_list_each(Fun, [H|T], Line, S, Acc) ->
  { Expr, NS } = Fun(H, S),
  build_list_each(Fun, T, Line, NS, { cons, Line, Expr, Acc }).

% Build binaries
build_bin(Line, Exprs) ->
  Transformer = fun (X) -> { bin_element, Line, X, default, default } end,
  { bin, Line, lists:map(Transformer, Exprs) }.

% Handles method calls. It performs no transformation and assumes
% all data is already transformed.
build_method_call(Name, Line, Args, Expr) ->
  FArgs = handle_new_call(Name, Line, Args, false),
  ?ELIXIR_WRAP_CALL(Line, elixir_dispatch, dispatch, [Expr, {atom, Line, Name}, FArgs]).

% Handle method dispatches to new by wrapping everything in an array
% as we don't have a splat operator. If true is given as last option,
% the items should be wrapped in a list, by creating a list. If false,
% it is already an list so we just need a cons-cell.
handle_new_call(new, Line, Args, true) ->
  { List, [] } = build_list(fun(X,Y) -> {X,Y} end, Args, Line, []),
  [List];

handle_new_call(new, Line, Args, false) ->
  {cons, Line, Args, {nil, Line}};

handle_new_call(_, _, Args, _) ->
  Args.

% Builds a variable name.
build_var_name(Line, #elixir_scope{counter=Counter} = S) ->
  NS = S#elixir_scope{counter=Counter+1},
  Var = { var, Line, ?ELIXIR_ATOM_CONCAT(["X", Counter]) },
  { Var, NS }.

% Convert the given expression to a boolean value: true or false.
% Assumes the given expressions was already transformed.
convert_to_boolean(Line, Expr, Bool) ->
  Any   = [{var, Line, '_'}],
  False = [{atom,Line,false}],
  Nil   = [{atom,Line,nil}],

  FalseResult = [{atom,Line,not Bool}],
  TrueResult  = [{atom,Line,Bool}],

  { 'case', Line, Expr, [
    { clause, Line, False, [], FalseResult },
    { clause, Line, Nil, [], FalseResult },
    { clause, Line, Any, [], TrueResult }
  ] }.