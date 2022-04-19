use math
use str
use re

fn make-assertion {
  |name f &fixtures=[&] &store=[&]|
  put [&name=$name &f=$f &fixtures=$fixtures &store=$store]
}

fn is-assertion {
  |form|
  and (eq (kind-of $form) map) ^
      has-key $form f ^
      (eq (kind-of $form[f]) fn)
}

fn call-test {
  |test-fn &fixtures=[&] &store=[&]|

  var test-args = $test-fn[arg-names]

  if (and (has-value $test-args fixtures) (has-value $test-args store)) {
    $test-fn $fixtures $store
  } elif (has-value $test-args store) {
    $test-fn $store
  } elif (has-value $test-args fixtures) {
    $test-fn $fixtures
  } else {
    $test-fn
  }
}

fn call-predicate {
  |predicate @reality &fixtures=[&] &store=[&]|

  var pred-opts = $predicate[opt-names]

  if (> (count $pred-opts) 0) {
    $predicate $@reality &fixtures=$fixtures &store=$store
  } else {
    $predicate $@reality
  }
}

fn assert {
  |expect predicate &fixtures=[&] &store=[&] &name=assert
   &docstring='base-level assertion.  avoid unless you need a predicate'
   &arglist=[[expect anything 'a function name (str), or the expected value']
             [predicate fn 'single-arity. might have optional fixtures & store']
             [fixtures list 'immutable list']
             [store list 'list which tests can persist changes to']]|
  make-assertion $name {
    |test-fn &store=[&]|

    var new-store = $store

    # call test
    var @res = (var err = ?(call-test $test-fn &fixtures=$fixtures &store=$store))
    var reality = $res

    if (and (eq $err $ok) (has-value $test-fn[arg-names] store)) {
      if (== (count $reality) 0) {
        fail 'Test '{$test-fn[body]}' took store but did not emit store.  Empty response.'
      } elif (not (eq (kind-of $reality[0]) map)) {
        fail 'test '{$test-fn[body]}' took store but did not emit store as a map.  response[0]='{(to-string $reality[0])}
      } else {
        set new-store @reality = $@reality
      }
    }

    if (not-eq $err $ok) {
      set reality = [$err]
      set res = [$err]
    }

    # call predicate
    var bool @messages = (call-predicate $predicate $@reality &fixtures=$fixtures &store=$new-store)

    put [&bool=$bool &expect=$expect &reality=$res
         &test=(str:trim $test-fn[body] ' ') &messages=$messages
         &store=$new-store]
  } &fixtures=$fixtures &store=$store
}

fn is-one {
  |expectation &fixtures=[&] &store=[&]|
  assert $expectation {|@reality|
    and (== (count $reality) 1) ^
        (eq $expectation $@reality)
  } &name=is-one &fixtures=$fixtures &store=$store
}

fn is-each {
  |@expectation &fixtures=[&] &store=[&]|
  assert $expectation {|@reality|
    eq $expectation $reality
  } &name=is-each &fixtures=$fixtures &store=$store
}

fn is-differences-empty {
  |@expectation &fixtures=[&] &store=[&]|
  assert $expectation {|@reality|
    var to-map = {|l|
      var m = [&]
      for x $l {
        set m = (assoc $m $x $nil)
      }
      put $m
    }
    var ex re = ($to-map $expectation) ($to-map $reality)

    var diff = {|a b|
      for x [(keys $a)] {
        set b = (dissoc $b $x)
      }
      put [(keys $b)]
    }
    var diff1 diff2 = ($diff $ex $re) ($diff $re $ex)

    and (eq $diff1 []) (eq $diff2 [])

  } &name=is-differences-empty &fixtures=$fixtures &store=$store
}

fn is-error {
  |&fixtures=[&] &store=[&]|
  assert exception {|@reality|
    and (== (count $reality) 1) ^
        (not-eq $@reality $ok) ^
        (eq (kind-of $@reality) exception)
  } &name=is-error &fixtures=$fixtures &store=$store
}

fn is-something {
  |&fixtures=[&] &store=[&]|
  assert something {|@reality|
    var @kinds = (each $kind-of~ $reality)
    and (> (count $kinds) 0) ^
        (or (has-value $kinds list) ^
            (has-value $kinds map) ^
            (has-value $kinds fn) ^
            (has-value $kinds num) ^
            (has-value $kinds string))
  } &name=is-something &fixtures=$fixtures &store=$store
}

fn is-nothing {
  |&fixtures=[&] &store=[&]|
  assert nothing {|@reality|
    eq $reality []
  } &name=is-nothing &fixtures=$fixtures &store=$store
}

