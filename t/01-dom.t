#!perl6

use lib 'lib';
use Test;
use DOM::Parser;

# Empty
is DOM::Parser.new,                     '',    'right result';
is DOM::Parser.new(''),                 '',    'right result';
is DOM::Parser.new.parse(''),          '',    'right result';
is DOM::Parser.new.at('p'),            Nil, 'no result';
is DOM::Parser.new.append-content(''), '',    'right result';
is DOM::Parser.new.all-text,           '',    'right result';

# Simple (basics)
my $dom = DOM::Parser.new(
    '<div><div FOO="0" id="a">A</div><div id="b">B</div></div>'
);
is $dom.at('#b').text, 'B', 'right text';
is-deeply [$dom.find('div[id]')».text], [<A B>],
    'found all div elements with id';
is $dom.at('#a').attr('foo'), 0, 'right attribute';
is $dom.at('#a').attr<foo>, 0, 'right attribute';
is "$dom", '<div><div foo="0" id="a">A</div><div id="b">B</div></div>',
  'right result';

# Build tree from scratch
is DOM::Parser.new.append-content('<p>').at('p').append-content('0').text, '0',
    'right text';

# Simple nesting with healing (tree structure)
$dom = DOM::Parser.new(qq:to/END/);
<foo><bar a="b&lt;c">ju<baz a23>s<bazz />t</bar>works</foo>
END
is $dom.tree[0], 'root', 'right type';
is $dom.tree[1][0], 'tag', 'right type';
is $dom.tree[1][1], 'foo', 'right tag';
is-deeply $dom.tree[1][2], {}, 'empty attributes';
is $dom.tree[1][3], $dom.tree, 'right parent';
is $dom.tree[1][4][0], 'tag', 'right type';
is $dom.tree[1][4][1], 'bar', 'right tag';
is-deeply $dom.tree[1][4][2], {a => 'b<c'}, 'right attributes';
is $dom.tree[1][4][3], $dom.tree[1], 'right parent';
is $dom.tree[1][4][4][0], 'text', 'right type';
is $dom.tree[1][4][4][1], 'ju',   'right text';
is $dom.tree[1][4][4][2], $dom.tree[1][4], 'right parent';
is $dom.tree[1][4][5][0], 'tag', 'right type';
is $dom.tree[1][4][5][1], 'baz', 'right tag';
is-deeply $dom.tree[1][4][5][2], {a23 => Nil}, 'right attributes';
is $dom.tree[1][4][5][3], $dom.tree[1][4], 'right parent';
is $dom.tree[1][4][5][4][0], 'text', 'right type';
is $dom.tree[1][4][5][4][1], 's',    'right text';
is $dom.tree[1][4][5][4][2], $dom.tree[1][4][5], 'right parent';
is $dom.tree[1][4][5][5][0], 'tag',  'right type';
is $dom.tree[1][4][5][5][1], 'bazz', 'right tag';
is-deeply $dom.tree[1][4][5][5][2], {}, 'empty attributes';
is $dom.tree[1][4][5][5][3], $dom.tree[1][4][5], 'right parent';
is $dom.tree[1][4][5][6][0], 'text', 'right type';
is $dom.tree[1][4][5][6][1], 't',    'right text';
is $dom.tree[1][4][5][6][2], $dom.tree[1][4][5], 'right parent';
is $dom.tree[1][5][0], 'text',  'right type';
is $dom.tree[1][5][1], 'works', 'right text';
is $dom.tree[1][5][2], $dom.tree[1], 'right parent';
is "$dom", qq:to/END/, 'right result';
<foo><bar a="b&lt;c">ju<baz a23>s<bazz></bazz>t</baz></bar>works</foo>
END

# Select based on parent
$dom = DOM::Parser.new(qq:to/END/);
<body>
  <div>test1</div>
  <div><div>test2</div></div>
<body>
END
is $dom.find('body > div')[0].text, 'test1', 'right text';
is $dom.find('body > div')[1].text, '',      'no content';
is $dom.find('body > div')[2], Nil, 'no result';
is $dom.find('body > div').elems, 2, 'right number of elements';
is $dom.find('body > div > div')[0].text, 'test2', 'right text';
is $dom.find('body > div > div')[1], Nil, 'no result';
is $dom.find('body > div > div').elems, 1, 'right number of elements';

# A bit of everything (basic navigation)
$dom = DOM::Parser.new.parse(qq:to/END/);
<!doctype foo>
<foo bar="ba&lt;z">
  test
  <simple class="working">easy</simple>
  <test foo="bar" id="test" />
  <!-- lala -.
  works well
  <![CDATA[ yada yada]]>
  <?boom lalalala ?>
  <a little bit broken>
  < very broken
  <br />
  more text
</foo>
END
ok !$dom.xml, 'XML mode not detected';
is $dom.tag, Nil, 'no tag';
is $dom.attr('foo'), Nil, 'no attribute';
is $dom.attr(foo => 'bar').attr('foo'), Nil, 'no attribute';
is $dom.tree[1][0], 'doctype', 'right type';
is $dom.tree[1][1], ' foo',    'right doctype';
is "$dom", qq:to/END/, 'right result';
<!DOCTYPE foo>
<foo bar="ba&lt;z">
  test
  <simple class="working">easy</simple>
  <test foo="bar" id="test"></test>
  <!-- lala -.
  works well
  <![CDATA[ yada yada]]>
  <?boom lalalala ?>
  <a bit broken little>
  &lt; very broken
  <br>
  more text
</a></foo>
END
my $simple = $dom.at('foo simple.working[class^="wor"]');
is $simple.parent.all-text,
  'test easy works well yada yada < very broken more text', 'right text';
is $simple.tag, 'simple', 'right tag';
is $simple.attr('class'), 'working', 'right class attribute';
is $simple.text, 'easy', 'right text';
is $simple.parent.tag, 'foo', 'right parent tag';
is $simple.parent.attr<bar>, 'ba<z', 'right parent attribute';
is $simple.parent.children[1].tag, 'test', 'right sibling';
is $simple.to-string, '<simple class="working">easy</simple>',
  'stringified right';
$simple.parent.attr(bar => 'baz').attr({this => 'works', too => 'yea'});
is $simple.parent.attr('bar'),  'baz',   'right parent attribute';
is $simple.parent.attr('this'), 'works', 'right parent attribute';
is $simple.parent.attr('too'),  'yea',   'right parent attribute';
is $dom.at('test#test').tag,              'test',   'right tag';
is $dom.at('[class$="ing"]').tag,         'simple', 'right tag';
is $dom.at('[class="working"]').tag,      'simple', 'right tag';
is $dom.at('[class$=ing]').tag,           'simple', 'right tag';
is $dom.at('[class=working][class]').tag, 'simple', 'right tag';
is $dom.at('foo > simple').next.tag, 'test', 'right tag';
is $dom.at('foo > simple').next.next.tag, 'a', 'right tag';
is $dom.at('foo > test').previous.tag, 'simple', 'right tag';
is $dom.next,     Nil, 'no siblings';
is $dom.previous, Nil, 'no siblings';
is $dom.at('foo > a').next,          Nil, 'no next sibling';
is $dom.at('foo > simple').previous, Nil, 'no previous sibling';
is-deeply [$dom.at('simple').ancestors».tag], ['foo'],
  'right results';
ok !$dom.at('simple').ancestors.first.xml, 'XML mode not active';

# Nodes
$dom = DOM::Parser.new(
  '<!DOCTYPE before><p>test<![CDATA[123]]><!-- 456 -.</p><?after?>');
is $dom.at('p').preceding-nodes.first.content, ' before', 'right content';
is $dom.at('p').preceding-nodes.elems, 1, 'right number of nodes';
is $dom.at('p').child-nodes.tail[0].preceding-nodes.first.content, 'test',
  'right content';
is $dom.at('p').child-nodes.tail[0].preceding-nodes.tail[0].content, '123',
  'right content';
is $dom.at('p').child-nodes.tail[0].preceding-nodes.elems, 2,
  'right number of nodes';
is $dom.preceding-nodes.elems, 0, 'no preceding nodes';
is $dom.at('p').following-nodes.first.content, 'after', 'right content';
is $dom.at('p').following-nodes.elems, 1, 'right number of nodes';
is $dom.child-nodes.first.following-nodes.first.tag, 'p', 'right tag';
is $dom.child-nodes.first.following-nodes.tail[0].content, 'after',
  'right content';
is $dom.child-nodes.first.following-nodes.elems, 2, 'right number of nodes';
is $dom.following-nodes.elems, 0, 'no following nodes';
is $dom.at('p').previous-node.content,       ' before', 'right content';
is $dom.at('p').previous-node.previous-node, Nil,     'no more siblings';
is $dom.at('p').next-node.content,           'after',   'right content';
is $dom.at('p').next-node.next-node,         Nil,     'no more siblings';
is $dom.at('p').child-nodes.tail[0].previous-node.previous-node.content,
  'test', 'right content';
is $dom.at('p').child-nodes.first.next-node.next-node.content, ' 456 ',
  'right content';
is $dom.descendant-nodes[0].type,    'doctype', 'right type';
is $dom.descendant-nodes[0].content, ' before', 'right content';
is $dom.descendant-nodes[0], '<!DOCTYPE before>', 'right content';
is $dom.descendant-nodes[1].tag,     'p',     'right tag';
is $dom.descendant-nodes[2].type,    'text',  'right type';
is $dom.descendant-nodes[2].content, 'test',  'right content';
is $dom.descendant-nodes[5].type,    'pi',    'right type';
is $dom.descendant-nodes[5].content, 'after', 'right content';
is $dom.at('p').descendant-nodes[0].type,    'text', 'right type';
is $dom.at('p').descendant-nodes[0].content, 'test', 'right type';
is $dom.at('p').descendant-nodes.tail[0].type,    'comment', 'right type';
is $dom.at('p').descendant-nodes.tail[0].content, ' 456 ',   'right type';
is $dom.child-nodes[1].child-nodes.first.parent.tag, 'p', 'right tag';
is $dom.child-nodes[1].child-nodes.first.content, 'test', 'right content';
is $dom.child-nodes[1].child-nodes.first, 'test', 'right content';
is $dom.at('p').child-nodes.first.type, 'text', 'right type';
is $dom.at('p').child-nodes.first.remove.tag, 'p', 'right tag';
is $dom.at('p').child-nodes.first.type,    'cdata', 'right type';
is $dom.at('p').child-nodes.first.content, '123',   'right content';
is $dom.at('p').child-nodes[1].type,    'comment', 'right type';
is $dom.at('p').child-nodes[1].content, ' 456 ',   'right content';
is $dom[0].type,    'doctype', 'right type';
is $dom[0].content, ' before', 'right content';
is $dom.child-nodes[2].type,    'pi',    'right type';
is $dom.child-nodes[2].content, 'after', 'right content';
is $dom.child-nodes.first.content(' again').content, ' again',
  'right content';
is $dom.child-nodes.grep(*.type eq 'pi')».remove.first.type, 'root', 'right type';
is "$dom", '<!DOCTYPE again><p><![CDATA[123]]><!-- 456 -.</p>', 'right result';

# Modify nodes
$dom = DOM::Parser.new('<script>la<la>la</script>');
is $dom.at('script').type, 'tag', 'right type';
is $dom.at('script')[0].type,    'raw',      'right type';
is $dom.at('script')[0].content, 'la<la>la', 'right content';
is "$dom", '<script>la<la>la</script>', 'right result';
is $dom.at('script').child-nodes.first.replace('a<b>c</b>1<b>d</b>').tag,
  'script', 'right tag';
is "$dom", '<script>a<b>c</b>1<b>d</b></script>', 'right result';
is $dom.at('b').child-nodes.first.append('e').content, 'c',
  'right content';
is $dom.at('b').child-nodes.first.prepend('f').type, 'text', 'right type';
is "$dom", '<script>a<b>fce</b>1<b>d</b></script>', 'right result';
is $dom.at('script').child-nodes.first.following.first.tag, 'b',
  'right tag';
is $dom.at('script').child-nodes.first.next.content, 'fce',
  'right content';
is $dom.at('script').child-nodes.first.previous, Nil, 'no siblings';
is $dom.at('script').child-nodes[2].previous.content, 'fce',
  'right content';
is $dom.at('b').child-nodes[1].next, Nil, 'no siblings';
is $dom.at('script').child-nodes.first.wrap('<i>:)</i>').root,
  '<script><i>:)a</i><b>fce</b>1<b>d</b></script>', 'right result';
is $dom.at('i').child-nodes.first.wrap-content('<b></b>').root,
  '<script><i>:)a</i><b>fce</b>1<b>d</b></script>', 'no changes';
is $dom.at('i').child-nodes.first.wrap('<b></b>').root,
  '<script><i><b>:)</b>a</i><b>fce</b>1<b>d</b></script>', 'right result';
is $dom.at('b').child-nodes.first.ancestors».tag.join(','),
  'b,i,script', 'right result';
is $dom.at('b').child-nodes.first.append-content('g').content, ':)g',
  'right content';
is $dom.at('b').child-nodes.first.prepend-content('h').content, 'h:)g',
  'right content';
is "$dom", '<script><i><b>h:)g</b>a</i><b>fce</b>1<b>d</b></script>',
  'right result';
is $dom.at('script > b:last-of-type').append('<!--y-.')
  .following-nodes.first.content, 'y', 'right content';
is $dom.at('i').prepend('z').preceding-nodes.first.content, 'z',
  'right content';
is $dom.at('i').following.last.text, 'd', 'right text';
is $dom.at('i').following.elems, 2, 'right number of following elements';
is $dom.at('i').following('b:last-of-type').first.text, 'd', 'right text';
is $dom.at('i').following('b:last-of-type').elems, 1,
  'right number of following elements';
is $dom.following.elems, 0, 'no following elements';
is $dom.at('script > b:last-of-type').preceding.first.tag, 'i', 'right tag';
is $dom.at('script > b:last-of-type').preceding.elems, 2,
  'right number of preceding elements';
is $dom.at('script > b:last-of-type').preceding('b').first.tag, 'b',
  'right tag';
