=====================
독유틸즈로 HTML 작성
=====================

.. contents::

html
------

`html` 은 독유틸즈 HTML 작성기의 기본 명령어다. 최근, `html` 은 html4css1_\ 에 맵핑됐다.

HTML, 브라우저, 독유틸즈, 웹의 발전과 함께 목표는 바뀔 것이다.

* 자동으로 결과가 최신으로 업데이트 되게 하려면,
  ``get_writer_by_name('html')`` 나 rst2html.py_ 프론트엔드를 사용해라.

* 생성된 HTML 코드의 안정성에 의존한다면, 특정 작성기 이름이나 프론트 엔드를 사용해라.
  그렇게 하지 않으면 파손될 수 있는 사용자 정의 스타일시트나 후 처리(post-processing)를
  사용할 수 있기 때문이다.


html4css1
------------

:aliases:    html4, html_
:front-ends: rst2html4.py, rst2html.py_
:config:     `[html4css1 writer]`_

HTML 작성기 모듈인 ``docutils/writers/html4css1.py`` 은 첫 독유틸즈 작성기이며
0.13까지 발행된 유일한 공식 HTML 작성기다.

결과는 `XHTML 1 Transitional`_ 설명서를 따른다. XML에서 요구되지만 HTML4에서는
허용되지 않는 빈 태그의 종료로 인해 `HTML 4.01 Transitional`_\ 로 인정되지 않는다.
그러나 대부분의 HTML 사용자가 올바르게 렌더링하기 위해, 결과는 `HTML 호환성 지침`_\ 을 따른다.

정확한 렌더링은 CSS_ 스타일시트에 의존한다. 참조 스타일시트인 `html4css1.css`_\ 가 제공되며,
기본적으로 사용된다.