fn is-list {
  |&fixtures=[&] &store=[&]|
  assert list {|@reality|
    and (== (count $reality) 1) ^
        (eq (kind-of $@reality) list)
  } &name=is-list &fixtures=$fixtures &store=$store
}

fn is-map {
  |&fixtures=[&] &store=[&]|
  assert map {|@reality|
    and (== (count $reality) 1) ^
        (eq (kind-of $@reality) map)
  } &name=is-map &fixtures=$fixtures &store=$store
}

fn is-coll {
  |&fixtures=[&] &store=[&]|
  assert collection {|@reality|
    and (== (count $reality) 1) ^
        (has-value [list map] (kind-of $@reality))
  } &name=is-coll &fixtures=$fixtures &store=$store
}

fn is-fn {
  |&fixtures=[&] &store=[&]|
  assert fn {|@reality|
    and (== (count $reality) 1) ^
        (eq (kind-of $@reality) fn)
  } &name=is-fn &fixtures=$fixtures &store=$store
}

fn is-num {
  |&fixtures=[&] &store=[&]|
  assert number {|@reality|
    and (== (count $reality) 1) ^
        (eq (kind-of $@reality) number)
  } &name=is-num &fixtures=$fixtures &store=$store
}

fn is-string {
  |&fixtures=[&] &store=[&]|
  assert string {|@reality|
    and (== (count $reality) 1) ^
        (eq (kind-of $@reality) string)
  } &name=is-string &fixtures=$fixtures &store=$store
}

fn is-nil {
  |&fixtures=[&] &store=[&]|
  assert nil {|@reality|
    and (== (count $reality) 1) ^
        (eq (kind-of $@reality) nil)
  } &name=is-nil &fixtures=$fixtures &store=$store
}

fn test {
  |tests &break=break &docstring='test runner'|

  if (not-eq (kind-of $tests) list) {
    fail 'tests must be a list'
  }

  if (eq $tests []) {
    fail 'missing header'
  }

  var test-elements subheader
  var subheaders = []
  var header @els = $@tests

  if (not-eq (kind-of $header) string) {
    fail 'missing header'
  }

  put $break
  put $header

  for el $els {

    var assertion

    if (eq (kind-of $el) string) {
      put $el
      continue
    }

    put $break

    if (not-eq (kind-of $el) list) {
      fail 'expected list or string, got '{(kind-of $el)}
    }

    if (or (== (count $el) 0) (not-eq (kind-of $el[0]) string)) {
      fail 'missing subheader'
    }

    set subheader @test-elements = $@el

    put $subheader
    set subheaders = [$@subheaders $subheader]

    var store

    for tel $test-elements {
      if (eq (kind-of $tel) string) {
        put $tel
      } elif (is-assertion $tel) {
        set assertion = $tel
        set store = $assertion[store]
      } elif (eq (kind-of $tel) fn) {
        if (eq $assertion $nil) {
          fail 'no assertion before '{$tel[def]}
        }
        var last-test = ($assertion[f] $tel &store=$store)
        set store = $last-test[store]
        assoc $last-test subheader $subheader
      } else {
        fail {(to-string $tel)}' is invalid'
      }

    }

  }

  put $subheaders
}

fn is-test {
  |x|
  and (eq (kind-of $x) map) ^
      (has-key $x bool) ^
      (has-key $x expect) ^
      (has-key $x reality) ^
      (has-key $x test) ^
      (has-key $x messages) ^
      (has-key $x store)
}

fn stats {
  |@xs|

  var @tests = (each {|x| if (is-test $x) { put $x }} $xs)
  var @working-tests = (each {|t| if (eq $t[bool] $true) { put $t }} $tests)

  echo {(count $working-tests)}' tests passed out of '{(count $tests)}
  echo
  echo {(math:floor (* 100 (/ (count $working-tests) (count $tests))))}'% of tests are passing'
  echo

}

fn format-test {
  |body &style-fn={|s| put $s} &fancy=$true|
  if (not (re:match \n $body)) {
    put [($style-fn $body)]
    return
  }
  var spaces = 0
  var @lines = (re:split \n $body | each {|s| str:trim $s ' '})

  if $fancy {
    put [(styled (str:from-codepoints 0x250F) white bold)]
  }

  for line $lines {
    if (re:match '^}.*' $line) { # ends with }
      set spaces = (- $spaces 2)
    }

    if $fancy {
      put [(styled (str:from-codepoints 0x2503) white bold)
           ' ' (repeat $spaces ' ' | str:join '')
           ($style-fn $line)]
    } else {
      put [' ' (repeat $spaces ' ' | str:join '')
           ($style-fn $line)]
    }

    if (or (re:match '.*{$' $line) ^
           (re:match '.*\^$' $line) ^
           (and (re:match '.*\[.*' $line) ^
                (not (re:match '.*\].*' $line))) ^
           (re:match '.*{\ *\|[^\|]*\|$' $line)) {
      set spaces = (+ $spaces 2)
    }
  }
}