is $dom.at('script > b:last-of-type').preceding('b').elems, 1,
  'right number of preceding elements';
is $dom.preceding.elems, 0, 'no preceding elements';
is "$dom", '<script>z<i><b>h:)g</b>a</i><b>fce</b>1<b>d</b><!--y-.</script>',
  'right result';

# XML nodes
$dom = DOM::Parser.new.xml(1).parse('<b>test<image /></b>');
ok $dom.at('b').child-nodes.first.xml, 'XML mode active';
ok $dom.at('b').child-nodes.first.replace('<br>').child-nodes.first.xml,
  'XML mode active';
is "$dom", '<b><br /><image /></b>', 'right result';

# Treating nodes as elements
$dom = DOM::Parser.new('foo<b>bar</b>baz');
is $dom.child-nodes.first.child-nodes.elems,      0, 'no nodes';
is $dom.child-nodes.first.descendant-nodes.elems, 0, 'no nodes';
is $dom.child-nodes.first.children.elems,         0, 'no children';
is $dom.child-nodes.first.strip.parent, 'foo<b>bar</b>baz', 'no changes';
is $dom.child-nodes.first.at('b'), Nil, 'no result';
is $dom.child-nodes.first.find('*').elems, 0, 'no results';
ok !$dom.child-nodes.first.matches('*'), 'no match';
is-deeply $dom.child-nodes.first.attr, {}, 'no attributes';
is $dom.child-nodes.first.namespace, Nil, 'no namespace';
is $dom.child-nodes.first.tag,       Nil, 'no tag';
is $dom.child-nodes.first.text,      '',    'no text';
is $dom.child-nodes.first.all-text,  '',    'no text';

# Class and ID
$dom = DOM::Parser.new('<div id="id" class="class">a</div>');
is $dom.at('div#id.class').text, 'a', 'right text';

# Deep nesting (parent combinator)
$dom = DOM::Parser.new(qq:to/END/);
<html>
  <head>
    <title>Foo</title>
  </head>
  <body>
    <div id="container">
      <div id="header">
        <div id="logo">Hello World</div>
        <div id="buttons">
          <p id="foo">Foo</p>
        </div>
      </div>
      <form>
        <div id="buttons">
          <p id="bar">Bar</p>
        </div>
      </form>
      <div id="content">More stuff</div>
    </div>
  </body>
</html>
END
my $p = $dom.find: 'body > #container > div p[id]';
is $p[0].attr('id'), 'foo', 'right id attribute';
is $p[1], Nil, 'no second result';
is $p.elems, 1, 'right number of elements';
@div  = $dom.find('div')».attr: 'id';
my @p = $dom.find('p')».attr: 'id';
is-deeply \@p, [<foo bar>], 'found all p elements';
my $ids = [<container header logo buttons buttons content>];
is-deeply \@div, $ids, 'found all div elements';
is-deeply [$dom.at('p').ancestors».tag],
  [<div div div body html>], 'right results';
is-deeply [$dom.at('html').ancestors], [], 'no results';
is-deeply [$dom.ancestors],             [], 'no results';

# Script tag
$dom = DOM::Parser.new(qq:to/END/);
<script charset="utf-8">alert('lalala');</script>
END
is $dom.at('script').text, "alert('lalala');", 'right script content';

# HTML5 (unquoted values)
$dom = DOM::Parser.new(
  '<div id = test foo ="bar" class=tset bar=/baz/ baz=//>works</div>');
is $dom.at('#test').text,                'works', 'right text';
is $dom.at('div').text,                  'works', 'right text';
is $dom.at('[foo=bar][foo="bar"]').text, 'works', 'right text';
is $dom.at('[foo="ba"]'), Nil, 'no result';
is $dom.at('[foo=bar]').text, 'works', 'right text';
is $dom.at('[foo=ba]'), Nil, 'no result';
is $dom.at('.tset').text,       'works', 'right text';
is $dom.at('[bar=/baz/]').text, 'works', 'right text';
is $dom.at('[baz=//]').text,    'works', 'right text';

# HTML1 (single quotes, uppercase tags and whitespace in attributes)
$dom = DOM::Parser.new(q{<DIV id = 'test' foo ='bar' class= "tset">works</DIV>});
is $dom.at('#test').text,       'works', 'right text';
is $dom.at('div').text,         'works', 'right text';
is $dom.at('[foo="bar"]').text, 'works', 'right text';
is $dom.at('[foo="ba"]'), Nil, 'no result';
is $dom.at('[foo=bar]').text, 'works', 'right text';
is $dom.at('[foo=ba]'), Nil, 'no result';
is $dom.at('.tset').text, 'works', 'right text';

# Already decoded Unicode snowman and quotes in selector
$dom = DOM::Parser.new: '<div id="snow&apos;m&quot;an">☃</div>';
is $dom.at('[id="snow\'m\"an"]').text,      '☃', 'right text';
is $dom.at('[id="snow\'m\22 an"]').text,    '☃', 'right text';
is $dom.at('[id="snow\'m\000022an"]').text, '☃', 'right text';
is $dom.at('[id="snow\'m\22an"]'),      Nil, 'no result';
is $dom.at('[id="snow\'m\21 an"]'),     Nil, 'no result';
is $dom.at('[id="snow\'m\000021an"]'),  Nil, 'no result';
is $dom.at('[id="snow\'m\000021 an"]'), Nil, 'no result';
is $dom.at("[id='snow\\'m\"an']").text,  '☃', 'right text';
is $dom.at("[id='snow\\27m\"an']").text, '☃', 'right text';

# Unicode and escaped selectors
my $html
  = '<html><div id="☃x">Snowman</div><div class="x ♥">Heart</div></html>';
$dom = DOM::Parser.new: $html;
is $dom.at("#\\\n\\002603x").text,                  'Snowman', 'right text';
is $dom.at('#\\2603 x').text,                       'Snowman', 'right text';
is $dom.at("#\\\n\\2603 x").text,                   'Snowman', 'right text';
is $dom.at(qq{[id="\\\n\\2603 x"]}).text,           'Snowman', 'right text';
is $dom.at(qq{[id="\\\n\\002603x"]}).text,          'Snowman', 'right text';
is $dom.at(qq{[id="\\\\2603 x"]}).text,             'Snowman', 'right text';
is $dom.at("html #\\\n\\002603x").text,             'Snowman', 'right text';
is $dom.at('html #\\2603 x').text,                  'Snowman', 'right text';
is $dom.at("html #\\\n\\2603 x").text,              'Snowman', 'right text';
is $dom.at(qq{html [id="\\\n\\2603 x"]}).text,      'Snowman', 'right text';
is $dom.at(qq{html [id="\\\n\\002603x"]}).text,     'Snowman', 'right text';
is $dom.at(qq{html [id="\\\\2603 x"]}).text,        'Snowman', 'right text';
is $dom.at('#☃x').text,                           'Snowman', 'right text';
is $dom.at('div#☃x').text,                        'Snowman', 'right text';
is $dom.at('html div#☃x').text,                   'Snowman', 'right text';
is $dom.at('[id^="☃"]').text,                     'Snowman', 'right text';
is $dom.at('div[id^="☃"]').text,                  'Snowman', 'right text';
is $dom.at('html div[id^="☃"]').text,             'Snowman', 'right text';
is $dom.at('html > div[id^="☃"]').text,           'Snowman', 'right text';
is $dom.at('[id^=☃]').text,                       'Snowman', 'right text';
is $dom.at('div[id^=☃]').text,                    'Snowman', 'right text';
is $dom.at('html div[id^=☃]').text,               'Snowman', 'right text';
is $dom.at('html > div[id^=☃]').text,             'Snowman', 'right text';
is $dom.at(".\\\n\\002665").text,                   'Heart',   'right text';
is $dom.at('.\\2665').text,                         'Heart',   'right text';
is $dom.at("html .\\\n\\002665").text,              'Heart',   'right text';
is $dom.at('html .\\2665').text,                    'Heart',   'right text';
is $dom.at(qq{html [class\$="\\\n\\002665"]}).text, 'Heart',   'right text';
is $dom.at(qq{html [class\$="\\2665"]}).text,       'Heart',   'right text';
is $dom.at(qq{[class\$="\\\n\\002665"]}).text,      'Heart',   'right text';
is $dom.at(qq{[class\$="\\2665"]}).text,            'Heart',   'right text';
is $dom.at('.x').text,                              'Heart',   'right text';
is $dom.at('html .x').text,                         'Heart',   'right text';
is $dom.at('.♥').text,                            'Heart',   'right text';
is $dom.at('html .♥').text,                       'Heart',   'right text';
is $dom.at('div.♥').text,                         'Heart',   'right text';
is $dom.at('html div.♥').text,                    'Heart',   'right text';
is $dom.at('[class$="♥"]').text,                  'Heart',   'right text';
is $dom.at('div[class$="♥"]').text,               'Heart',   'right text';
is $dom.at('html div[class$="♥"]').text,          'Heart',   'right text';
is $dom.at('html > div[class$="♥"]').text,        'Heart',   'right text';
is $dom.at('[class$=♥]').text,                    'Heart',   'right text';
is $dom.at('div[class$=♥]').text,                 'Heart',   'right text';
is $dom.at('html div[class$=♥]').text,            'Heart',   'right text';
is $dom.at('html > div[class$=♥]').text,          'Heart',   'right text';
is $dom.at('[class~="♥"]').text,                  'Heart',   'right text';
is $dom.at('div[class~="♥"]').text,               'Heart',   'right text';
is $dom.at('html div[class~="♥"]').text,          'Heart',   'right text';
is $dom.at('html > div[class~="♥"]').text,        'Heart',   'right text';
is $dom.at('[class~=♥]').text,                    'Heart',   'right text';
is $dom.at('div[class~=♥]').text,                 'Heart',   'right text';
is $dom.at('html div[class~=♥]').text,            'Heart',   'right text';
is $dom.at('html > div[class~=♥]').text,          'Heart',   'right text';
is $dom.at('[class~="x"]').text,                    'Heart',   'right text';
is $dom.at('div[class~="x"]').text,                 'Heart',   'right text';
is $dom.at('html div[class~="x"]').text,            'Heart',   'right text';
is $dom.at('html > div[class~="x"]').text,          'Heart',   'right text';
is $dom.at('[class~=x]').text,                      'Heart',   'right text';
is $dom.at('div[class~=x]').text,                   'Heart',   'right text';
is $dom.at('html div[class~=x]').text,              'Heart',   'right text';
is $dom.at('html > div[class~=x]').text,            'Heart',   'right text';
is $dom.at('html'), $html, 'right result';
is $dom.at('#☃x').parent,     $html, 'right result';
is $dom.at('#☃x').root,       $html, 'right result';
is $dom.children('html').first, $html, 'right result';
is $dom.to-string, $html, 'right result';
is $dom.content,   $html, 'right result';

# Looks remotely like HTML
$dom = DOM::Parser.new(
  '<!DOCTYPE H "-/W/D HT 4/E">☃<title class=test>♥</title>☃');
is $dom.at('title').text, '♥', 'right text';
is $dom.at('*').text,     '♥', 'right text';
is $dom.at('.test').text, '♥', 'right text';

# Replace elements
$dom = DOM::Parser.new('<div>foo<p>lalala</p>bar</div>');
is $dom.at('p').replace('<foo>bar</foo>'), '<div>foo<foo>bar</foo>bar</div>',
  'right result';
is "$dom", '<div>foo<foo>bar</foo>bar</div>', 'right result';
$dom.at('foo').replace(DOM::Parser.new('text'));
is "$dom", '<div>footextbar</div>', 'right result';
$dom = DOM::Parser.new('<div>foo</div><div>bar</div>');
$dom.find('div')».replace('<p>test</p>');
is "$dom", '<p>test</p><p>test</p>', 'right result';
$dom = DOM::Parser.new('<div>foo<p>lalala</p>bar</div>');
is $dom.replace('♥'), '♥', 'right result';
is "$dom", '♥', 'right result';
$dom.replace('<div>foo<p>lalala</p>bar</div>');
is "$dom", '<div>foo<p>lalala</p>bar</div>', 'right result';
is $dom.at('p').replace(''), '<div>foobar</div>', 'right result';
is "$dom", '<div>foobar</div>', 'right result';
is $dom.replace(''), '', 'no result';
is "$dom", '', 'no result';
$dom.replace('<div>foo<p>lalala</p>bar</div>');
is "$dom", '<div>foo<p>lalala</p>bar</div>', 'right result';
$dom.find('p')».replace('');
is "$dom", '<div>foobar</div>', 'right result';
$dom = DOM::Parser.new('<div>♥</div>');
$dom.at('div').content('☃');
is "$dom", '<div>☃</div>', 'right result';
$dom = DOM::Parser.new('<div>♥</div>');
$dom.at('div').content("\x{2603}");
is $dom.to-string, '<div>☃</div>', 'right result';
is $dom.at('div').replace('<p>♥</p>').root, '<p>♥</p>', 'right result';
is $dom.to-string, '<p>♥</p>', 'right result';
is $dom.replace('<b>whatever</b>').root, '<b>whatever</b>', 'right result';
is $dom.to-string, '<b>whatever</b>', 'right result';
$dom.at('b').prepend('<p>foo</p>').append('<p>bar</p>');
is "$dom", '<p>foo</p><b>whatever</b><p>bar</p>', 'right result';
is $dom.find('p').map('remove').first.root.at('b').text, 'whatever',
  'right result';
is "$dom", '<b>whatever</b>', 'right result';
is $dom.at('b').strip, 'whatever', 'right result';
is $dom.strip,  'whatever', 'right result';
is $dom.remove, '',         'right result';
$dom.replace('A<div>B<p>C<b>D<i><u>E</u></i>F</b>G</p><div>H</div></div>I');
is $dom.find(':not(div):not(i):not(u)')».strip.first.root,
  'A<div>BCD<i><u>E</u></i>FG<div>H</div></div>I', 'right result';
is $dom.at('i').to-string, '<i><u>E</u></i>', 'right result';
$dom = DOM::Parser.new('<div><div>A</div><div>B</div>C</div>');
is $dom.at('div').at('div').text, 'A', 'right text';
$dom.at('div').find('div')».strip;
is "$dom", '<div>ABC</div>', 'right result';

