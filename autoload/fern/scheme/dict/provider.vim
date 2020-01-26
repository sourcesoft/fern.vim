let s:Promise = vital#fern#import('Async.Promise')

function! fern#scheme#dict#provider#new(...) abort
  return {
        \ 'get_node': funcref('s:get_node'),
        \ 'get_parent': funcref('s:get_parent'),
        \ 'get_children': funcref('s:get_children'),
        \ '_tree': a:0 ? a:1 : deepcopy(s:sample_tree),
        \ '_parse_url': { u -> split(matchstr(u, '^dict:\zs.*$'), '/') },
        \ '_update_tree': { -> 0 },
        \ '_create_label': { n ->
        \   n.status
        \     ? n.name
        \     : printf('%s [%s]', n.name, n.concealed._value)
        \ },
        \ '_extend_node': { n -> n },
        \ '_root_name_factory': { -> 'root' },
        \ '_leaf_name_factory': { -> 'leaf' },
        \ '_branch_name_factory': { -> 'branch' },
        \}
endfunction

function! s:get_node(url) abort dict
  let terms = self._parse_url(a:url)
  let name = self._root_name_factory(a:url)
  let path = []
  let cursor = self._tree
  let node = s:node(self, path, name, cursor, v:null)
  for term in terms
    if !has_key(cursor, term)
      throw printf("no %s exists: %s", term, a:url)
    endif
    call add(path, term)
    let cursor = cursor[term]
    let node = s:node(self, path, term, cursor, node)
  endfor
  return node
endfunction

function! s:get_parent(node, ...) abort
  let parent = a:node.concealed._parent
  let parent = parent is# v:null ? copy(a:node) : parent
  return s:Promise.resolve(parent)
endfunction

function! s:get_children(node, ...) abort dict
  try
    if a:node.status is# 0
      throw printf("%s node is leaf", a:node.name)
    endif
    let ref = a:node.concealed._value
    let children = map(
          \ keys(ref),
          \ { _, v -> s:node(self, a:node._path + [v], v, ref[v], a:node)},
          \)
    return s:Promise.resolve(children)
  catch
    return s:Promise.reject(v:exception)
  endtry
endfunction

function! s:node(provider, path, name, value, parent) abort
  let status = type(a:value) is# v:t_dict
  let bufname = status ? printf('dict:/%s', join(a:path, '/')) : v:null
  let node = {
        \ 'name': a:name,
        \ 'status': status,
        \ 'bufname': bufname,
        \ 'concealed': {
        \   '_value': a:value,
        \   '_parent': a:parent,
        \ },
        \ '_path': a:path,
        \}
  let node.label = a:provider._create_label(node)
  return a:provider._extend_node(node)
endfunction


let s:sample_tree = {
      \ 'shallow': {
      \   'alpha': {},
      \   'beta': {},
      \   'gamma': 'value',
      \ },
      \ 'deep': {
      \   'alpha': {
      \     'beta': {
      \       'gamma': 'value',
      \     },
      \   },
      \ },
      \ 'leaf': 'value',
      \}