fn plain {
  |break @xs subheaders|
  var info-text = {|s| styled $s white }
  var header-text = {|s| styled $s white bold }
  var error-text = {|s| styled $s red }
  var error-text-code = {|s| styled $s red bold italic}
  var success-text = {|s| styled $s green }

  var break-length = (if (< 80 (tput cols)) { put 80 } else { tput cols })
  var break-text = (repeat $break-length (str:from-codepoints 0x2500) | str:join '')

  var testmeta

  for x $xs {
    if (eq $x $break) {
      echo $break-text
    } elif (and (eq (kind-of $x) string) (has-value $subheaders $x)) {
      echo ($header-text $x)
    } elif (eq (kind-of $x) map) {
      set testmeta = $x
      if $testmeta[bool] {
        format-test $testmeta[test] &style-fn=$success-text | each {|line| echo $@line}
      } else {
        var expect = (to-string $testmeta[expect])
        var reality = (to-string $testmeta[reality])
        echo
        format-test $testmeta[test] &style-fn=$error-text-code | each {|line| echo $@line}
        echo ($error-text 'EXPECTED: '{$expect})
        echo ($error-text '     GOT: '{$reality})
        echo
      }
    }
  }

  stats $@xs
}

fn err {
  |break @xs subheaders|
  var header-text = {|s| styled $s white bold underlined }
  var error-text = {|s| styled $s red }
  var error-text-code = {|s| styled $s red bold italic}
  var info-text = {|s| styled $s white italic }
  var info-code = {|s| styled $s white bold italic }

  var break-length = (if (< 80 (tput cols)) { put 80 } else { tput cols })
  var break-text = (repeat $break-length (str:from-codepoints 0x2500) | str:join '')

  var testmeta

  for x $xs {
    if (eq (kind-of $x) map) {
      set testmeta = $x
      if (not $testmeta[bool]) {
        var expect = (to-string $testmeta[expect])
        var reality = (to-string $testmeta[reality])

        echo
        echo ($header-text $testmeta[subheader])
        format-test $testmeta[test] &style-fn=$error-text-code | each {|line| echo $@line}
        echo ($error-text 'EXPECTED: '{$expect})
        echo ($error-text '     GOT: '{$reality})

        if (> (count $testmeta[store]) 0) {
          echo ($header-text STORE)
          echo ($info-code $testmeta[store])
        }

        if (> (count $testmeta[messages]) 0) {
          echo ($header-text MESSAGES)
          for msg $testmeta[messages] {
            echo ($info-text $msg)
          }
          echo
        }

        echo
        echo $break-text
      }
    }
  }

}

fn md {
  |break header @xs subheaders|

  echo '# '{$header}

  echo '1. [testing-status](#testing-status)'

  var i = 2
  for subheader $subheaders {
    echo {$i}'. ['{$subheader}'](#'{$subheader}')'
    set i = (+ $i 1)
  }

  echo '***'
  echo '## testing-status'
  stats $@xs

  var last-reality last-bool
  var num-tests = 0
  var expectations = []
  var in-code-block = $false

  var close-code-block = {
    if (== (count $last-reality) 0) {
      echo '```'
      echo 'MATCHES EXPECTATIONS: `'{(to-string $expectations)}'`'
    } elif (== $num-tests 1) {
      each {|l| echo '▶ '{(to-string $l)}} $last-reality
      echo '```'
    } else {
      echo '```'
      echo '```elvish'
      each {|l| echo '▶ '{(to-string $l)}} $last-reality
      echo '```'
    }

    set in-code-block = $false
    set expectations = []
    set num-tests = 0
  }

  for line $xs {

    if (and $in-code-block ^
            (or (not-eq (kind-of $line) map) ^
                (not-eq $last-reality $line[reality]) ^
                (not-eq $last-bool $line[bool]))) {
      $close-code-block
    }

    if (has-value $subheaders $line) {
      echo '## '{$line}
    } elif (eq $line $break) {
      echo '***'
    } elif (eq (kind-of $line) string) {
      echo ' '
      echo $line
    } else {
      set last-reality = $line[reality]
      set last-bool = $line[bool]
      set num-tests = (+ $num-tests 1)

      # track expectations
      if (== (count $expectations) 0) {
        set expectations = [$line[expect]]
      } elif (not-eq $expectations[0] $line[expect]) {
        set expectations = [$line[expect] $@expectations]
      }

      if (not $line[bool]) {
        echo '**STATUS: FAILING**'
      }

      if (not $in-code-block) {
        echo '```elvish'
        set in-code-block = $true
      }

      format-test $line[test] &fancy=$false | each {|l| echo $@l}
    }
  }

  if $in-code-block {
    $close-code-block
  }

}