# Replace element content
$dom = DOM::Parser.new('<div>foo<p>lalala</p>bar</div>');
is $dom.at('p').content('bar'), '<p>bar</p>', 'right result';
is "$dom", '<div>foo<p>bar</p>bar</div>', 'right result';
$dom.at('p').content(DOM::Parser.new('text'));
is "$dom", '<div>foo<p>text</p>bar</div>', 'right result';
$dom = DOM::Parser.new('<div>foo</div><div>bar</div>');
$dom.find('div')».content('<p>test</p>');
is "$dom", '<div><p>test</p></div><div><p>test</p></div>', 'right result';
$dom.find('p')».content('');
is "$dom", '<div><p></p></div><div><p></p></div>', 'right result';
$dom = DOM::Parser.new('<div><p id="☃" /></div>');
$dom.at('#☃').content('♥');
is "$dom", '<div><p id="☃">♥</p></div>', 'right result';
$dom = DOM::Parser.new('<div>foo<p>lalala</p>bar</div>');
$dom.content('♥');
is "$dom", '♥', 'right result';
is $dom.content('<div>foo<p>lalala</p>bar</div>'),
  '<div>foo<p>lalala</p>bar</div>', 'right result';
is "$dom", '<div>foo<p>lalala</p>bar</div>', 'right result';
is $dom.content(''), '', 'no result';
is "$dom", '', 'no result';
$dom.content('<div>foo<p>lalala</p>bar</div>');
is "$dom", '<div>foo<p>lalala</p>bar</div>', 'right result';
is $dom.at('p').content(''), '<p></p>', 'right result';

# Mixed search and tree walk
$dom = DOM::Parser.new(qq:to/END/);
<table>
  <tr>
    <td>text1</td>
    <td>text2</td>
  </tr>
</table>
END
my @data;
for $dom.find('table tr') -> $tr {
  for $tr.children -> $td {
    push @data, $td.tag, $td.all-text;
  }
}
is $data[0], 'td',    'right tag';
is $data[1], 'text1', 'right text';
is $data[2], 'td',    'right tag';
is $data[3], 'text2', 'right text';
is $data[4], Nil,   'no tag';

# RSS
$dom = DOM::Parser.new(qq:to/END/);
<?xml version="1.0" encoding="UTF-8"?>
<rss xmlns:atom="http://www.w3.org/2005/Atom" version="2.0">
  <channel>
    <title>Test Blog</title>
    <link>http://blog.example.com</link>
    <description>lalala</description>
    <generator>Mojolicious</generator>
    <item>
      <pubDate>Mon, 12 Jul 2010 20:42:00</pubDate>
      <title>Works!</title>
      <link>http://blog.example.com/test</link>
      <guid>http://blog.example.com/test</guid>
      <description>
        <![CDATA[<p>trololololo>]]>
      </description>
      <my:extension foo:id="works">
        <![CDATA[
          [awesome]]
        ]]>
      </my:extension>
    </item>
  </channel>
</rss>
END
ok $dom.xml, 'XML mode detected';
is $dom.find('rss')[0].attr('version'), '2.0', 'right version';
is-deeply [$dom.at('title').ancestors».tag], [<channel rss>],
  'right results';
is $dom.at('extension').attr('foo:id'), 'works', 'right id';
like $dom.at('#works').text,       /'[awesome]]'/, 'right text';
like $dom.at('[id="works"]').text, /'[awesome]]'/, 'right text';
is $dom.find('description')[1].text, '<p>trololololo>', 'right text';
is $dom.at('pubDate').text,        'Mon, 12 Jul 2010 20:42:00', 'right text';
like $dom.at('[id*="ork"]').text,  /'[awesome]]'/,           'right text';
like $dom.at('[id*="orks"]').text, /'[awesome]]'/,           'right text';
like $dom.at('[id*="work"]').text, /'[awesome]]'/,           'right text';
like $dom.at('[id*="or"]').text,   /'[awesome]]'/,           'right text';
ok $dom.at('rss').xml,             'XML mode active';
ok $dom.at('extension').parent.xml, 'XML mode active';
ok $dom.at('extension').root.xml,   'XML mode active';
ok $dom.children('rss').first.xml,  'XML mode active';
ok $dom.at('title').ancestors.first.xml, 'XML mode active';

# Namespace
$dom = DOM::Parser.new(qq:to/END/);
<?xml version="1.0"?>
<bk:book xmlns='uri:default-ns'
         xmlns:bk='uri:book-ns'
         xmlns:isbn='uri:isbn-ns'>
  <bk:title>Programming Perl</bk:title>
  <comment>rocks!</comment>
  <nons xmlns=''>
    <section>Nothing</section>
  </nons>
  <meta xmlns='uri:meta-ns'>
    <isbn:number>978-0596000271</isbn:number>
  </meta>
</bk:book>
END
ok $dom.xml, 'XML mode detected';
is $dom.namespace, Nil, 'no namespace';
is $dom.at('book comment').namespace, 'uri:default-ns', 'right namespace';
is $dom.at('book comment').text,      'rocks!',         'right text';
is $dom.at('book nons section').namespace, '',            'no namespace';
is $dom.at('book nons section').text,      'Nothing',     'right text';
is $dom.at('book meta number').namespace,  'uri:isbn-ns', 'right namespace';
is $dom.at('book meta number').text, '978-0596000271', 'right text';
is $dom.children('bk\:book').first<xmlns>, 'uri:default-ns',
  'right attribute';
is $dom.children('book').first<xmlns>, 'uri:default-ns', 'right attribute';
is $dom.children('k\:book').first, Nil, 'no result';
is $dom.children('ook').first,     Nil, 'no result';
is $dom.at('k\:book'), Nil, 'no result';
is $dom.at('ook'),     Nil, 'no result';
is $dom.at('[xmlns\:bk]')<xmlns:bk>, 'uri:book-ns', 'right attribute';
is $dom.at('[bk]')<xmlns:bk>,        'uri:book-ns', 'right attribute';
is $dom.at('[bk]').attr('xmlns:bk'), 'uri:book-ns', 'right attribute';
is $dom.at('[bk]').attr('s:bk'),     Nil,         'no attribute';
is $dom.at('[bk]').attr('bk'),       Nil,         'no attribute';
is $dom.at('[bk]').attr('k'),        Nil,         'no attribute';
is $dom.at('[s\:bk]'), Nil, 'no result';
is $dom.at('[k]'),     Nil, 'no result';
is $dom.at('number').ancestors('meta').first<xmlns>, 'uri:meta-ns',
  'right attribute';
ok $dom.at('nons').matches('book > nons'), 'element did match';
ok !$dom.at('title').matches('book > nons > section'),
  'element did not match';

# Dots
$dom = DOM::Parser.new(q:to/END/);
<?xml version="1.0"?>
<foo xmlns:foo.bar="uri:first">
  <bar xmlns:fooxbar="uri:second">
    <foo.bar:baz>First</fooxbar:baz>
    <fooxbar:ya.da>Second</foo.bar:ya.da>
  </bar>
</foo>
END
is $dom.at('foo bar baz').text,    'First',      'right text';
is $dom.at('baz').namespace,       'uri:first',  'right namespace';
is $dom.at('foo bar ya\.da').text, 'Second',     'right text';
is $dom.at('ya\.da').namespace,    'uri:second', 'right namespace';
is $dom.at('foo').namespace,       Nil,        'no namespace';
is $dom.at('[xml\.s]'), Nil, 'no result';
is $dom.at('b\.z'),     Nil, 'no result';

# Yadis
$dom = DOM::Parser.new(q:to/END/);
<?xml version="1.0" encoding="UTF-8"?>
<XRDS xmlns="xri://$xrds">
  <XRD xmlns="xri://$xrd*($v*2.0)">
    <Service>
      <Type>http://o.r.g/sso/2.0</Type>
    </Service>
    <Service>
      <Type>http://o.r.g/sso/1.0</Type>
    </Service>
  </XRD>
</XRDS>
END
ok $dom.xml, 'XML mode detected';
is $dom.at('XRDS').namespace, 'xri://$xrds',         'right namespace';
is $dom.at('XRD').namespace,  'xri://$xrd*($v*2.0)', 'right namespace';
my $s = $dom.find('XRDS XRD Service');
is $s[0].at('Type').text, 'http://o.r.g/sso/2.0', 'right text';
is $s[0].namespace, 'xri://$xrd*($v*2.0)', 'right namespace';
is $s[1].at('Type').text, 'http://o.r.g/sso/1.0', 'right text';
is $s[1].namespace, 'xri://$xrd*($v*2.0)', 'right namespace';
is $s[2], Nil, 'no result';
is $s.elems, 2, 'right number of elements';

# Yadis (roundtrip with namespace)
my $yadis = q:to/END/;
<?xml version="1.0" encoding="UTF-8"?>
<xrds:XRDS xmlns="xri://$xrd*($v*2.0)" xmlns:xrds="xri://$xrds">
  <XRD>
    <Service>
      <Type>http://o.r.g/sso/3.0</Type>
    </Service>
    <xrds:Service>
      <Type>http://o.r.g/sso/4.0</Type>
    </xrds:Service>
  </XRD>
  <XRD>
    <Service>
      <Type test="23">http://o.r.g/sso/2.0</Type>
    </Service>
    <Service>
      <Type Test="23" test="24">http://o.r.g/sso/1.0</Type>
    </Service>
  </XRD>
</xrds:XRDS>
END
$dom = DOM::Parser.new($yadis);
ok $dom.xml, 'XML mode detected';
is $dom.at('XRDS').namespace, 'xri://$xrds',         'right namespace';
is $dom.at('XRD').namespace,  'xri://$xrd*($v*2.0)', 'right namespace';
$s = $dom.find('XRDS XRD Service');
is $s[0].at('Type').text, 'http://o.r.g/sso/3.0', 'right text';
is $s[0].namespace, 'xri://$xrd*($v*2.0)', 'right namespace';
is $s[1].at('Type').text, 'http://o.r.g/sso/4.0', 'right text';
is $s[1].namespace, 'xri://$xrds', 'right namespace';
is $s[2].at('Type').text, 'http://o.r.g/sso/2.0', 'right text';
is $s[2].namespace, 'xri://$xrd*($v*2.0)', 'right namespace';
is $s[3].at('Type').text, 'http://o.r.g/sso/1.0', 'right text';
is $s[3].namespace, 'xri://$xrd*($v*2.0)', 'right namespace';
is $s[4], Nil, 'no result';
is $s.elems, 4, 'right number of elements';
is $dom.at('[Test="23"]').text, 'http://o.r.g/sso/1.0', 'right text';
is $dom.at('[test="23"]').text, 'http://o.r.g/sso/2.0', 'right text';
is $dom.find('xrds\:Service > Type')[0].text, 'http://o.r.g/sso/4.0',
  'right text';
is $dom.find('xrds\:Service > Type')[1], Nil, 'no result';
is $dom.find('xrds\3AService > Type')[0].text, 'http://o.r.g/sso/4.0',
  'right text';
is $dom.find('xrds\3AService > Type')[1], Nil, 'no result';
is $dom.find('xrds\3A Service > Type')[0].text, 'http://o.r.g/sso/4.0',
  'right text';
is $dom.find('xrds\3A Service > Type')[1], Nil, 'no result';
is $dom.find('xrds\00003AService > Type')[0].text, 'http://o.r.g/sso/4.0',
  'right text';
is $dom.find('xrds\00003AService > Type')[1], Nil, 'no result';
is $dom.find('xrds\00003A Service > Type')[0].text, 'http://o.r.g/sso/4.0',
  'right text';
is $dom.find('xrds\00003A Service > Type')[1], Nil, 'no result';
is "$dom", $yadis, 'successful roundtrip';

# Result and iterator order
$dom = DOM::Parser.new('<a><b>1</b></a><b>2</b><b>3</b>');
my @numbers = $dom.find('b')».text.kv;
is-deeply \@numbers, [1, 1, 2, 2, 3, 3], 'right order';

# Attributes on multiple lines
$dom = DOM::Parser.new("<div test=23 id='a' \n class='x' foo=bar />");
is $dom.at('div.x').attr('test'),        23,  'right attribute';
is $dom.at('[foo="bar"]').attr('class'), 'x', 'right attribute';
is $dom.at('div').attr(baz => Nil).root.to-string,
  '<div baz class="x" foo="bar" id="a" test="23"></div>', 'right result';

# Markup characters in attribute values
$dom = DOM::Parser.new(qq{<div id="<a>" \n test='='>Test<div id='><' /></div>});
is $dom.at('div[id="<a>"]').attr<test>, '=', 'right attribute';
is $dom.at('[id="<a>"]').text, 'Test', 'right text';
is $dom.at('[id="><"]').attr<id>, '><', 'right attribute';

# Empty attributes
$dom = DOM::Parser.new(qq{<div test="" test2='' />});
is $dom.at('div').attr<test>,  '', 'empty attribute value';
is $dom.at('div').attr<test2>, '', 'empty attribute value';
is $dom.at('[test]').tag,  'div', 'right tag';
is $dom.at('[test2]').tag, 'div', 'right tag';
is $dom.at('[test3]'), Nil, 'no result';
is $dom.at('[test=""]').tag,  'div', 'right tag';
is $dom.at('[test2=""]').tag, 'div', 'right tag';
is $dom.at('[test3=""]'), Nil, 'no result';

# Multi-line attribute
$dom = DOM::Parser.new(qq{<div class="line1\nline2" />});
is $dom.at('div').attr<class>, "line1\nline2", 'multi-line attribute value';
is $dom.at('.line1').tag, 'div', 'right tag';
is $dom.at('.line2').tag, 'div', 'right tag';
is $dom.at('.line3'), Nil, 'no result';

# Whitespaces before closing bracket
$dom = DOM::Parser.new('<div >content</div>');
ok $dom.at('div'), 'tag found';
is $dom.at('div').text,    'content', 'right text';
is $dom.at('div').content, 'content', 'right text';