`Internet Explorer`\ (이 작성기가 쓰여진 2002년에는 시장점유율이 약 90%였다)를
지원하기 위해 문서는 하드코드된 포매팅 힌트를 포함하며,
"text/html" 로 태그되어 있다. ( "application/xhtml+xml" 대신). [#IE]_

.. [#IE] Conformance to `CSS 2.1`_\에 대한 적합성은 IE 8 (2009)부터 추가됐으며,
   XHTML에 대한 지원은 IE 9 (2011)부터다.

.. _rst2html.py: tools.html#rst2html-py
.. _[html4css1 writer]: config.html#html4css1-writer
.. _html4css1.css: ../../docutils/writers/html4css1/html4css1.css

pep_html
~~~~~~~~

:front-end: rstpep2html.py_
:config:    `[pep_html writer]`_

이것은 `Python Enhancement Proposals`_ (PEPs)를 생성하기 위한 특별한 작성기다.
html4css1_\ 에서 상속받으며, 몇몇 `PEP-specific options`_, 스타일시트, 템플릿을 추가한다.
프론트엔드는 또한 특화된 판독기를 사용한다.

.. _rstpep2html.py: tools.html#rstpep2html-py
.. _PEP-specific options:
.. _[pep_html writer]: config.html#pep-html-writer
.. _Python Enhancement Proposals: https://www.python.org/dev/peps/

s5_html
~~~~~~~

:alias:     s5
:front-end: rst2s5.py_
:config:    `[s5_html writer]`_

`s5` 작성기는 html4css1_\ 에서 상속받는다. Eric Meyer가 만든
“간단한 표준 기반 슬라이드 쇼 시스템”인 S5_ 사용을 위한, XHTML을 만든다.
자세한 내용은 `reST & S5의 쉬운 슬라이드 쇼`_\ 를 봐라.

.. _rst2s5.py: tools.html#rst2s5-py
.. _[s5_html writer]: config.html#s5-html-writer
.. _reST & S5의 쉬운 슬라이드 쇼: slide-shows.html
.. _S5: http://meyerweb.com/eric/tools/s5/
.. _theme: tools.html#themes


html5_polyglot
-----------------

:aliases: html5
:front-end: rst2html5.py_
:config: `[html5 writer]`_

``html5_polyglot`` 작성기는 `HTML5`_\ 와 호환되는 유효한 XML [#safetext]_\ 인
`polyglot HTML`_ [#]_ 출력을 생성한다. 새로운 특성과 요소는 오직 그것들이
`어느 브라우저에서나 볼 수 있는`_ 문서를 만들기 위해 폭넓게 지원받을 때 사용된다.

HTML 문서에는 하드코드된 포매팅 정보가 없다. 직접적으로 HTML의 지원을 받지 않는 요소의 정확한
렌더링은 CSS_ 스타일시트에 의존한다. 제공된 스타일시트 minimal.css_\ 와 plain.css_\ 는
각자 요구된 부가적인 스타일 규칙을 정의한다. 레이아웃의 개조는
`사용자 지정 스타일시트`_\ 면 가능하다. [#safetext]_

독유틸즈 0.13의 새로운 것

.. [#] `polyglot XHTML5의 장점`_\ 도 봐라.
.. [#safetext] 원본 HTML과 사용자 지정 스타일시트의 유효성은 작성자가 보장해야 한다.
   (예: `안전한 텍스트 내용`_ 사용).

.. _rst2html5.py: tools.html#rst2html5-py
.. _[html5 writer]: config.html#html5-writer
.. _minimal.css: ../../docutils/writers/html5_polyglot/minimal.css
.. _plain.css: ../../docutils/writers/html5_polyglot/plain.css
.. _사용자 지정 스타일시트: ../howto/html-stylesheets.html
.. _어느 브라우저에서나 볼 수 있는: http://www.anybrowser.org/campaign
.. _polyglot XHTML5의 장점: http://xmlplease.com/xhtml/xhtml5polyglot/
.. _안전한 텍스트 내용:
     https://www.w3.org/TR/html-polyglot/#dfn-safe-text-content


샌드박스의 HTML 작성기
---------------------------

샌드박스_\ 의 HTML 작성기는 2개 이상이 있다:

.. _샌드박스: ../dev/policies.html#the-sandbox

xhtml11
~~~~~~~
:aliases:   xhtml, html4strict
:front-end: rst2xhtml.py
:config:    `[xhtml11 writer]`

`XHTML 1.1`_\ 는 공식적인 DTD의 `extensible Hypertext Markup Language` 기반의
최신버전 XML이다.

`xhtml11 작성기`_\ 는 2008년 이후로 독유틸즈 샌드박스_ 안에 있다.
결과는 엄격한 `XHTML 1.1`_ 요구를 따른다.

.. _xhtml11 작성기: ../../../sandbox/html4strict/README.html


html4trans
~~~~~~~~~~

:front-end: rst2html_trans.py_

`가벼운 브라우저용 HTML 작성기`_\ 는 2008년부터
독유틸즈 샌드박스 (`sandbox/html4trans`_)에 있다. CSS에 대한 의존성을 제거했다.
출력은 `XHTML 1 Transitional`_\ 을 따르며, 스타일시트가 없는 렌더링에 대한
충분한 포매팅 정보를 포함한다. (당연히, 이는 몇가지 `문제점`_\ 이 있다.)

.. _가벼운 브라우저용 HTML 작성기:
   ../../../sandbox/html4trans/README.html
.. _문제점: ../../../sandbox/html4trans/README.html#drawbacks
.. _sandbox/html4trans: ../../../sandbox/html4trans
.. _rst2html_trans.py: ../../../sandbox/html4trans/tools/rst2html_trans.py


개요
--------

=============== =========== ============== ================= ===========
name            alias(es)   `front-end`_   HTML version      CSS version
=============== =========== ============== ================= ===========
html4css1_      html4,      rst2html4.py,  `XHTML 1          `CSS 1`_
                html_       rst2html.py    Transitional`_

pep_html_       ..          rstpep2html.py `XHTML 1          `CSS 1`_
                                           Transitional`_

s5_html_        s5          rst2s5.py      `XHTML 1          `CSS 1`_
                                           Transitional`_

html5_polyglot_ html5       rst2html5.py   `HTML5`_          `CSS 3`_

xhtml11_        xhtml,      rst2xhtml.py   `XHTML 1.1`_      `CSS 3`_
                html4strict

html4trans_ ..              rst2html_trans `XHTML 1          no CSS
                                           Transitional`_    required
=============== =========== ============== ================= ===========


References
----------

_`HTML5`
   `HTML5, A vocabulary and associated APIs for HTML and XHTML`,
   W3C Recommendation, 28 October 2014.
   http://www.w3.org/TR/html5/

_`XHTML 1.1`
   `XHTML™ 1.1 - Module-based XHTML - Second Edition`,
   W3C Recommendation, 23 November 2010.
   http://www.w3.org/TR/xhtml11/

_`XHTML 1 Transitional`
   `Transitional version`_ of:
   `XHTML™ 1.0 The Extensible HyperText Markup Language (Second
   Edition)`, `A Reformulation of HTML 4 in XML 1.0`,
   W3C Recommendation, 26 January 2000, revised 1 August 2002.
   http://www.w3.org/TR/xhtml1/

_`XHTML Basic`
   `XHTML™ Basic 1.1 - Second Edition`,
   W3C Recommendation, 23 November 2010.
   http://www.w3.org/TR/xhtml-basic/

.. _transitional version:
   http://www.w3.org/TR/xhtml1/#a_dtd_XHTML-1.0-Transitional

_`HTML 4.01 Transitional`
  Transitional version of:
  `HTML 4.01 Specification`, W3C Recommendation 24 December 1999.
  http://www.w3.org/TR/html4/

.. _`CSS 1`:

_`CSS Level 1`:
  The features defined in the `CSS1 specification`_, but using the syntax
  and definitions in the `CSS 2.1`_ specification.

_`CSS 2.1` `Cascading Style Sheets Level 2 Revision 1 (CSS 2.1) Specification`,
  W3C Recommendation 07 June 2011.
  http://www.w3.org/TR/CSS21/

_`CSS 3`:
  CSS Level 3 builds on CSS Level 2 module by module, using the CSS2.1
  specification as its core.

  Specifications: http://www.w3.org/Style/CSS/specs.en.html

  Validator: http://jigsaw.w3.org/css-validator/

.. other references
   ----------------

.. _HTML 호환성 지침: http://www.w3.org/TR/xhtml1/#guidelines
.. _CSS: http://www.w3.org/TR/CSS/
.. _CSS1 specification: http://www.w3.org/TR/2008/REC-CSS1-20080411/
.. _polyglot HTML: http://www.w3.org/TR/html-polyglot/

   .. Beware. This specification is no longer in active maintenance and the
      HTML Working Group does not intend to maintain it further.

.. Appendix


      On the question of Polyglot markup, there seems to be little
      consensus. One line of argument suggests that, to the extent that it
      is practical to obey the Robustness principle, it makes sense to do
      so. That is, if you're generating HTML markup for the web, and you can
      generate Polyglot markup that is also directly consumable as XML, you
      should do so. Another line of argument suggests that even under the
      most optimistic of projections, so tiny a fraction of the web will
      ever be written in Polyglot that there's no practical benefit to
      pursuing it as a general strategy for consuming documents from the
      web. If you want to consume HTML content, use an HTML parser that
      produces an XML-compatible DOM or event stream.

      -- https://www.w3.org/TR/html-xml-tf-report/#conclusions

  Further development

  On 2016-05-25, David Goodger wrote:

  > In addition, I'd actually like to see the HTML writer(s) with
  > fully-parameterized classes, i.e. removing hard-coded *classes* as well as
  > formatting. This way, any user who wants to (e.g.) write reST for use with
  > Bootstrap can easily work around any naming conflicts.



  Problems with html4css1 writer:

  1. Limiting ourself to CSS Level 1 requires use of hard-coded HTML
     formatting to get all rST objects mapped to HTML.
     Hard-coded HTML formatting is considered bad practice.

  2. Maths cannot be included in MathML format without rendering a
     hmtl4css1-generated document invalid.

     (XHTML 1.1. is the only member of the "HTML4 family" allowing embedding
     of MathML. However, hard-coded HTML formatting prevents its use.)



  Comparison of current HTML versions
  ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

  XHTML1.1
  """"""""

  +2 XML-based with official DTD
     +1 allows processing with XML-tool-chain
     +1 allows validating against the DTD

  +1 writer exists (in sandbox) and in active use since 2008

  -1 "old" format
  -1 requires to work around restrictions lifted in HTML5
     ("start" argument for enumerated lists, some tags in parsed literal)
     which makes code and documents more complicated

  HTML5
  """""
  +1 more recent
  +1 simpler to write, less restrictions

  +1 writer exists and in active use since 2015

  +1 new page structure elements such as <main>, <section>, <article>,
     <header>, <footer>, <aside>, <nav> and <figure>
     provide better matches for the rst document model.

  -1 new elements not yet supported by many browsers.

  -2 no DTD
     - no proper validation possible (there is an experimental validator)
     - no standard interface to post-processing XML-tools

  -1 two concurring definitions:
     W3C standard and WHATWG "HTML Living Standard".

.. _front-end: tools.html