fn md-show {
  |@markdown &pager=$false|

  if (not-eq $ok ?(which glow)) {
    echo 'Glow required: https://github.com/charmbracelet/glow'
    return
  }

  var tmp = (mktemp rivglow-XXXXXXXXXX.md)

  for line $markdown {
    echo $line >> $tmp
  }

  if $pager {
    glow $tmp --pager
  } else {
    glow $tmp
  }

}

var tests = [Test.elv
  [make-assertion
   'lowest-level building-block for constructing assertions.  This makes assertion creation a bit easier by defaulting fixtures and store to empty maps.  This document will explain those later.'
   (is-map)
   { make-assertion foo { } }
   { make-assertion foo { } &fixtures=[&foo=bar]}
   { make-assertion foo { } &store=[&frob=nitz]}
   { make-assertion foo { } &fixtures=[&foo=bar] &store=[&frob=nitz]}]

  [is-assertion
   '`is-assertion` is a predicate for assertions.'
   (is-one $true)
   { make-assertion foo { put foo } | is-assertion (one) }

   '`is-assertion` only cares about the presence of `f` key'
   { make-assertion foo { } | dissoc (one) fixtures | dissoc (one) store | is-assertion (one) }

   'All other assertions satisfy the predicate'
   { assert foo { put $true } | is-assertion (one) }
   { is-one foo | is-assertion (one) }
   { is-each foo bar | is-assertion (one) }
   { is-differences-empty foo bar | is-assertion (one) }
   { is-error | is-assertion (one) }
   { is-something | is-assertion (one) }
   { is-nothing | is-assertion (one) }
   { is-list | is-assertion (one) }
   { is-map | is-assertion (one) }
   { is-coll | is-assertion (one) }
   { is-fn | is-assertion (one) }
   { is-num | is-assertion (one) }
   { is-string | is-assertion (one) }
   { is-nil | is-assertion (one) }]

  [helpers
   'These functions are useful if you are writing a low-level assertion like `assert`.  Your test function can be one of four forms, and `call-test` will dispatch based on argument-reflection.'
   'The following tests demonstrate that type of dispatch.'
   (is-one something)
   { call-test {|| put something} }
   { call-test {|store| put $store[x]} &store=[&x=something] }
   { call-test {|fixtures| put $fixtures[x]} &fixtures=[&x=something] }

   (is-each some thing)
   { call-test {|fixtures store| put $fixtures[x]; put $store[x]} &fixtures=[&x=some] &store=[&x=thing] }

   '`call-test` expects fixtures before store.  This test errors because the input args are swapped.'
   (is-error)
   { call-test {|store fixtures| put $fixtures[a]; put $store[b]} &fixtures=[&a=a] &store=[&b=b] }

   '`call-predicate` accepts two forms.'
   (is-one $true)
   { call-predicate {|@reality| eq $@reality foo} foo }
   { call-predicate {|@reality &fixtures=[&] &store=[&]|
                       == ($reality[0] $fixtures[x] $store[x]) -1
                    } $compare~ &fixtures=[&x=1] &store=[&x=2] }

   'Any other form will error'
   (is-error)
   { call-predicate {|@reality &store=[&]| eq $@reality foo} foo }
   { call-predicate {|@reality &fixtures=[&]| eq $@reality foo} foo }]

  [assert
   'assertions return the boolean result, the expected value, the values emmited from the test, the test body, any messages produced by the assertion, and the store (more on that later)'
   (is-one [&test='put foo' &expect=foo &bool=$true &store=[&] &messages=[] &reality=[foo]])
   { (assert foo {|@x| eq $@x foo})[f] { put foo } }

   'The expected value can be the exact value you want, or it can be a description of what you are testing for'
   (is-one string-with-foo)
   { (assert string-with-foo {|@x| str:contains $@x foo})[f] { put '--foo--' } | put (all)[expect] }

   'if your predicate takes a store, then the predicate must emit the store first'
   (assert [&foo=bar] {|@result &store=[&] &fixtures=[&]| eq $store[foo] bar})
   {|store| assoc $store foo bar; put foo }

   (is-error)
   { test [mytest [subheader {|store| put foo} ]] }

   'The `store` must be returned as a map'
   { test [mytest [subheader (is-one bar) {|store| put foo; put bar} ]] }]

  [high-level-assertions
   'general use-cases for each assertion'
   (is-one $true)
   { (is-one foo)[f] { put foo } | put (one)[bool] }
   { (is-each foo bar)[f] { put foo; put bar } | put (one)[bool] }
   { (is-differences-empty foo bar)[f] { put bar; put foo } | put (one)[bool] }
   { (is-error)[f] { fail foobar } | put (one)[bool] }
   { (is-something)[f] { put foo; put bar; put [foo bar] } | put (one)[bool] }
   { (is-nothing)[f] { } | put (one)[bool] }
   { (is-list)[f] { put [a b c] } | put (one)[bool] }
   { (is-map)[f] { put [&foo=bar] } | put (one)[bool] }
   { (is-fn)[f] { put { } } | put (one)[bool] }
   { (is-string)[f] { put foo } | put (one)[bool] }
   { (is-nil)[f] { put $nil } | put (one)[bool] }

   '`is-coll` works on lists and maps'
   { (is-coll)[f] { put [a b c] } | put (one)[bool] }
   { (is-coll)[f] { put [&foo=bar] } | put (one)[bool] }

   '`is-num` works on nums & floats.  It could expand to more types if elvish adds more in the future.'
   { (is-num)[f] { num 1 } | put (one)[bool] }
   { (is-num)[f] { float64 1 } | put (one)[bool] }

   '`is-ok` does not exist (yet), but you can get it with this.  In this example `{ put foo }` is the function we are testing for success.  We do not care about the return value - only that the function works without error'
   { (is-one $ok)[f] { var @_ = (var err = ?({ put foo })); put $err } | put (one)[bool] }

   (is-one $false)
   'Simply returning something is not enough for `is-something`.  A bunch of `$nil` values will fail, for instance'
   { (is-something)[f] { put $nil; put $nil; put $nil } | put (one)[bool] }]

  [test-runner-exceptions
   'The test runner emits information suitable for debugging and documentation.  Start by giving it nothing.'
   (is-error)
   { test $nil }

   'It should have told you it expects a list.  Give it a list.'
   { test [] }

   'Now it is complaining about a missing header.  Give it a header.'
   (is-something)
   { test [mytests] }

   'Our first victory!  But we have no tests yet.  A test is a function preceded by an assertion.  They are grouped in sub-lists.  First, test all the ways we can get that wrong.'
   (is-error)

   '$nil is not a list'
   { test [mytests $nil] }

   'This is missing a subheader'
   { test [mytests []] }

   'This is missing an assertion'
   { test [mytests ['bad test' { }]] }]
  [working-test-runner
   (is-something)
   'an arbitrary number of tests can follow an assertion, and text can be added to describe the tests'
   { test [mytests
           [foo-tests
           'All of the assertions the string "foo" satisfies'
           (is-string)
           { put foo }

           (is-something)
           { put foo}

           'Really, text can be added anywhere'
           (is-one foo)
           { put foo }]] }

   'Assertions which compose other assertions and predicates are planned.'

   'Fixtures can be supplied to tests.  They must be maps set in the assertion.'
   { test [mytests
           [fixture-test
            (is-one bar &fixtures=[&foo=bar])
            {|fixtures| put $fixtures[foo]}]]}

   'Stores can be supplied to tests, too.  These must be maps, too.  Stores persist changes from test to test and are reset with every assertion.'
   { test [mytests
           [store-test
            (assert whaky-test {|@results &fixtures=[&] &store=[&]|
              if (eq $store[x] foo) {
                eq $store[y] bar
              } elif (eq $store[x] bar) {
                eq $store[y] foo
              }
            })
            {|store| assoc $store x foo | assoc (one) y bar }
            {|store|
              if (eq $store[x] foo) {
                assoc $store x bar | assoc (one) y foo
              } else {
                put [&]
              }
            }]]}

   'A store can be initialized from an assertion also.'
   { test [mytests
           [store-test
            (is-one bar &store=[&foo=bar])
            {|store| put $store; put $store[foo]}]]}

   'However, when taking a store, the store must be the first element returned, even if no changes are made'
   (is-error)
   { test [mytests
           [store-test
            (is-one bar &store=[&foo=bar])
            {|store| put $store[foo]}]]}
  ]]