# Class with hyphen
$dom = DOM::Parser.new('<div class="a">A</div><div class="a-1">A1</div>');
@div = $dom.find('.a')».text;
is-deeply @div, ['A'], 'found first element only';
@div = $dom.find('.a-1')».text;
is-deeply @div, ['A1'], 'found last element only';

# Defined but false text
$dom = DOM::Parser.new(
  '<div><div id="a">A</div><div id="b">B</div></div><div id="0">0</div>');
@div = $dom.find('div[id]')».text;
is-deeply @div, [<A B 0>], 'found all div elements with id';

# Empty tags
$dom = DOM::Parser.new('<hr /><br/><br id="br"/><br />');
is "$dom", '<hr><br><br id="br"><br>', 'right result';
is $dom.at('br').content, '', 'empty result';

# Inner XML
$dom = DOM::Parser.new('<a>xxx<x>x</x>xxx</a>');
is $dom.at('a').content, 'xxx<x>x</x>xxx', 'right result';
is $dom.content, '<a>xxx<x>x</x>xxx</a>', 'right result';

# Multiple selectors
$dom = DOM::Parser.new(
  '<div id="a">A</div><div id="b">B</div><div id="c">C</div><p>D</p>');
@div = $dom.find('p, div')».text;
is-deeply @div, [qw(A B C D)], 'found all elements';
@div = $dom.find('#a, #c')».text;
is-deeply @div, [qw(A C)], 'found all div elements with the right ids';
@div = $dom.find('div#a, div#b')».text;
is-deeply @div, [qw(A B)], 'found all div elements with the right ids';
@div = $dom.find('div[id="a"], div[id="c"]')».text;
is-deeply @div, [qw(A C)], 'found all div elements with the right ids';
$dom = DOM::Parser.new(
  '<div id="☃">A</div><div id="b">B</div><div id="♥x">C</div>');
@div = $dom.find('#☃, #♥x')».text;
is-deeply @div, [qw(A C)], 'found all div elements with the right ids';
@div = $dom.find('div#☃, div#b')».text;
is-deeply @div, [qw(A B)], 'found all div elements with the right ids';
@div = $dom.find('div[id="☃"], div[id="♥x"]')».text;
is-deeply @div, [qw(A C)], 'found all div elements with the right ids';

# Multiple attributes
$dom = DOM::Parser.new(qq:to/END/);
<div foo="bar" bar="baz">A</div>
<div foo="bar">B</div>
<div foo="bar" bar="baz">C</div>
<div foo="baz" bar="baz">D</div>
END
is-deeply $dom.find('div[foo="bar"][bar="baz"]')».text, [qw(A C)],
    'found all div elements with the right atributes';
is-deeply $dom.find('div[foo^="b"][foo$="r"]')».text, [qw(A B C)],
    'found all div elements with the right atributes';
is $dom.at('[foo="bar"]').previous, Nil, 'no previous sibling';
is $dom.at('[foo="bar"]').next.text, 'B', 'right text';
is $dom.at('[foo="bar"]').next.previous.text, 'A', 'right text';
is $dom.at('[foo="bar"]').next.next.next.next, Nil, 'no next sibling';

# Pseudo-classes
$dom = DOM::Parser.new(qq:to/END/);
<form action="/foo">
    <input type="text" name="user" value="test" />
    <input type="checkbox" checked="checked" name="groovy">
    <select name="a">
        <option value="b">b</option>
        <optgroup label="c">
            <option value="d">d</option>
            <option selected="selected" value="e">E</option>
            <option value="f">f</option>
        </optgroup>
        <option value="g">g</option>
        <option selected value="h">H</option>
    </select>
    <input type="submit" value="Ok!" />
    <input type="checkbox" checked name="I">
    <p id="content">test 123</p>
    <p id="no_content"><? test ?><!-- 123 -.</p>
</form>
END
is $dom.find(':root')[0].tag,     'form', 'right tag';
is $dom.find('*:root')[0].tag,    'form', 'right tag';
is $dom.find('form:root')[0].tag, 'form', 'right tag';
is $dom.find(':root')[1], Nil, 'no result';
is $dom.find(':checked')[0].attr<name>,        'groovy', 'right name';
is $dom.find('option:checked')[0].attr<value>, 'e',      'right value';
is $dom.find(':checked')[1].text,  'E', 'right text';
is $dom.find('*:checked')[1].text, 'E', 'right text';
is $dom.find(':checked')[2].text,  'H', 'right name';
is $dom.find(':checked')[3].attr<name>, 'I', 'right name';
is $dom.find(':checked')[4], Nil, 'no result';
is $dom.find('option[selected]')[0].attr<value>, 'e', 'right value';
is $dom.find('option[selected]')[1].text, 'H', 'right text';
is $dom.find('option[selected]')[2], Nil, 'no result';
is $dom.find(':checked[value="e"]')[0].text,       'E', 'right text';
is $dom.find('*:checked[value="e"]')[0].text,      'E', 'right text';
is $dom.find('option:checked[value="e"]')[0].text, 'E', 'right text';
is $dom.at('optgroup option:checked[value="e"]').text, 'E', 'right text';
is $dom.at('select option:checked[value="e"]').text,   'E', 'right text';
is $dom.at('select :checked[value="e"]').text,         'E', 'right text';
is $dom.at('optgroup > :checked[value="e"]').text,     'E', 'right text';
is $dom.at('select *:checked[value="e"]').text,        'E', 'right text';
is $dom.at('optgroup > *:checked[value="e"]').text,    'E', 'right text';
is $dom.find(':checked[value="e"]')[1], Nil, 'no result';
is $dom.find(':empty')[0].attr<name>,      'user', 'right name';
is $dom.find('input:empty')[0].attr<name>, 'user', 'right name';
is $dom.at(':empty[type^="ch"]').attr<name>, 'groovy',  'right name';
is $dom.at('p').attr<id>,                    'content', 'right attribute';
is $dom.at('p:empty').attr<id>, 'no_content', 'right attribute';

# More pseudo-classes
$dom = DOM::Parser.new(qq:to/END/);
<ul>
    <li>A</li>
    <li>B</li>
    <li>C</li>
    <li>D</li>
    <li>E</li>
    <li>F</li>
    <li>G</li>
    <li>H</li>
</ul>
END
is-deeply $dom.find('li:nth-child(odd)')».text, [qw(A C E G)],
    'found all odd li elements';
is-deeply $dom.find('li:NTH-CHILD(ODD)')».text, [qw(A C E G)],
    'found all odd li elements';
is-deeply $dom.find('li:nth-last-child(odd)')».text, [qw(B D F H)],
    'found all odd li elements';
is $dom.find(':nth-child(odd)')[0].tag,      'ul', 'right tag';
is $dom.find(':nth-child(odd)')[1].text,     'A',  'right text';
is $dom.find(':nth-child(1)')[0].tag,        'ul', 'right tag';
is $dom.find(':nth-child(1)')[1].text,       'A',  'right text';
is $dom.find(':nth-last-child(odd)')[0].tag, 'ul', 'right tag';
is $dom.find(':nth-last-child(odd)').tail[0].text, 'H', 'right text';
is $dom.find(':nth-last-child(1)')[0].tag,  'ul', 'right tag';
is $dom.find(':nth-last-child(1)')[1].text, 'H',  'right text';
is-deeply $dom.find('li:nth-child(2n+1)')».text, [qw(A C E G)],
    'found all odd li elements';
is-deeply $dom.find('li:nth-child(2n + 1)')».text, [qw(A C E G)],
    'found all odd li elements';
is-deeply $dom.find('li:nth-last-child(2n+1)')».text, [qw(B D F H)],
    'found all odd li elements';
is-deeply $dom.find('li:nth-child(even)')».text, [qw(B D F H)],
    'found all even li elements';
is-deeply $dom.find('li:NTH-CHILD(EVEN)')».text, [qw(B D F H)],
    'found all even li elements';
is-deeply $dom.find('li:nth-last-child( even )')».text, [qw(A C E G)],
    'found all even li elements';
is-deeply $dom.find('li:nth-child(2n+2)')».text, [qw(B D F H)],
    'found all even li elements';
is-deeply $dom.find('li:nTh-chILd(2N+2)')».text, [qw(B D F H)],
    'found all even li elements';
is-deeply $dom.find('li:nth-child( 2n + 2 )')».text, [qw(B D F H)],
    'found all even li elements';
is-deeply $dom.find('li:nth-last-child(2n+2)')».text, [qw(A C E G)],
    'found all even li elements';
is-deeply $dom.find('li:nth-child(4n+1)')».text, [qw(A E)],
    'found the right li elements';
is-deeply $dom.find('li:nth-last-child(4n+1)')».text, [qw(D H)],
    'found the right li elements';
is-deeply $dom.find('li:nth-child(4n+4)')».text, [qw(D H)],
    'found the right li elements';
is-deeply $dom.find('li:nth-last-child(4n+4)')».text, [qw(A E)],
    'found the right li elements';
is-deeply $dom.find('li:nth-child(4n)')».text, [qw(D H)],
    'found the right li elements';
is-deeply $dom.find('li:nth-child( 4n )')».text, [qw(D H)],
    'found the right li elements';
is-deeply $dom.find('li:nth-last-child(4n)')».text, [qw(A E)],
    'found the right li elements';
is-deeply $dom.find('li:nth-child(5n-2)')».text, [qw(C H)],
    'found the right li elements';
is-deeply $dom.find('li:nth-child( 5n - 2 )')».text, [qw(C H)],
    'found the right li elements';
is-deeply $dom.find('li:nth-last-child(5n-2)')».text, [qw(A F)],
    'found the right li elements';
is-deeply $dom.find('li:nth-child(-n+3)')».text, [qw(A B C)],
    'found first three li elements';
is-deeply $dom.find('li:nth-child( -n + 3 )')».text, [qw(A B C)],
    'found first three li elements';
is-deeply $dom.find('li:nth-last-child(-n+3)')».text, [qw(F G H)],
    'found last three li elements';
is-deeply $dom.find('li:nth-child(-1n+3)')».text, [qw(A B C)],
    'found first three li elements';
is-deeply $dom.find('li:nth-last-child(-1n+3)')».text, [qw(F G H)],
    'found first three li elements';
is-deeply $dom.find('li:nth-child(3n)')».text, [qw(C F)],
    'found every third li elements';
is-deeply $dom.find('li:nth-last-child(3n)')».text, [qw(C F)],
    'found every third li elements';
is-deeply $dom.find('li:NTH-LAST-CHILD(3N)')».text, [qw(C F)],
    'found every third li elements';
is-deeply $dom.find('li:Nth-Last-Child(3N)')».text, [qw(C F)],
    'found every third li elements';
is-deeply $dom.find('li:nth-child( 3 )')».text, ['C'],
    'found third li element';
is-deeply $dom.find('li:nth-last-child( +3 )')».text, ['F'],
    'found third last li element';
is-deeply $dom.find('li:nth-child(1n+0)')».text, [qw(A B C D E F G)],
    'found all li elements';
is-deeply $dom.find('li:nth-child(1n-0)')».text, [qw(A B C D E F G)],
    'found all li elements';
is-deeply $dom.find('li:nth-child(n+0)')».text, [qw(A B C D E F G)],
    'found all li elements';
is-deeply $dom.find('li:nth-child(n)')».text, [qw(A B C D E F G)],
    'found all li elements';
is-deeply $dom.find('li:nth-child(n+0)')».text, [qw(A B C D E F G)],
    'found all li elements';
is-deeply $dom.find('li:NTH-CHILD(N+0)')».text, [qw(A B C D E F G)],
    'found all li elements';
is-deeply $dom.find('li:Nth-Child(N+0)')».text, [qw(A B C D E F G)],
    'found all li elements';
is-deeply $dom.find('li:nth-child(n)')».text, [qw(A B C D E F G)],
    'found all li elements';
is-deeply $dom.find('li:nth-child(0n+1)')».text, [qw(A)],
    'found first li element';
is $dom.find('li:nth-child(0n+0)').elems,     0, 'no results';
is $dom.find('li:nth-child(0)').elems,        0, 'no results';
is $dom.find('li:nth-child()').elems,         0, 'no results';
is $dom.find('li:nth-child(whatever)').elems, 0, 'no results';
is $dom.find('li:whatever(whatever)').elems,  0, 'no results';

# Even more pseudo-classes
$dom = DOM::Parser.new(qq:to/END/);
<ul>
    <li>A</li>
    <p>B</p>
    <li class="test ♥">C</li>
    <p>D</p>
    <li>E</li>
    <li>F</li>
    <p>G</p>
    <li>H</li>
    <li>I</li>
</ul>
<div>
    <div class="☃">J</div>
</div>
<div>
    <a href="http://mojolicio.us">Mojo!</a>
    <div class="☃">K</div>
    <a href="http://mojolicio.us">Mojolicious!</a>
</div>
END
is-deeply $dom.find('ul :nth-child(odd)')».text, [qw(A C E G I)],
    'found all odd elements';
is-deeply $dom.find('li:nth-of-type(odd)')».text, [qw(A E H)],
    'found all odd li elements';
is-deeply $dom.find('li:nth-last-of-type( odd )')».text, [qw(C F I)],
    'found all odd li elements';
is-deeply $dom.find('p:nth-of-type(odd)')».text, [qw(B G)],
    'found all odd p elements';
is-deeply $dom.find('p:nth-last-of-type(odd)')».text, [qw(B G)],
    'found all odd li elements';
is-deeply $dom.find('ul :nth-child(1)')».text, ['A'], 'found first child';
is-deeply $dom.find('ul :first-child')».text, ['A'], 'found first child';
is-deeply $dom.find('p:nth-of-type(1)')».text, ['B'], 'found first child';
is-deeply $dom.find('p:first-of-type')».text, ['B'], 'found first child';
is-deeply $dom.find('li:nth-of-type(1)')».text, ['A'], 'found first child';
is-deeply $dom.find('li:first-of-type')».text, ['A'], 'found first child';
is-deeply $dom.find('ul :nth-last-child(-n+1)')».text, ['I'],
    'found last child';
is-deeply $dom.find('ul :last-child')».text, ['I'], 'found last child';
is-deeply $dom.find('p:nth-last-of-type(-n+1)')».text, ['G'],
    'found last child';
is-deeply $dom.find('p:last-of-type')».text, ['G'], 'found last child';
is-deeply $dom.find('li:nth-last-of-type(-n+1)')».text, ['I'],
    'found last child';
is-deeply $dom.find('li:last-of-type')».text, ['I'], 'found last child';
is-deeply $dom.find('ul :nth-child(-n+3):not(li)')».text, ['B'],
    'found first p element';
is-deeply $dom.find('ul :nth-child(-n+3):NOT(li)')».text, ['B'],
    'found first p element';
is-deeply $dom.find('ul :nth-child(-n+3):not(:first-child)')».text, [qw(B C)],
    'found second and third element';
is-deeply $dom.find('ul :nth-child(-n+3):not(.♥)')».text, [qw(A B)],
    'found first and second element';
is-deeply $dom.find('ul :nth-child(-n+3):not([class$="♥"])')».text, [qw(A B)],
    'found first and second element';
is-deeply $dom.find('ul :nth-child(-n+3):not(li[class$="♥"])')».text, [qw(A B)],
    'found first and second element';
is-deeply $dom.find(
    'ul :nth-child(-n+3):not([class$="♥"][class^="test"])')».text, [qw(A B)],
    'found first and second element';
is-deeply $dom.find('ul :nth-child(-n+3):not(*[class$="♥"])')».text, [qw(A B)],
    'found first and second element';
is-deeply $dom.find('ul :nth-child(-n+3):not(:nth-child(-n+2))')».text, ['C'],
    'found third element';
is-deeply $dom.find(
    'ul :nth-child(-n+3):not(:nth-child(1)):not(:nth-child(2))')».text, ['C'],
    'found third element';
is-deeply $dom.find(':only-child')».text, ['J'], 'found only child';
is-deeply $dom.find('div :only-of-type')».text, [qw(J K)], 'found only child';
is-deeply $dom.find('div:only-child')».text, ['J'], 'found only child';
is-deeply $dom.find('div div:only-of-type')».text, [qw(J K)],
    'found only child';

# Sibling combinator
$dom = DOM::Parser.new(qq:to/END/);
<ul>
    <li>A</li>
    <p>B</p>
    <li>C</li>
</ul>
<h1>D</h1>
<p id="♥">E</p>
<p id="☃">F<b>H</b></p>
<div>G</div>
END
is $dom.at('li ~ p').text,       'B', 'right text';
is $dom.at('li + p').text,       'B', 'right text';
is $dom.at('h1 ~ p ~ p').text,   'F', 'right text';
is $dom.at('h1 + p ~ p').text,   'F', 'right text';
is $dom.at('h1 ~ p + p').text,   'F', 'right text';
is $dom.at('h1 + p + p').text,   'F', 'right text';
is $dom.at('h1  +  p+p').text,   'F', 'right text';
is $dom.at('ul > li ~ li').text, 'C', 'right text';
is $dom.at('ul li ~ li').text,   'C', 'right text';
is $dom.at('ul>li~li').text,     'C', 'right text';
is $dom.at('ul li li'),     Nil, 'no result';
is $dom.at('ul ~ li ~ li'), Nil, 'no result';
is $dom.at('ul + li ~ li'), Nil, 'no result';
is $dom.at('ul > li + li'), Nil, 'no result';
is $dom.at('h1 ~ div').text, 'G', 'right text';
is $dom.at('h1 + div'), Nil, 'no result';
is $dom.at('p + div').text,               'G', 'right text';
is $dom.at('ul + h1 + p + p + div').text, 'G', 'right text';
is $dom.at('ul + h1 ~ p + div').text,     'G', 'right text';
is $dom.at('h1 ~ #♥').text,             'E', 'right text';
is $dom.at('h1 + #♥').text,             'E', 'right text';
is $dom.at('#♥~#☃').text,             'F', 'right text';
is $dom.at('#♥+#☃').text,             'F', 'right text';
is $dom.at('#♥+#☃>b').text,           'H', 'right text';
is $dom.at('#♥ > #☃'), Nil, 'no result';
is $dom.at('#♥ #☃'),   Nil, 'no result';
is $dom.at('#♥ + #☃ + :nth-last-child(1)').text,  'G', 'right text';
is $dom.at('#♥ ~ #☃ + :nth-last-child(1)').text,  'G', 'right text';
is $dom.at('#♥ + #☃ ~ :nth-last-child(1)').text,  'G', 'right text';
is $dom.at('#♥ ~ #☃ ~ :nth-last-child(1)').text,  'G', 'right text';
is $dom.at('#♥ + :nth-last-child(2)').text,         'F', 'right text';
is $dom.at('#♥ ~ :nth-last-child(2)').text,         'F', 'right text';
is $dom.at('#♥ + #☃ + *:nth-last-child(1)').text, 'G', 'right text';
is $dom.at('#♥ ~ #☃ + *:nth-last-child(1)').text, 'G', 'right text';
is $dom.at('#♥ + #☃ ~ *:nth-last-child(1)').text, 'G', 'right text';
is $dom.at('#♥ ~ #☃ ~ *:nth-last-child(1)').text, 'G', 'right text';
is $dom.at('#♥ + *:nth-last-child(2)').text,        'F', 'right text';
is $dom.at('#♥ ~ *:nth-last-child(2)').text,        'F', 'right text';

# Adding nodes
$dom = DOM::Parser.new(qq:to/END/);
<ul>
    <li>A</li>
    <p>B</p>
    <li>C</li>
</ul>
<div>D</div>
END
$dom.at('li').append('<p>A1</p>23');
is "$dom", qq:to/END/, 'right result';
<ul>
    <li>A</li><p>A1</p>23
    <p>B</p>
    <li>C</li>
</ul>
<div>D</div>
END
$dom.at('li').prepend('24').prepend('<div>A-1</div>25');
is "$dom", qq:to/END/, 'right result';
<ul>
    24<div>A-1</div>25<li>A</li><p>A1</p>23
    <p>B</p>
    <li>C</li>
</ul>
<div>D</div>
END
is $dom.at('div').text, 'A-1', 'right text';
is $dom.at('iv'), Nil, 'no result';
is $dom.prepend('l').prepend('alal').prepend('a').type, 'root', 'right type';
is "$dom", qq:to/END/, 'no changes';
<ul>
    24<div>A-1</div>25<li>A</li><p>A1</p>23
    <p>B</p>
    <li>C</li>
</ul>
<div>D</div>
END
is $dom.append('lalala').type, 'root', 'right type';
is "$dom", qq:to/END/, 'no changes';
<ul>
    24<div>A-1</div>25<li>A</li><p>A1</p>23
    <p>B</p>
    <li>C</li>
</ul>
<div>D</div>
END
$dom.find('div')».append('works');
is "$dom", qq:to/END/, 'right result';
<ul>
    24<div>A-1</div>works25<li>A</li><p>A1</p>23
    <p>B</p>
    <li>C</li>
</ul>
<div>D</div>works
END
$dom.at('li').prepend-content('A3<p>A2</p>').prepend-content('A4');
is $dom.at('li').text, 'A4A3 A', 'right text';
is "$dom", qq:to/END/, 'right result';
<ul>
    24<div>A-1</div>works25<li>A4A3<p>A2</p>A</li><p>A1</p>23
    <p>B</p>
    <li>C</li>
</ul>
<div>D</div>works
END
$dom.find('li')[1].append-content('<p>C2</p>C3').append-content(' C4')
  .append-content('C5');
is $dom.find('li')[1].text, 'C C3 C4C5', 'right text';
is "$dom", qq:to/END/, 'right result';
<ul>
    24<div>A-1</div>works25<li>A4A3<p>A2</p>A</li><p>A1</p>23
    <p>B</p>
    <li>C<p>C2</p>C3 C4C5</li>
</ul>
<div>D</div>works
END

# Optional "head" and "body" tags
$dom = DOM::Parser.new(qq:to/END/);
<html>
  <head>
    <title>foo</title>
  <body>bar
END
is $dom.at('html > head > title').text, 'foo', 'right text';
is $dom.at('html > body').text,         'bar', 'right text';

# Optional "li" tag
$dom = DOM::Parser.new(qq:to/END/);
<ul>
  <li>
    <ol>
      <li>F
      <li>G
    </ol>
  <li>A</li>
  <LI>B
  <li>C</li>
  <li>D
  <li>E
</ul>
END
is $dom.find('ul > li > ol > li')[0].text, 'F', 'right text';
is $dom.find('ul > li > ol > li')[1].text, 'G', 'right text';
is $dom.find('ul > li')[1].text,           'A', 'right text';
is $dom.find('ul > li')[2].text,           'B', 'right text';
is $dom.find('ul > li')[3].text,           'C', 'right text';
is $dom.find('ul > li')[4].text,           'D', 'right text';
is $dom.find('ul > li')[5].text,           'E', 'right text';

# Optional "p" tag
$dom = DOM::Parser.new(qq:to/END/);
<div>
  <p>A</p>
  <P>B
  <p>C</p>
  <p>D<div>X</div>
  <p>E<img src="foo.png">
  <p>F<br>G
  <p>H
</div>
END
is $dom.find('div > p')[0].text, 'A',   'right text';
is $dom.find('div > p')[1].text, 'B',   'right text';
is $dom.find('div > p')[2].text, 'C',   'right text';
is $dom.find('div > p')[3].text, 'D',   'right text';
is $dom.find('div > p')[4].text, 'E',   'right text';
is $dom.find('div > p')[5].text, 'F G', 'right text';
is $dom.find('div > p')[6].text, 'H',   'right text';
is $dom.find('div > p > p')[0], Nil, 'no results';
is $dom.at('div > p > img').attr<src>, 'foo.png', 'right attribute';
is $dom.at('div > div').text, 'X', 'right text';

# Optional "dt" and "dd" tags
$dom = DOM::Parser.new(qq:to/END/);
<dl>
  <dt>A</dt>
  <DD>B
  <dt>C</dt>
  <dd>D
  <dt>E
  <dd>F
</dl>
END
is $dom.find('dl > dt')[0].text, 'A', 'right text';
is $dom.find('dl > dd')[0].text, 'B', 'right text';
is $dom.find('dl > dt')[1].text, 'C', 'right text';
is $dom.find('dl > dd')[1].text, 'D', 'right text';
is $dom.find('dl > dt')[2].text, 'E', 'right text';
is $dom.find('dl > dd')[2].text, 'F', 'right text';

# Optional "rp" and "rt" tags
$dom = DOM::Parser.new(qq:to/END/);
<ruby>
  <rp>A</rp>
  <RT>B
  <rp>C</rp>
  <rt>D
  <rp>E
  <rt>F
</ruby>
END
is $dom.find('ruby > rp')[0].text, 'A', 'right text';
is $dom.find('ruby > rt')[0].text, 'B', 'right text';
is $dom.find('ruby > rp')[1].text, 'C', 'right text';
is $dom.find('ruby > rt')[1].text, 'D', 'right text';
is $dom.find('ruby > rp')[2].text, 'E', 'right text';
is $dom.find('ruby > rt')[2].text, 'F', 'right text';

# Optional "optgroup" and "option" tags
$dom = DOM::Parser.new(qq:to/END/);
<div>
  <optgroup>A
    <option id="foo">B
    <option>C</option>
    <option>D
  <OPTGROUP>E
    <option>F
  <optgroup>G
    <option>H
</div>
END
is $dom.find('div > optgroup')[0].text,          'A', 'right text';
is $dom.find('div > optgroup > #foo')[0].text,   'B', 'right text';
is $dom.find('div > optgroup > option')[1].text, 'C', 'right text';
is $dom.find('div > optgroup > option')[2].text, 'D', 'right text';
is $dom.find('div > optgroup')[1].text,          'E', 'right text';
is $dom.find('div > optgroup > option')[3].text, 'F', 'right text';
is $dom.find('div > optgroup')[2].text,          'G', 'right text';
is $dom.find('div > optgroup > option')[4].text, 'H', 'right text';

# Optional "colgroup" tag
$dom = DOM::Parser.new(qq:to/END/);
<table>
  <col id=morefail>
  <col id=fail>
  <colgroup>
    <col id=foo>
    <col class=foo>
  <colgroup>
    <col id=bar>
</table>
END
is $dom.find('table > col')[0].attr<id>, 'morefail', 'right attribute';
is $dom.find('table > col')[1].attr<id>, 'fail',     'right attribute';
is $dom.find('table > colgroup > col')[0].attr<id>, 'foo',
  'right attribute';
is $dom.find('table > colgroup > col')[1].attr<class>, 'foo',
  'right attribute';
is $dom.find('table > colgroup > col')[2].attr<id>, 'bar',
  'right attribute';

# Optional "thead", "tbody", "tfoot", "tr", "th" and "td" tags
$dom = DOM::Parser.new(qq:to/END/);
<table>
  <thead>
    <tr>
      <th>A</th>
      <th>D
  <tfoot>
    <tr>
      <td>C
  <tbody>
    <tr>
      <td>B
</table>
END
is $dom.at('table > thead > tr > th').text, 'A', 'right text';
is $dom.find('table > thead > tr > th')[1].text, 'D', 'right text';
is $dom.at('table > tbody > tr > td').text, 'B', 'right text';
is $dom.at('table > tfoot > tr > td').text, 'C', 'right text';

# Optional "colgroup", "thead", "tbody", "tr", "th" and "td" tags
$dom = DOM::Parser.new(qq:to/END/);
<table>
  <col id=morefail>
  <col id=fail>
  <colgroup>
    <col id=foo />
    <col class=foo>
  <colgroup>
    <col id=bar>
  </colgroup>
  <thead>
    <tr>
      <th>A</th>
      <th>D
  <tbody>
    <tr>
      <td>B
  <tbody>
    <tr>
      <td>E
</table>
END
is $dom.find('table > col')[0].attr<id>, 'morefail', 'right attribute';
is $dom.find('table > col')[1].attr<id>, 'fail',     'right attribute';
is $dom.find('table > colgroup > col')[0].attr<id>, 'foo',
  'right attribute';
is $dom.find('table > colgroup > col')[1].attr<class>, 'foo',
  'right attribute';
is $dom.find('table > colgroup > col')[2].attr<id>, 'bar',
  'right attribute';
is $dom.at('table > thead > tr > th').text, 'A', 'right text';
is $dom.find('table > thead > tr > th')[1].text, 'D', 'right text';
is $dom.at('table > tbody > tr > td').text, 'B', 'right text';
is $dom.find('table > tbody > tr > td')».text.join("\n"), "B\nE",
  'right text';

# Optional "colgroup", "tbody", "tr", "th" and "td" tags
$dom = DOM::Parser.new(qq:to/END/);
<table>
  <colgroup>
    <col id=foo />
    <col class=foo>
  <colgroup>
    <col id=bar>
  </colgroup>
  <tbody>
    <tr>
      <td>B
</table>
END
is $dom.find('table > colgroup > col')[2].attr<id>, 'bar',
is $dom.find('table > colgroup > col')[0].attr<id>, 'foo',
  'right attribute';
is $dom.find('table > colgroup > col')[1].attr<class>, 'foo',
  'right attribute';
is $dom.find('table > colgroup > col')[2].attr<id>, 'bar',
  'right attribute';
is $dom.at('table > tbody > tr > td').text, 'B', 'right text';

# Optional "tr" and "td" tags
$dom = DOM::Parser.new(qq:to/END/);
<table>
    <tr>
      <td>A
      <td>B</td>
    <tr>
      <td>C
    </tr>
    <tr>
      <td>D
</table>
END
is $dom.find('table > tr > td')[0].text, 'A', 'right text';
is $dom.find('table > tr > td')[1].text, 'B', 'right text';
is $dom.find('table > tr > td')[2].text, 'C', 'right text';
is $dom.find('table > tr > td')[3].text, 'D', 'right text';

# Real world table
$dom = DOM::Parser.new(qq:to/END/);
<html>
  <head>
    <title>Real World!</title>
  <body>
    <p>Just a test
    <table class=RealWorld>
      <thead>
        <tr>
          <th class=one>One
          <th class=two>Two
          <th class=three>Three
          <th class=four>Four
      <tbody>
        <tr>
          <td class=alpha>Alpha
          <td class=beta>Beta
          <td class=gamma><a href="#gamma">Gamma</a>
          <td class=delta>Delta
        <tr>
          <td class=alpha>Alpha Two
          <td class=beta>Beta Two
          <td class=gamma><a href="#gamma-two">Gamma Two</a>
          <td class=delta>Delta Two
    </table>
END
is $dom.find('html > head > title')[0].text, 'Real World!', 'right text';
is $dom.find('html > body > p')[0].text,     'Just a test', 'right text';
is $dom.find('p')[0].text,                   'Just a test', 'right text';
is $dom.find('thead > tr > .three')[0].text, 'Three',       'right text';
is $dom.find('thead > tr > .four')[0].text,  'Four',        'right text';
is $dom.find('tbody > tr > .beta')[0].text,  'Beta',        'right text';
is $dom.find('tbody > tr > .gamma')[0].text, '',            'no text';
is $dom.find('tbody > tr > .gamma > a')[0].text, 'Gamma',     'right text';
is $dom.find('tbody > tr > .alpha')[1].text,     'Alpha Two', 'right text';
is $dom.find('tbody > tr > .gamma > a')[1].text, 'Gamma Two', 'right text';
is-deeply $dom.find('tr > td:nth-child(1)')».following(':nth-child(even)')
    .flat».all-text, ['Beta', 'Delta', 'Beta Two', 'Delta Two'],
    'right results';

# Real world list
$dom = DOM::Parser.new(qq:to/END/);
<html>
  <head>
    <title>Real World!</title>
  <body>
    <ul>
      <li>
        Test
        <br>
        123
        <p>

      <li>
        Test
        <br>
        321
        <p>
      <li>
        Test
        3
        2
        1
        <p>
    </ul>
END
is $dom.find('html > head > title')[0].text,    'Real World!', 'right text';
is $dom.find('body > ul > li')[0].text,         'Test 123',    'right text';
is $dom.find('body > ul > li > p')[0].text,     '',            'no text';
is $dom.find('body > ul > li')[1].text,         'Test 321',    'right text';
is $dom.find('body > ul > li > p')[1].text,     '',            'no text';
is $dom.find('body > ul > li')[1].all-text,     'Test 321',    'right text';
is $dom.find('body > ul > li > p')[1].all-text, '',            'no text';
is $dom.find('body > ul > li')[2].text,         'Test 3 2 1',  'right text';
is $dom.find('body > ul > li > p')[2].text,     '',            'no text';
is $dom.find('body > ul > li')[2].all-text,     'Test 3 2 1',  'right text';
is $dom.find('body > ul > li > p')[2].all-text, '',            'no text';

# Advanced whitespace trimming (punctuation)
$dom = DOM::Parser.new(qq:to/END/);
<html>
  <head>
    <title>Real World!</title>
  <body>
    <div>foo <strong>bar</strong>.</div>
    <div>foo<strong>, bar</strong>baz<strong>; yada</strong>.</div>
    <div>foo<strong>: bar</strong>baz<strong>? yada</strong>!</div>
END
is $dom.find('html > head > title')[0].text, 'Real World!', 'right text';
is $dom.find('body > div')[0].all-text,      'foo bar.',    'right text';
is $dom.find('body > div')[1].all-text, 'foo, bar baz; yada.', 'right text';
is $dom.find('body > div')[1].text,     'foo baz.',            'right text';
is $dom.find('body > div')[2].all-text, 'foo: bar baz? yada!', 'right text';
is $dom.find('body > div')[2].text,     'foo baz!',            'right text';

# Real world JavaScript and CSS
$dom = DOM::Parser.new(qq:to/END/);
<html>
  <head>
    <style test=works>#style { foo: style('<test>'); }</style>
    <script>
      if (a < b) {
        alert('<123>');
      }
    </script>
    < sCriPt two="23" >if (b > c) { alert('&<ohoh>') }< / scRiPt >
  <body>Foo!</body>
END
is $dom.find('html > body')[0].text, 'Foo!', 'right text';
is $dom.find('html > head > style')[0].text,
  "#style { foo: style('<test>'); }", 'right text';
is $dom.find('html > head > script')[0].text,
 "\n      if (a < b) \{\n        alert('<123>');\n      \}\n    ", 'right text';
is $dom.find('html > head > script')[1].text,
  "if (b > c) \{ alert('&<ohoh>') \}", 'right text';

# More real world JavaScript
$dom = DOM::Parser.new(qq:to/END/);
<!DOCTYPE html>
<html>
  <head>
    <title>Foo</title>
    <script src="/js/one.js"></script>
    <script src="/js/two.js"></script>
    <script src="/js/three.js"></script>
  </head>
  <body>Bar</body>
</html>
END
is $dom.at('title').text, 'Foo', 'right text';
is $dom.find('html > head > script')[0].attr('src'), '/js/one.js',
  'right attribute';
is $dom.find('html > head > script')[1].attr('src'), '/js/two.js',
  'right attribute';
is $dom.find('html > head > script')[2].attr('src'), '/js/three.js',
  'right attribute';
is $dom.find('html > head > script')[2].text, '', 'no text';
is $dom.at('html > body').text, 'Bar', 'right text';

# Even more real world JavaScript
$dom = DOM::Parser.new(qq:to/END/);
<!DOCTYPE html>
<html>
  <head>
    <title>Foo</title>
    <script src="/js/one.js"></script>
    <script src="/js/two.js"></script>
    <script src="/js/three.js">
  </head>
  <body>Bar</body>
</html>
END
is $dom.at('title').text, 'Foo', 'right text';
is $dom.find('html > head > script')[0].attr('src'), '/js/one.js',
  'right attribute';
is $dom.find('html > head > script')[1].attr('src'), '/js/two.js',
  'right attribute';
is $dom.find('html > head > script')[2].attr('src'), '/js/three.js',
  'right attribute';
is $dom.find('html > head > script')[2].text, '', 'no text';
is $dom.at('html > body').text, 'Bar', 'right text';

# Inline DTD
$dom = DOM::Parser.new(qq:to/END/);
<?xml version="1.0"?>
<!-- This is a Test! -.
<!DOCTYPE root [
  <!ELEMENT root (#PCDATA)>
  <!ATTLIST root att CDATA #REQUIRED>
]>
<root att="test">
  <![CDATA[<hello>world</hello>]]>
</root>
END
ok $dom.xml, 'XML mode detected';
is $dom.at('root').attr('att'), 'test', 'right attribute';
is $dom.tree[5][1], ' root [
  <!ELEMENT root (#PCDATA)>
  <!ATTLIST root att CDATA #REQUIRED>
]', 'right doctype';
is $dom.at('root').text, '<hello>world</hello>', 'right text';
$dom = DOM::Parser.new(qq:to/END/);
<!doctype book
SYSTEM "usr.dtd"
[
  <!ENTITY test "yeah">
]>
<foo />
END
is $dom.tree[1][1], ' book
SYSTEM "usr.dtd"
[
  <!ENTITY test "yeah">
]', 'right doctype';
ok !$dom.xml, 'XML mode not detected';
is $dom.at('foo'), '<foo></foo>', 'right element';
$dom = DOM::Parser.new(qq:to/END/);
<?xml version="1.0" encoding = 'utf-8'?>
<!DOCTYPE foo [
  <!ELEMENT foo ANY>
  <!ATTLIST foo xml:lang CDATA #IMPLIED>
  <!ENTITY % e SYSTEM "myentities.ent">
  %myentities;
]  >
<foo xml:lang="de">Check!</fOo>
END
ok $dom.xml, 'XML mode detected';
is $dom.tree[3][1], ' foo [
  <!ELEMENT foo ANY>
  <!ATTLIST foo xml:lang CDATA #IMPLIED>
  <!ENTITY % e SYSTEM "myentities.ent">
  %myentities;
]  ', 'right doctype';
is $dom.at('foo').attr<xml:lang>, 'de', 'right attribute';
is $dom.at('foo').text, 'Check!', 'right text';
$dom = DOM::Parser.new(qq:to/END/);
<!DOCTYPE TESTSUITE PUBLIC "my.dtd" 'mhhh' [
  <!ELEMENT foo ANY>
  <!ATTLIST foo bar ENTITY 'true'>
  <!ENTITY system_entities SYSTEM 'systems.xml'>
  <!ENTITY leertaste '&#32;'>
  <!-- This is a comment -.
  <!NOTATION hmmm SYSTEM "hmmm">
]   >
<?check for-nothing?>
<foo bar='false'>&leertaste;!!!</foo>
END
is $dom.tree[1][1], ' TESTSUITE PUBLIC "my.dtd" \'mhhh\' [
  <!ELEMENT foo ANY>
  <!ATTLIST foo bar ENTITY \'true\'>
  <!ENTITY system_entities SYSTEM \'systems.xml\'>
  <!ENTITY leertaste \'&#32;\'>
  <!-- This is a comment -.
  <!NOTATION hmmm SYSTEM "hmmm">
]   ', 'right doctype';
is $dom.at('foo').attr('bar'), 'false', 'right attribute';

# Broken "font" block and useless end tags
$dom = DOM::Parser.new(qq:to/END/);
<html>
  <head><title>Test</title></head>
  <body>
    <table>
      <tr><td><font>test</td></font></tr>
      </tr>
    </table>
  </body>
</html>
END
is $dom.at('html > head > title').text,          'Test', 'right text';
is $dom.at('html body table tr td > font').text, 'test', 'right text';

# Different broken "font" block
$dom = DOM::Parser.new(qq:to/END/);
<html>
  <head><title>Test</title></head>
  <body>
    <font>
    <table>
      <tr>
        <td>test1<br></td></font>
        <td>test2<br>
    </table>
  </body>
</html>
END
is $dom.at('html > head > title').text, 'Test', 'right text';
is $dom.find('html > body > font > table > tr > td')[0].text, 'test1',
  'right text';
is $dom.find('html > body > font > table > tr > td')[1].text, 'test2',
  'right text';

# Broken "font" and "div" blocks
$dom = DOM::Parser.new(qq:to/END/);
<html>
  <head><title>Test</title></head>
  <body>
    <font>
    <div>test1<br>
      <div>test2<br></font>
    </div>
  </body>
</html>
END
is $dom.at('html head title').text,            'Test',  'right text';
is $dom.at('html body font > div').text,       'test1', 'right text';
is $dom.at('html body font > div > div').text, 'test2', 'right text';

# Broken "div" blocks
$dom = DOM::Parser.new(qq:to/END/);
<html>
  <head><title>Test</title></head>
  <body>
    <div>
    <table>
      <tr><td><div>test</td></div></tr>
      </div>
    </table>
  </body>
</html>
END
is $dom.at('html head title').text,                 'Test', 'right text';
is $dom.at('html body div table tr td > div').text, 'test', 'right text';

# And another broken "font" block
$dom = DOM::Parser.new(qq:to/END/);
<html>
  <head><title>Test</title></head>
  <body>
    <table>
      <tr>
        <td><font><br>te<br>st<br>1</td></font>
        <td>x1<td><img>tes<br>t2</td>
        <td>x2<td><font>t<br>est3</font></td>
      </tr>
    </table>
  </body>
</html>
END
is $dom.at('html > head > title').text, 'Test', 'right text';
is $dom.find('html body table tr > td > font')[0].text, 'te st 1',
  'right text';
is $dom.find('html body table tr > td')[1].text, 'x1',     'right text';
is $dom.find('html body table tr > td')[2].text, 'tes t2', 'right text';
is $dom.find('html body table tr > td')[3].text, 'x2',     'right text';
is $dom.find('html body table tr > td')[5], Nil, 'no result';
is $dom.find('html body table tr > td').elems, 5, 'right number of elements';
is $dom.find('html body table tr > td > font')[1].text, 't est3',
  'right text';
is $dom.find('html body table tr > td > font')[2], Nil, 'no result';
is $dom.find('html body table tr > td > font').elems, 2,
  'right number of elements';
is $dom, qq:to/END/, 'right result';
<html>
  <head><title>Test</title></head>
  <body>
    <table>
      <tr>
        <td><font><br>te<br>st<br>1</font></td>
        <td>x1</td><td><img>tes<br>t2</td>
        <td>x2</td><td><font>t<br>est3</font></td>
      </tr>
    </table>
  </body>
</html>
END

# A collection of wonderful screwups
$dom = DOM::Parser.new(q:to/END/);
<!DOCTYPE html>
<html lang="en">
  <head><title>Wonderful Screwups</title></head>
  <body id="screw-up">
    <div>
      <div class="ewww">
        <a href="/test" target='_blank'><img src="/test.png"></a>
        <a href='/real bad' screwup: http://localhost/bad' target='_blank'>
          <img src="/test2.png">
      </div>
      </mt:If>
    </div>
    <b>>la<>la<<>>la<</b>
  </body>
</html>
END
is $dom.at('#screw-up > b').text, '>la<>la<<>>la<', 'right text';
is $dom.at('#screw-up .ewww > a > img').attr('src'), '/test.png',
  'right attribute';
is $dom.find('#screw-up .ewww > a > img')[1].attr('src'), '/test2.png',
  'right attribute';
is $dom.find('#screw-up .ewww > a > img')[2], Nil, 'no result';
is $dom.find('#screw-up .ewww > a > img').elems, 2, 'right number of elements';

# Broken "br" tag
$dom = DOM::Parser.new('<br< abc abc abc abc abc abc abc abc<p>Test</p>');
is $dom.at('p').text, 'Test', 'right text';

# Modifying an XML document
$dom = DOM::Parser.new(q:to/END/);
<?xml version='1.0' encoding='UTF-8'?>
<XMLTest />
END
ok $dom.xml, 'XML mode detected';
$dom.at('XMLTest').content('<Element />');
my $element = $dom.at('Element');
is $element.tag, 'Element', 'right tag';
ok $element.xml, 'XML mode active';
$element = $dom.at('XMLTest').children[0];
is $element.tag, 'Element', 'right child';
is $element.parent.tag, 'XMLTest', 'right parent';
ok $element.root.xml, 'XML mode active';
$dom.replace('<XMLTest2 /><XMLTest3 just="works" />');
ok $dom.xml, 'XML mode active';
$dom.at('XMLTest2')<foo> = Nil;
is $dom, '<XMLTest2 foo="foo" /><XMLTest3 just="works" />', 'right result';

# Ensure HTML semantics
ok !DOM::Parser.new.xml(Nil).parse('<?xml version="1.0"?>').xml,
  'XML mode not detected';
$dom
  = DOM::Parser.new.xml(0).parse('<?xml version="1.0"?><br><div>Test</div>');
is $dom.at('div:root').text, 'Test', 'right text';

# Ensure XML semantics
ok !!DOM::Parser.new.xml(1).parse('<foo />').xml, 'XML mode active';
$dom = DOM::Parser.new(q:to/END/);
<?xml version='1.0' encoding='UTF-8'?>
<script>
  <table>
    <td>
      <tr><thead>foo<thead></tr>
    </td>
    <td>
      <tr><thead>bar<thead></tr>
    </td>
  </table>
</script>
END
is $dom.find('table > td > tr > thead')[0].text, 'foo', 'right text';
is $dom.find('script > table > td > tr > thead')[1].text, 'bar',
  'right text';
is $dom.find('table > td > tr > thead')[2], Nil, 'no result';
is $dom.find('table > td > tr > thead').elems, 2, 'right number of elements';

# Ensure XML semantics again
$dom = DOM::Parser.new.xml(1).parse(q:to/END/);
<table>
  <td>
    <tr><thead>foo<thead></tr>
  </td>
  <td>
    <tr><thead>bar<thead></tr>
  </td>
</table>
END
is $dom.find('table > td > tr > thead')[0].text, 'foo', 'right text';
is $dom.find('table > td > tr > thead')[1].text, 'bar', 'right text';
is $dom.find('table > td > tr > thead')[2], Nil, 'no result';
is $dom.find('table > td > tr > thead').elems, 2, 'right number of elements';

# Nested tables
$dom = DOM::Parser.new(q:to/END/);
<table id="foo">
  <tr>
    <td>
      <table id="bar">
        <tr>
          <td>baz</td>
        </tr>
      </table>
    </td>
  </tr>
</table>
END
is $dom.find('#foo > tr > td > #bar > tr >td')[0].text, 'baz', 'right text';
is $dom.find('table > tr > td > table > tr >td')[0].text, 'baz',
  'right text';

# Nested find
$dom.parse(qq:to/END/);
<c>
  <a>foo</a>
  <b>
    <a>bar</a>
    <c>
      <a>baz</a>
      <d>
        <a>yada</a>
      </d>
    </c>
  </b>
</c>
END
my @results;
@results.append: .find('a')».text for $dom.find('b');
is-deeply @results, [qw(bar baz yada)], 'right results';
is-deeply $dom.find('a')».text, [qw(foo bar baz yada)], 'right results';
@results = ();
@results.append: .find('c a')».text for $dom.find('b');
is-deeply @results, [qw(baz yada)], 'right results';
is $dom.at('b').at('a').text, 'bar', 'right text';
is $dom.at('c > b > a').text, 'bar', 'right text';
is $dom.at('b').at('c > b > a'), Nil, 'no result';

# Direct hash access to attributes in XML mode
$dom = DOM::Parser.new.xml(1).parse(qq:to/END/);
<a id="one">
  <B class="two" test>
    foo
    <c id="three">bar</c>
    <c ID="four">baz</c>
  </B>
</a>
END
ok $dom.xml, 'XML mode active';
is $dom.at('a')<id>, 'one', 'right attribute';
is-deeply $dom.at('a').keys.sort, ['id'], 'right attributes';
is $dom.at('a').at('B').text, 'foo', 'right text';
is $dom.at('B')<class>, 'two', 'right attribute';
is-deeply $dom.at('a B').keys.sort, [qw(class test)], 'right attributes';
is $dom.find('a B c')[0].text, 'bar', 'right text';
is $dom.find('a B c')[0]<id>, 'three', 'right attribute';
is-deeply $dom.find('a B c')[0].keys.sort, ['id'], 'right attributes';
is $dom.find('a B c')[1].text, 'baz', 'right text';
is $dom.find('a B c')[1]<ID>, 'four', 'right attribute';
is-deeply $dom.find('a B c')[1].keys.sort, ['ID'], 'right attributes';
is $dom.find('a B c')[2], Nil, 'no result';
is $dom.find('a B c').elems, 2, 'right number of elements';
is-deeply $dom.find('a B c')».text, [qw(bar baz)], 'right results';
is $dom.find('a B c').join("\n"),
  qq{<c id="three">bar</c>\n<c ID="four">baz</c>}, 'right result';
is-deeply $dom.keys, [], 'root has no attributes';
is $dom.find('#nothing').join, '', 'no result';

# Direct hash access to attributes in HTML mode
$dom = DOM::Parser.new(qq:to/END/);
<a id="one">
  <B class="two" test>
    foo
    <c id="three">bar</c>
    <c ID="four">baz</c>
  </B>
</a>
END
ok !$dom.xml, 'XML mode not active';
is $dom.at('a')<id>, 'one', 'right attribute';
is-deeply $dom.at('a').keys.sort, ['id'], 'right attributes';
is $dom.at('a').at('b').text, 'foo', 'right text';
is $dom.at('b')<class>, 'two', 'right attribute';
is-deeply $dom.at('a b').keys.sorts, [qw(class test)], 'right attributes';
is $dom.find('a b c')[0].text, 'bar', 'right text';
is $dom.find('a b c')[0]<id>, 'three', 'right attribute';
is-deeply $dom.find('a b c')[0].keys.sort, ['id'], 'right attributes';
is $dom.find('a b c')[1].text, 'baz', 'right text';
is $dom.find('a b c')[1]<id>, 'four', 'right attribute';
is-deeply $dom.find('a b c')[1].keys.sort, ['id'], 'right attributes';
is $dom.find('a b c')[2], Nil, 'no result';
is $dom.find('a b c').elems, 2, 'right number of elements';
is-deeply $dom.find('a b c')».text, [qw(bar baz)], 'right results';
is $dom.find('a b c').join("\n"),
  qq{<c id="three">bar</c>\n<c id="four">baz</c>}, 'right result';
is-deeply $dom.keys, [], 'root has no attributes';
is $dom.find('#nothing').join, '', 'no result';

# Append and prepend content
$dom = DOM::Parser.new('<a><b>Test<c /></b></a>');
$dom.at('b').append-content('<d />');
is $dom.children[0].tag, 'a', 'right tag';
is $dom.all-text, 'Test', 'right text';
is $dom.at('c').parent.tag, 'b', 'right tag';
is $dom.at('d').parent.tag, 'b', 'right tag';
$dom.at('b').prepend-content('<e>Mojo</e>');
is $dom.at('e').parent.tag, 'b', 'right tag';
is $dom.all-text, 'Mojo Test', 'right text';

# Wrap elements
$dom = DOM::Parser.new('<a>Test</a>');
is "$dom", '<a>Test</a>', 'right result';
is $dom.wrap('<b></b>').type, 'root', 'right type';
is "$dom", '<a>Test</a>', 'no changes';
is $dom.at('a').wrap('<b></b>').type, 'tag', 'right type';
is "$dom", '<b><a>Test</a></b>', 'right result';
is $dom.at('b').strip.at('a').wrap('A').tag, 'a', 'right tag';
is "$dom", '<a>Test</a>', 'right result';
is $dom.at('a').wrap('<b></b>').tag, 'a', 'right tag';
is "$dom", '<b><a>Test</a></b>', 'right result';
is $dom.at('a').wrap('C<c><d>D</d><e>E</e></c>F').parent.tag, 'd',
  'right tag';
is "$dom", '<b>C<c><d>D<a>Test</a></d><e>E</e></c>F</b>', 'right result';

# Wrap content
$dom = DOM::Parser.new('<a>Test</a>');
is $dom.at('a').wrap_content('A').tag, 'a', 'right tag';
is "$dom", '<a>Test</a>', 'right result';
is $dom.wrap_content('<b></b>').type, 'root', 'right type';
is "$dom", '<b><a>Test</a></b>', 'right result';
is $dom.at('b').strip.at('a').tag('e:a').wrap-content('1<b c="d"></b>')
  .tag, 'e:a', 'right tag';
is "$dom", '<e:a>1<b c="d">Test</b></e:a>', 'right result';
is $dom.at('a').wrap_content('C<c><d>D</d><e>E</e></c>F').parent.type,
  'root', 'right type';
is "$dom", '<e:a>C<c><d>D1<b c="d">Test</b></d><e>E</e></c>F</e:a>',
  'right result';

# Broken "div" in "td"
$dom = DOM::Parser.new(qq:to/END/);
<table>
  <tr>
    <td><div id="A"></td>
    <td><div id="B"></td>
  </tr>
</table>
END
is $dom.find('table tr td')[0].at('div')<id>, 'A', 'right attribute';
is $dom.find('table tr td')[1].at('div')<id>, 'B', 'right attribute';
is $dom.find('table tr td')[2], Nil, 'no result';
is $dom.find('table tr td').elems, 2, 'right number of elements';
is "$dom", qq:to/END/, 'right result';
<table>
  <tr>
    <td><div id="A"></div></td>
    <td><div id="B"></div></td>
  </tr>
</table>
END

# Preformatted text
$dom = DOM::Parser.new(qq:to/END/);
<div>
  looks
  <pre><code>like
  it
    really</code>
  </pre>
  works
</div>
END
is $dom.text, '', 'no text';
is $dom.text(0), "\n", 'right text';
is $dom.all-text, "looks like\n  it\n    really\n  works", 'right text';
is $dom.all-text(0), "\n  looks\n  like\n  it\n    really\n  \n  works\n\n",
  'right text';
is $dom.at('div').text, 'looks works', 'right text';
is $dom.at('div').text(0), "\n  looks\n  \n  works\n", 'right text';
is $dom.at('div').all-text, "looks like\n  it\n    really\n  works",
  'right text';
is $dom.at('div').all-text(0),
  "\n  looks\n  like\n  it\n    really\n  \n  works\n", 'right text';
is $dom.at('div pre').text, "\n  ", 'right text';
is $dom.at('div pre').text(0), "\n  ", 'right text';
is $dom.at('div pre').all-text, "like\n  it\n    really\n  ", 'right text';
is $dom.at('div pre').all-text(0), "like\n  it\n    really\n  ", 'right text';
is $dom.at('div pre code').text, "like\n  it\n    really", 'right text';
is $dom.at('div pre code').text(0), "like\n  it\n    really", 'right text';
is $dom.at('div pre code').all-text, "like\n  it\n    really", 'right text';
is $dom.at('div pre code').all-text(0), "like\n  it\n    really",
  'right text';

# Form values
$dom = DOM::Parser.new(qq:to/END/);
<form action="/foo">
  <p>Test</p>
  <input type="text" name="a" value="A" />
  <input type="checkbox" checked name="b" value="B">
  <input type="radio" checked name="c" value="C">
  <select multiple name="f">
    <option value="F">G</option>
    <optgroup>
      <option>H</option>
      <option selected>I</option>
    </optgroup>
    <option value="J" selected>K</option>
  </select>
  <select name="n"><option>N</option></select>
  <select multiple name="q"><option>Q</option></select>
  <select name="d">
    <option selected>R</option>
    <option selected>D</option>
  </select>
  <textarea name="m">M</textarea>
  <button name="o" value="O">No!</button>
  <input type="submit" name="p" value="P" />
</form>
END
is $dom.at('p').val,                         Nil, 'no value';
is $dom.at('input').val,                     'A',   'right value';
is $dom.at('input:checked').val,             'B',   'right value';
is $dom.at('input:checked[type=radio]').val, 'C',   'right value';
is-deeply $dom.at('select').val, ['I', 'J'], 'right values';
is $dom.at('select option').val,                          'F', 'right value';
is $dom.at('select optgroup option:not([selected])').val, 'H', 'right value';
is $dom.find('select')[1].at('option').val, 'N', 'right value';
is $dom.find('select')[1].val,        Nil, 'no value';
is-deeply $dom.find('select')[2].val, Nil, 'no value';
is $dom.find('select')[2].at('option').val, 'Q', 'right value';
is-deeply $dom.find('select').last.val, 'D', 'right value';
is-deeply $dom.find('select').last.at('option').val, 'R', 'right value';
is $dom.at('textarea').val, 'M', 'right value';
is $dom.at('button').val,   'O', 'right value';
is $dom.find('form input').last.val, 'P', 'right value';

# PoCo example with whitespace sensitive text
$dom = DOM::Parser.new(qq:to/END/);
<?xml version="1.0" encoding="UTF-8"?>
<response>
  <entry>
    <id>1286823</id>
    <displayName>Homer Simpson</displayName>
    <addresses>
      <type>home</type>
      <formatted><![CDATA[742 Evergreen Terrace
Springfield, VT 12345 USA]]></formatted>
    </addresses>
  </entry>
  <entry>
    <id>1286822</id>
    <displayName>Marge Simpson</displayName>
    <addresses>
      <type>home</type>
      <formatted>742 Evergreen Terrace
Springfield, VT 12345 USA</formatted>
    </addresses>
  </entry>
</response>
END
is $dom.find('entry')[0].at('displayName').text, 'Homer Simpson',
  'right text';
is $dom.find('entry')[0].at('id').text, '1286823', 'right text';
is $dom.find('entry')[0].at('addresses').children('type')[0].text,
  'home', 'right text';
is $dom.find('entry')[0].at('addresses formatted').text,
  "742 Evergreen Terrace\nSpringfield, VT 12345 USA", 'right text';
is $dom.find('entry')[0].at('addresses formatted').text(0),
  "742 Evergreen Terrace\nSpringfield, VT 12345 USA", 'right text';
is $dom.find('entry')[1].at('displayName').text, 'Marge Simpson',
  'right text';
is $dom.find('entry')[1].at('id').text, '1286822', 'right text';
is $dom.find('entry')[1].at('addresses').children('type')[0].text,
  'home', 'right text';
is $dom.find('entry')[1].at('addresses formatted').text,
  '742 Evergreen Terrace Springfield, VT 12345 USA', 'right text';
is $dom.find('entry')[1].at('addresses formatted').text(0),
  "742 Evergreen Terrace\nSpringfield, VT 12345 USA", 'right text';
is $dom.find('entry')[2], Nil, 'no result';
is $dom.find('entry').elems, 2, 'right number of elements';

# Find attribute with hyphen in name and value
$dom = DOM::Parser.new(qq:to/END/);
<html>
  <head><meta http-equiv="content-type" content="text/html"></head>
</html>
END
is $dom.find('[http-equiv]')[0]<content>, 'text/html', 'right attribute';
is $dom.find('[http-equiv]')[1], Nil, 'no result';
is $dom.find('[http-equiv="content-type"]')[0]<content>, 'text/html',
  'right attribute';
is $dom.find('[http-equiv="content-type"]')[1], Nil, 'no result';
is $dom.find('[http-equiv^="content-"]')[0]<content>, 'text/html',
  'right attribute';
is $dom.find('[http-equiv^="content-"]')[1], Nil, 'no result';
is $dom.find('head > [http-equiv$="-type"]')[0]<content>, 'text/html',
  'right attribute';
is $dom.find('head > [http-equiv$="-type"]')[1], Nil, 'no result';

# Find "0" attribute value
$dom = DOM::Parser.new(qq:to/END/);
<a accesskey="0">Zero</a>
<a accesskey="1">O&gTn&gt;e</a>
END
is $dom.find('a[accesskey]')[0].text, 'Zero',    'right text';
is $dom.find('a[accesskey]')[1].text, 'O&gTn>e', 'right text';
is $dom.find('a[accesskey]')[2], Nil, 'no result';
is $dom.find('a[accesskey=0]')[0].text, 'Zero', 'right text';
is $dom.find('a[accesskey=0]')[1], Nil, 'no result';
is $dom.find('a[accesskey^=0]')[0].text, 'Zero', 'right text';
is $dom.find('a[accesskey^=0]')[1], Nil, 'no result';
is $dom.find('a[accesskey$=0]')[0].text, 'Zero', 'right text';
is $dom.find('a[accesskey$=0]')[1], Nil, 'no result';
is $dom.find('a[accesskey~=0]')[0].text, 'Zero', 'right text';
is $dom.find('a[accesskey~=0]')[1], Nil, 'no result';
is $dom.find('a[accesskey*=0]')[0].text, 'Zero', 'right text';
is $dom.find('a[accesskey*=0]')[1], Nil, 'no result';
is $dom.find('a[accesskey=1]')[0].text, 'O&gTn>e', 'right text';
is $dom.find('a[accesskey=1]')[1], Nil, 'no result';
is $dom.find('a[accesskey^=1]')[0].text, 'O&gTn>e', 'right text';
is $dom.find('a[accesskey^=1]')[1], Nil, 'no result';
is $dom.find('a[accesskey$=1]')[0].text, 'O&gTn>e', 'right text';
is $dom.find('a[accesskey$=1]')[1], Nil, 'no result';
is $dom.find('a[accesskey~=1]')[0].text, 'O&gTn>e', 'right text';
is $dom.find('a[accesskey~=1]')[1], Nil, 'no result';
is $dom.find('a[accesskey*=1]')[0].text, 'O&gTn>e', 'right text';
is $dom.find('a[accesskey*=1]')[1], Nil, 'no result';
is $dom.at('a[accesskey*="."]'), Nil, 'no result';

# Empty attribute value
$dom = DOM::Parser.new(qq:to/END/);
<foo bar=>
  test
</foo>
<bar>after</bar>
END
is $dom.tree[0], 'root', 'right type';
is $dom.tree[1][0], 'tag', 'right type';
is $dom.tree[1][1], 'foo', 'right tag';
is-deeply $dom.tree[1][2], {bar => ''}, 'right attributes';
is $dom.tree[1][4][0], 'text',       'right type';
is $dom.tree[1][4][1], "\n  test\n", 'right text';
is $dom.tree[3][0], 'tag', 'right type';
is $dom.tree[3][1], 'bar', 'right tag';
is $dom.tree[3][4][0], 'text',  'right type';
is $dom.tree[3][4][1], 'after', 'right text';
is "$dom", qq:to/END/, 'right result';
<foo bar="">
  test
</foo>
<bar>after</bar>
END

# Case-insensitive attribute values
$dom = DOM::Parser.new(qq:to/END/);
<p class="foo">A</p>
<p class="foo bAr">B</p>
<p class="FOO">C</p>
END
is $dom.find('.foo')».text.join(','),            'A,B', 'right result';
is $dom.find('.FOO')».text.join(','),            'C',   'right result';
is $dom.find('[class=foo]')».text.join(','),     'A',   'right result';
is $dom.find('[class=foo i]')».text.join(','),   'A,C', 'right result';
is $dom.find('[class="foo" i]')».text.join(','), 'A,C', 'right result';
is $dom.find('[class="foo bar"]')».text, 0, 'no results';
is $dom.find('[class="foo bar" i]')».text.join(','), 'B',
  'right result';
is $dom.find('[class~=foo]')».text.join(','), 'A,B', 'right result';
is $dom.find('[class~=foo i]')».text.join(','), 'A,B,C',
  'right result';
is $dom.find('[class*=f]')».text.join(','),   'A,B',   'right result';
is $dom.find('[class*=f i]')».text.join(','), 'A,B,C', 'right result';
is $dom.find('[class^=F]')».text.join(','),   'C',     'right result';
is $dom.find('[class^=F i]')».text.join(','), 'A,B,C', 'right result';
is $dom.find('[class$=O]')».text.join(','),   'C',     'right result';
is $dom.find('[class$=O i]')».text.join(','), 'A,C',   'right result';

# Nested description lists
$dom = DOM::Parser.new(qq:to/END/);
<dl>
  <dt>A</dt>
  <DD>
    <dl>
      <dt>B
      <dd>C
    </dl>
  </dd>
</dl>
END
is $dom.find('dl > dd > dl > dt')[0].text, 'B', 'right text';
is $dom.find('dl > dd > dl > dd')[0].text, 'C', 'right text';
is $dom.find('dl > dt')[0].text,           'A', 'right text';

# Nested lists
$dom = DOM::Parser.new(qq:to/END/);
<div>
  <ul>
    <li>
      A
      <ul>
        <li>B</li>
        C
      </ul>
    </li>
  </ul>
</div>
END
is $dom.find('div > ul > li')[0].text, 'A', 'right text';
is $dom.find('div > ul > li')[1], Nil, 'no result';
is $dom.find('div > ul li')[0].text, 'A', 'right text';
is $dom.find('div > ul li')[1].text, 'B', 'right text';
is $dom.find('div > ul li')[2], Nil, 'no result';
is $dom.find('div > ul ul')[0].text, 'C', 'right text';
is $dom.find('div > ul ul')[1], Nil, 'no result';

# Unusual order
$dom
  = DOM::Parser.new('<a href="http://example.com" id="foo" class="bar">Ok!</a>');
is $dom.at('a:not([href$=foo])[href^=h]').text, 'Ok!', 'right text';
is $dom.at('a:not([href$=example.com])[href^=h]'), Nil, 'no result';
is $dom.at('a[href^=h]#foo.bar').text, 'Ok!', 'right text';
is $dom.at('a[href^=h]#foo.baz'), Nil, 'no result';
is $dom.at('a[href^=h]#foo:not(b)').text, 'Ok!', 'right text';
is $dom.at('a[href^=h]#foo:not(a)'), Nil, 'no result';
is $dom.at('[href^=h].bar:not(b)[href$=m]#foo').text, 'Ok!', 'right text';
is $dom.at('[href^=h].bar:not(b)[href$=m]#bar'), Nil, 'no result';
is $dom.at(':not(b)#foo#foo').text, 'Ok!', 'right text';
is $dom.at(':not(b)#foo#bar'), Nil, 'no result';
is $dom.at(':not([href^=h]#foo#bar)').text, 'Ok!', 'right text';
is $dom.at(':not([href^=h]#foo#foo)'), Nil, 'no result';

# Slash between attributes
$dom = DOM::Parser.new('<input /type=checkbox / value="/a/" checked/><br/>');
is-deeply $dom.at('input').attr,
  {type => 'checkbox', value => '/a/', checked => Nil}, 'right attributes';
is "$dom", '<input checked type="checkbox" value="/a/"><br>', 'right result';

# Dot and hash in class and id attributes
$dom = DOM::Parser.new('<p class="a#b.c">A</p><p id="a#b.c">B</p>');
is $dom.at('p.a\#b\.c').text,       'A', 'right text';
is $dom.at(':not(p.a\#b\.c)').text, 'B', 'right text';
is $dom.at('p#a\#b\.c').text,       'B', 'right text';
is $dom.at(':not(p#a\#b\.c)').text, 'A', 'right text';

# Extra whitespace
$dom = DOM::Parser.new('< span>a< /span><b >b</b><span >c</ span>');
is $dom.at('span').text,     'a', 'right text';
is $dom.at('span + b').text, 'b', 'right text';
is $dom.at('b + span').text, 'c', 'right text';
is "$dom", '<span>a</span><b>b</b><span>c</span>', 'right result';

# Selectors with leading and trailing whitespace
$dom = DOM::Parser.new('<div id=foo><b>works</b></div>');
is $dom.at(' div   b ').text,          'works', 'right text';
is $dom.at('  :not(  #foo  )  ').text, 'works', 'right text';

# "0"
$dom = DOM::Parser.new('0');
is "$dom", '0', 'right result';
$dom.append-content('☃');
is "$dom", '0☃', 'right result';
is $dom.parse('<!DOCTYPE 0>'),  '<!DOCTYPE 0>',  'successful roundtrip';
is $dom.parse('<!--0-.'),      '<!--0-.',      'successful roundtrip';
is $dom.parse('<![CDATA[0]]>'), '<![CDATA[0]]>', 'successful roundtrip';
is $dom.parse('<?0?>'),         '<?0?>',         'successful roundtrip';

# Not self-closing
$dom = DOM::Parser.new('<div />< div ><pre />test</div >123');
is $dom.at('div > div > pre').text, 'test', 'right text';
is "$dom", '<div><div><pre>test</pre></div>123</div>', 'right result';
$dom = DOM::Parser.new('<p /><svg><circle /><circle /></svg>');
is $dom.find('p > svg > circle').elems, 2, 'two circles';
is "$dom", '<p><svg><circle></circle><circle></circle></svg></p>',
  'right result';

# "image"
$dom = DOM::Parser.new('<image src="foo.png">test');
is $dom.at('img')<src>, 'foo.png', 'right attribute';
is "$dom", '<img src="foo.png">test', 'right result';

# "title"
$dom = DOM::Parser.new('<title> <p>test&lt;</title>');
is $dom.at('title').text, ' <p>test<', 'right text';
is "$dom", '<title> <p>test<</title>', 'right result';

# "textarea"
$dom = DOM::Parser.new('<textarea id="a"> <p>test&lt;</textarea>');
is $dom.at('textarea#a').text, ' <p>test<', 'right text';
is "$dom", '<textarea id="a"> <p>test<</textarea>', 'right result';

# Comments
$dom = DOM::Parser.new(qq:to/END/);
<!-- HTML5 -.
<!-- bad idea -- HTML5 -.
<!-- HTML4 -- >
<!-- bad idea -- HTML4 -- >
END
is $dom.tree[1][1], ' HTML5 ',             'right comment';
is $dom.tree[3][1], ' bad idea -- HTML5 ', 'right comment';
is $dom.tree[5][1], ' HTML4 ',             'right comment';
is $dom.tree[7][1], ' bad idea -- HTML4 ', 'right comment';

# Huge number of attributes
$dom = DOM::Parser.new('<div ' ~ ('a=b ' x 32768) ~ '>Test</div>');
is $dom.at('div[a=b]').text, 'Test', 'right text';

# Huge number of nested tags
my $huge = ('<a>' x 100) ~ 'works' ~ ('</a>' x 100);
$dom = DOM::Parser.new($huge);
is $dom.all-text, 'works', 'right text';
is "$dom", $huge, 'right result';

done-testing;
