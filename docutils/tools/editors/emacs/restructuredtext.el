;; Authors: Martin Blais <blais@furius.ca>,
;;          David Goodger <goodger@python.org>
;; Date: $Date$
;; Copyright: This module has been placed in the public domain.
;;
;; Support code for editing reStructuredText with Emacs indented-text mode.
;; The goal is to create an integrated reStructuredText editing mode.
;;
;; Installation instructions
;; -------------------------
;;
;; Add this line to your .emacs file and bind the versatile sectioning commands
;; in text mode, like this::
;;
;;   (require 'restructuredtext)
;;   (add-hook 'text-mode-hook 'rest-text-mode-hook)
;;
;; The keys it defines are:
;;
;;    C-= : updates or rotates the section title around point or
;;          promotes/demotes the decorations within the region (see full details
;;          below).
;;
;;          Note that C-= is a good binding, since it allows you to specify a
;;          negative arg easily with C-- C-= (easy to type), as well as ordinary
;;          prefix arg with C-u C-=.
;;
;;    C-x C-= : displays the hierarchical table-of-contents of the document and
;;              allows you to jump to any section from it.
;;
;;    C-u C-x C-= : displays the title decorations from this file.
;;
;;    C-x + : insert the table of contents in the text.  See the many options
;;            for customizing how it will look.
;;
;;    C-M-{, C-M-} : navigate between section titles.
;;
;; Other specialized and more generic functions are also available (see source
;; code).  The most important function provided by this file for section title
;; adjustments is rest-adjust.
;;
;; There are many variables that can be customized, look for defcustom and
;; defvar in this file.
;;
;; If you use the table-of-contents feature, you may want to add a hook to
;; update the TOC automatically everytime you adjust a section title::
;;
;;   (add-hook 'rest-adjust-hook 'rest-toc-insert-update)
;;
;;
;; TODO
;; ====
;;
;; rest-toc-insert features
;; ------------------------
;; - Support local table of contents, like in doctree.txt.
;; - On load, detect any existing TOCs and set the properties for links.
;; - TOC insertion should have an option to add empty lines.
;; - TOC insertion should deal with multiple lines
;;
;; - There is a bug on redo after undo of adjust when rest-adjust-hook uses the
;;   automatic toc update. The cursor ends up in the TOC and this is
;;   annoying. Gotta fix that.
;;
;; Other
;; -----
;; - Add an option to forego using the file structure in order to make
;;   suggestion, and to always use the preferred decorations to do that.
;;


(require 'cl)

(defun rest-toc-or-hierarchy ()
  "Binding for either TOC or decorations hierarchy."
  (interactive)
  (if (not current-prefix-arg)
      (rest-toc)
    (rest-display-decorations-hierarchy)))

(defun rest-text-mode-hook ()
  "Default text mode hook for rest."
  (local-set-key [(control ?=)] 'rest-adjust)
  (local-set-key [(control x)(control ?=)] 'rest-toc-or-hierarchy)
  (local-set-key [(control x)(?+)] 'rest-toc-insert)
  (local-set-key [(control meta ?{)] 'rest-backward-section)
  (local-set-key [(control meta ?})] 'rest-forward-section)
  )

;; Note: we cannot do this because it messes with undo.  If we disable undo,
;; since it adds and removes characters, the positions in the undo list are not
;; making sense anymore.  Dunno what to do with this, it would be nice to update
;; when saving.
;;
;; (add-hook 'write-contents-hooks 'rest-toc-insert-update-fun)
;; (defun rest-toc-insert-update-fun ()
;;   ;; Disable undo for the write file hook.
;;   (let ((buffer-undo-list t)) (rest-toc-insert-update) ))



;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; Generic Filter function.

(if (not (fboundp 'filter))
    (defun filter (pred list)
      "Returns a list of all the elements fulfilling the pred requirement (that
is for which (pred elem) is true)"
      (if list
          (let ((head (car list))
                (tail (filter pred (cdr list))))
            (if (funcall pred head)
                (cons head tail)
              tail)))))


;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; From emacs-22

(if (not (fboundp 'line-number-at-pos))
    (defun line-number-at-pos (&optional pos)
      "Return (narrowed) buffer line number at position POS.
    If POS is nil, use current buffer location."
      (let ((opoint (or pos (point))) start)
        (save-excursion
          (goto-char (point-min))
          (setq start (point))
          (goto-char opoint)
          (forward-line 0)
          (1+ (count-lines start (point)))))) )

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;
;; The following functions implement a smart automatic title sectioning feature.
;; The idea is that with the cursor sitting on a section title, we try to get as
;; much information from context and try to do the best thing automatically.
;; This function can be invoked many times and/or with prefix argument to rotate
;; between the various sectioning decorations.
;;
;; Definitions: the two forms of sectioning define semantically separate section
;; levels.  A sectioning DECORATION consists in:
;;
;;   - a CHARACTER
;;
;;   - a STYLE which can be either of 'simple' or 'over-and-under'.
;;
;;   - an INDENT (meaningful for the over-and-under style only) which determines
;;     how many characters and over-and-under style is hanging outside of the
;;     title at the beginning and ending.
;;
;; Important note: an existing decoration must be formed by at least two
;; characters to be recognized.
;;
;; Here are two examples of decorations (| represents the window border, column
;; 0):
;;
;;                                  |
;; 1. char: '-'   e                 |Some Title
;;    style: simple                 |----------
;;                                  |
;; 2. char: '='                     |==============
;;    style: over-and-under         |  Some Title
;;    indent: 2                     |==============
;;                                  |
;;
;; Some notes:
;;
;; - The underlining character that is used depends on context. The file is
;;   scanned to find other sections and an appropriate character is selected.
;;   If the function is invoked on a section that is complete, the character is
;;   rotated among the existing section decorations.
;;
;;   Note that when rotating the characters, if we come to the end of the
;;   hierarchy of decorations, the variable rest-preferred-decorations is
;;   consulted to propose a new underline decoration, and if continued, we cycle
;;   the decorations all over again.  Set this variable to nil if you want to
;;   limit the underlining character propositions to the existing decorations in
;;   the file.
;;
;; - A prefix argument can be used to alternate the style.
;;
;; - An underline/overline that is not extended to the column at which it should
;;   be hanging is dubbed INCOMPLETE.  For example::
;;
;;      |Some Title
;;      |-------
;;
;; Examples of default invocation:
;;
;;   |Some Title       --->    |Some Title
;;   |                         |----------
;;
;;   |Some Title       --->    |Some Title
;;   |-----                    |----------
;;
;;   |                         |------------
;;   | Some Title      --->    | Some Title
;;   |                         |------------
;;
;; In over-and-under style, when alternating the style, a variable is available
;; to select how much default indent to use (it can be zero).  Note that if the
;; current section decoration already has an indent, we don't adjust it to the
;; default, we rather use the current indent that is already there for
;; adjustment (unless we cycle, in which case we use the indent that has been
;; found previously).

(defcustom rest-preferred-decorations '( (?= over-and-under 1)
					 (?= simple 0)
					 (?- simple 0)
					 (?~ simple 0)
					 (?+ simple 0)
					 (?` simple 0)
					 (?# simple 0)
					 (?@ simple 0) )
  "Preferred ordering of section title decorations.  This
  sequence is consulted to offer a new decoration suggestion when
  we rotate the underlines at the end of the existing hierarchy
  of characters, or when there is no existing section title in
  the file.")


(defcustom rest-default-indent 1
  "Number of characters to indent the section title when toggling
  decoration styles.  This is used when switching from a simple
  decoration style to a over-and-under decoration style.")


(defvar rest-section-text-regexp "^[ \t]*\\S-*[a-zA-Z0-9]\\S-*"
  "Regular expression for valid section title text.")


(defun rest-line-homogeneous-p (&optional accept-special)
  "Predicate return the unique char if the current line is
  composed only of a single repeated non-whitespace
  character. This returns the char even if there is whitespace at
  the beginning of the line.

  If ACCEPT-SPECIAL is specified we do not ignore special sequences
  which normally we would ignore when doing a search on many lines.
  For example, normally we have cases to ignore commonly occuring
  patterns, such as :: or ...;  with the flag do not ignore them."
  (save-excursion
    (back-to-indentation)
    (if (not (looking-at "\n"))
        (let ((c (thing-at-point 'char)))
          (if (and (looking-at (format "[%s]+[ \t]*$" c))
                   (or accept-special
                       (and
                        ;; Common patterns.
                        (not (looking-at "::[ \t]*$"))
                        (not (looking-at "\\.\\.\\.[ \t]*$"))
                        ;; Discard one char line
                        (not (looking-at ".[ \t]*$"))
                        )))
              (string-to-char c))
          ))
    ))

(defun rest-line-homogeneous-nodent-p (&optional accept-special)
  (save-excursion
    (beginning-of-line)
    (if (looking-at "^[ \t]+")
	nil
      (rest-line-homogeneous-p accept-special)
      )))


(defun rest-compare-decorations (deco1 deco2)
  "Compare decorations.  Returns true if both are equal,
according to restructured text semantics (only the character and
the style are compared, the indentation does not matter."
  (and (eq (car deco1) (car deco2))
       (eq (cadr deco1) (cadr deco2))))


(defun rest-get-decoration-match (hier deco)
  "Returns the index (level) of the decoration in the given hierarchy.
This basically just searches for the item using the appropriate
comparison and returns the index.  We return nil if the item is
not found."
  (let ((cur hier))
    (while (and cur (not (rest-compare-decorations (car cur) deco)))
      (setq cur (cdr cur)))
    cur))


(defun rest-suggest-new-decoration (alldecos &optional prev)
  "Suggest a new, different decoration, different from all that
have been seen.

  ALLDECOS is the set of all decorations, including the line
  numbers.  PREV is the optional previous decoration, in order to
  suggest a better match."

  ;; For all the preferred decorations...
  (let* (
	 ;; If 'prev' is given, reorder the list to start searching after the
	 ;; match.
	 (fplist
	  (cdr (rest-get-decoration-match rest-preferred-decorations prev)))

	 ;; List of candidates to search.
	 (curpotential (append fplist rest-preferred-decorations)))
    (while
	;; For all the decorations...
	(let ((cur alldecos)
	      found)
	  (while (and cur (not found))
	    (if (rest-compare-decorations (car cur) (car curpotential))
		;; Found it!
		(setq found (car curpotential))
	      (setq cur (cdr cur))))
	  found)

      (setq curpotential (cdr curpotential)))

    (copy-list (car curpotential)) ))

(defun rest-delete-line ()
  "A version of kill-line that does not use the kill-ring."
  (delete-region (line-beginning-position) (+ 1 (line-end-position))))

(defun rest-update-section (char style &optional indent)
  "Unconditionally updates the style of a section decoration
  using the given character CHAR, with STYLE 'simple or
  'over-and-under, and with indent INDENT.  If the STYLE is
  'simple, whitespace before the title is removed (indent is
  always assume to be 0).

  If there are existing overline and/or underline from the
  existing decoration, they are removed before adding the
  requested decoration."

  (interactive)
  (let (marker
        len
        ec
        (c ?-))

      (end-of-line)
      (setq marker (point-marker))

      ;; Fixup whitespace at the beginning and end of the line
      (if (or (null indent) (eq style 'simple))
          (setq indent 0))
      (beginning-of-line)
      (delete-horizontal-space)
      (insert (make-string indent ? ))

      (end-of-line)
      (delete-horizontal-space)

      ;; Set the current column, we're at the end of the title line
      (setq len (+ (current-column) indent))

      ;; Remove previous line if it consists only of a single repeated character
      (save-excursion
        (forward-line -1)
	(and (rest-line-homogeneous-p 1)
	     ;; Avoid removing the underline of a title right above us.
	     (save-excursion (forward-line -1)
			     (not (looking-at rest-section-text-regexp)))
             (rest-delete-line)))

      ;; Remove following line if it consists only of a single repeated
      ;; character
      (save-excursion
        (forward-line +1)
        (and (rest-line-homogeneous-p 1)
             (rest-delete-line))
        ;; Add a newline if we're at the end of the buffer, for the subsequence
        ;; inserting of the underline
        (if (= (point) (buffer-end 1))
            (newline 1)))

      ;; Insert overline
      (if (eq style 'over-and-under)
          (save-excursion
            (beginning-of-line)
            (open-line 1)
            (insert (make-string len char))))

      ;; Insert underline
      (forward-line +1)
      (open-line 1)
      (insert (make-string len char))

      (forward-line +1)
      (goto-char marker)
      ))


(defun rest-normalize-cursor-position ()
  "If the cursor is on a decoration line or an empty line , place
  it on the section title line (at the end).  Returns the line
  offset by which the cursor was moved. This works both over or
  under a line."
  (if (save-excursion (beginning-of-line)
                      (or (rest-line-homogeneous-p 1)
                          (looking-at "^[ \t]*$")))
      (progn
        (beginning-of-line)
        (cond
         ((save-excursion (forward-line -1)
                          (beginning-of-line)
                          (and (looking-at rest-section-text-regexp)
                               (not (rest-line-homogeneous-p 1))))
          (progn (forward-line -1) -1))
         ((save-excursion (forward-line +1)
                          (beginning-of-line)
                          (and (looking-at rest-section-text-regexp)
                               (not (rest-line-homogeneous-p 1))))
          (progn (forward-line +1) +1))
         (t 0)))
    0 ))


(defun rest-find-all-decorations ()
  "Finds all the decorations in the file, and returns a list of
  (line, decoration) pairs.  Each decoration consists in a (char,
  style, indent) triple.

  This function does not detect the hierarchy of decorations, it
  just finds all of them in a file.  You can then invoke another
  function to remove redundancies and inconsistencies."

  (let (positions
        (curline 1))
    ;; Iterate over all the section titles/decorations in the file.
    (save-excursion
      (beginning-of-buffer)
      (while (< (point) (buffer-end 1))
        (if (rest-line-homogeneous-nodent-p)
            (progn
              (setq curline (+ curline (rest-normalize-cursor-position)))

              ;; Here we have found a potential site for a decoration,
              ;; characterize it.
              (let ((deco (rest-get-decoration)))
                (if (cadr deco) ;; Style is existing.
                    ;; Found a real decoration site.
                    (progn
                      (push (cons curline deco) positions)
                      ;; Push beyond the underline.
                      (forward-line 1)
                      (setq curline (+ curline 1))
                      )))
              ))
        (forward-line 1)
        (setq curline (+ curline 1))
        ))
    (reverse positions)))


(defun rest-infer-hierarchy (decorations)
  "Build a hierarchy of decorations using the list of given decorations.

  This function expects a list of (char, style, indent)
  decoration specifications, in order that they appear in a file,
  and will infer a hierarchy of section levels by removing
  decorations that have already been seen in a forward traversal of the
  decorations, comparing just the character and style.

  Similarly returns a list of (char, style, indent), where each
  list element should be unique."

  (let ((hierarchy-alist (list)))
    (dolist (x decorations)
      (let ((char (car x))
            (style (cadr x))
            (indent (caddr x)))
        (if (not (assoc (cons char style) hierarchy-alist))
            (progn
              (setq hierarchy-alist
                    (append hierarchy-alist
                            (list (cons (cons char style) x))))
              ))
        ))
    (mapcar 'cdr hierarchy-alist)
    ))


(defun rest-get-hierarchy (&optional alldecos ignore)
  "Returns a list of decorations that represents the hierarchy of
  section titles in the file.

  If the line number in IGNORE is specified, the decoration found
  on that line (if there is one) is not taken into account when
  building the hierarchy."
  (let ((all (or alldecos (rest-find-all-decorations))))
    (setq all (assq-delete-all ignore all))
    (rest-infer-hierarchy (mapcar 'cdr all))))


(defun rest-get-decoration (&optional point)
  "Looks around point and finds the characteristics of the
  decoration that is found there.  We assume that the cursor is
  already placed on the title line (and not on the overline or
  underline).

  This function returns a (char, style, indent) triple.  If the
  characters of overline and underline are different, we return
  the underline character.  The indent is always calculated.  A
  decoration can be said to exist if the style is not nil.

  A point can be specified to go to the given location before
  extracting the decoration."

  (let (char style indent)
    (save-excursion
      (if point (goto-char point))
      (beginning-of-line)
      (if (looking-at rest-section-text-regexp)
          (let* ((over (save-excursion
			 (forward-line -1)
			 (rest-line-homogeneous-nodent-p)))

		(under (save-excursion
			 (forward-line +1)
			 (rest-line-homogeneous-nodent-p)))
	        )

	    ;; Check that the line above the overline is not part of a title
	    ;; above it.
	    (if (and over
		     (save-excursion
		       (and (equal (forward-line -2) 0)
			    (looking-at rest-section-text-regexp))))
		(setq over nil))

            (cond
             ;; No decoration found, leave all return values nil.
             ((and (eq over nil) (eq under nil)))

             ;; Overline only, leave all return values nil.
             ;;
             ;; Note: we don't return the overline character, but it could perhaps
             ;; in some cases be used to do something.
             ((and over (eq under nil)))

             ;; Underline only.
             ((and under (eq over nil))
              (setq char under
                    style 'simple))

             ;; Both overline and underline.
             (t
              (setq char under
                    style 'over-and-under))
             )
            )
        )
      ;; Find indentation.
      (setq indent (save-excursion (back-to-indentation) (current-column)))
      )
    ;; Return values.
    (list char style indent)))


(defun rest-get-decorations-around (&optional alldecos)
  "Given the list of all decorations (with positions),
find the decorations before and after the given point.
A list of the previous and next decorations is returned."
  (let* ((all (or alldecos (rest-find-all-decorations)))
	 (curline (line-number-at-pos))
	 prev next
	 (cur all))

    ;; Search for the decorations around the current line.
    (while (and cur (< (caar cur) curline))
      (setq prev cur
	    cur (cdr cur)))
    ;; 'cur' is the following decoration.

    (if (and cur (caar cur))
	(setq next (if (= curline (caar cur)) (cdr cur) cur)))

    (mapcar 'cdar (list prev next))
    ))


(defun rest-decoration-complete-p (deco &optional point)
  "Return true if the decoration DECO around POINT is complete."
  ;; Note: we assume that the detection of the overline as being the underline
  ;; of a preceding title has already been detected, and has been eliminated
  ;; from the decoration that is given to us.

  ;; There is some sectioning already present, so check if the current
  ;; sectioning is complete and correct.
  (let* ((char (car deco))
         (style (cadr deco))
         (indent (caddr deco))
         (endcol (save-excursion (end-of-line) (current-column)))
         )
    (if char
        (let ((exps (concat "^"
                            (regexp-quote (make-string (+ endcol indent) char))
                            "$")))
          (and
           (save-excursion (forward-line +1)
                           (beginning-of-line)
                           (looking-at exps))
           (or (not (eq style 'over-and-under))
               (save-excursion (forward-line -1)
                               (beginning-of-line)
                               (looking-at exps))))
          ))
    ))


(defun rest-get-next-decoration
  (curdeco hier &optional suggestion reverse-direction)
  "Get the next decoration for CURDECO, in given hierarchy HIER,
and suggesting for new decoration SUGGESTION."

  (let* (
	 (char (car curdeco))
	 (style (cadr curdeco))

	 ;; Build a new list of decorations for the rotation.
	 (rotdecos
	  (append hier
		  ;; Suggest a new decoration.
		  (list suggestion
			;; If nothing to suggest, use first decoration.
			(car hier)))) )
    (or
     ;; Search for next decoration.
     (cadr
      (let ((cur (if reverse-direction rotdecos
		   (reverse rotdecos)))
	    found)
	(while (and cur
		    (not (and (eq char (caar cur))
			      (eq style (cadar cur)))))
	  (setq cur (cdr cur)))
	cur))

     ;; If not found, take the first of all decorations.
     suggestion
     )))


(defun rest-adjust ()
  "Adjust/rotate the section decoration for the section title
around point or promote/demote the decorations inside the region,
depending on if the region is active.  This function is meant to
be invoked possibly multiple times, and can vary its behaviour
with a positive prefix argument (toggle style), or with a
negative prefix argument (alternate behaviour).

This function is the main focus of this module and is a bit of a
swiss knife.  It is meant as the single most essential function
to be bound to invoke to adjust the decorations of a section
title in restructuredtext.  It tries to deal with all the
possible cases gracefully and to do `the right thing' in all
cases.

See the documentations of rest-adjust-decoration and
rest-promote-region for full details.

Prefix Arguments
================

The method can take either (but not both) of

a. a (non-negative) prefix argument, which means to toggle the
   decoration style.  Invoke with C-u prefix for example;

b. a negative numerical argument, which generally inverts the
   direction of search in the file or hierarchy.  Invoke with C--
   prefix for example.

"
  (interactive)

  (let* ( ;; Parse the positive and negative prefix arguments.
	 (reverse-direction
	  (and current-prefix-arg
	       (< (prefix-numeric-value current-prefix-arg) 0)))
	 (toggle-style
	  (and current-prefix-arg (not reverse-direction))))

    (if (and transient-mark-mode mark-active)
	;; Adjust decorations within region.
	(rest-promote-region current-prefix-arg)
      ;; Adjust decoration around point.
      (rest-adjust-decoration toggle-style reverse-direction))
    
    ;; Run the hooks to run after adjusting.
    (run-hooks 'rest-adjust-hook)

    ))

(defvar rest-adjust-hook nil
  "Hooks to be run after running rest-adjust.")

(defun rest-adjust-decoration (&optional toggle-style reverse-direction)
"Adjust/rotate the section decoration for the section title around point.

This function is meant to be invoked possibly multiple times, and
can vary its behaviour with a true TOGGLE-STYLE argument, or with
a REVERSE-DIRECTION argument.

General Behaviour
=================

The next action it takes depends on context around the point, and
it is meant to be invoked possibly more than once to rotate among
the various possibilities. Basically, this function deals with:

- adding a decoration if the title does not have one;

- adjusting the length of the underline characters to fit a
  modified title;

- rotating the decoration in the set of already existing
  sectioning decorations used in the file;

- switching between simple and over-and-under styles.

You should normally not have to read all the following, just
invoke the method and it will do the most obvious thing that you
would expect.


Decoration Definitions
======================

The decorations consist in

1. a CHARACTER

2. a STYLE which can be either of 'simple' or 'over-and-under'.

3. an INDENT (meaningful for the over-and-under style only)
   which determines how many characters and over-and-under
   style is hanging outside of the title at the beginning and
   ending.

See source code for mode details.


Detailed Behaviour Description
==============================

Here are the gory details of the algorithm (it seems quite
complicated, but really, it does the most obvious thing in all
the particular cases):

Before applying the decoration change, the cursor is placed on
the closest line that could contain a section title.

Case 1: No Decoration
---------------------

If the current line has no decoration around it,

- search backwards for the last previous decoration, and apply
  the decoration one level lower to the current line.  If there
  is no defined level below this previous decoration, we suggest
  the most appropriate of the rest-preferred-decorations.

  If REVERSE-DIRECTION is true, we simply use the previous
  decoration found directly.

- if there is no decoration found in the given direction, we use
  the first of rest-preferred-decorations.

The prefix argument forces a toggle of the prescribed decoration
style.

Case 2: Incomplete Decoration
-----------------------------

If the current line does have an existing decoration, but the
decoration is incomplete, that is, the underline/overline does
not extend to exactly the end of the title line (it is either too
short or too long), we simply extend the length of the
underlines/overlines to fit exactly the section title.

If the prefix argument is given, we toggle the style of the
decoration as well.

REVERSE-DIRECTION has no effect in this case.

Case 3: Complete Existing Decoration
------------------------------------

If the decoration is complete (i.e. the underline (overline)
length is already adjusted to the end of the title line), we
search/parse the file to establish the hierarchy of all the
decorations (making sure not to include the decoration around
point), and we rotate the current title's decoration from within
that list (by default, going *down* the hierarchy that is present
in the file, i.e. to a lower section level).  This is meant to be
used potentially multiple times, until the desired decoration is
found around the title.

If we hit the boundary of the hierarchy, exactly one choice from
the list of preferred decorations is suggested/chosen, the first
of those decoration that has not been seen in the file yet (and
not including the decoration around point), and the next
invocation rolls over to the other end of the hierarchy (i.e. it
cycles).  This allows you to avoid having to set which character
to use by always using the

If REVERSE-DIRECTION is true, the effect is to change the
direction of rotation in the hierarchy of decorations, thus
instead going *up* the hierarchy.

However, if there is a non-negative prefix argument, we do not
rotate the decoration, but instead simply toggle the style of the
current decoration (this should be the most common way to toggle
the style of an existing complete decoration).


Point Location
==============

The invocation of this function can be carried out anywhere
within the section title line, on an existing underline or
overline, as well as on an empty line following a section title.
This is meant to be as convenient as possible.


Indented Sections
=================

Indented section titles such as ::

   My Title
   --------

are illegal in restructuredtext and thus not recognized by the
parser.  This code will thus not work in a way that would support
indented sections (it would be ambiguous anyway).


Joint Sections
==============

Section titles that are right next to each other may not be
treated well.  More work might be needed to support those, and
special conditions on the completeness of existing decorations
might be required to make it non-ambiguous.

For now we assume that the decorations are disjoint, that is,
there is at least a single line between the titles/decoration
lines.


Suggested Binding
=================

We suggest that you bind this function on C-=.  It is close to
C-- so a negative argument can be easily specified with a flick
of the right hand fingers and the binding is unused in text-mode."
  (interactive)

  ;; If we were invoked directly, parse the prefix arguments into the
  ;; arguments of the function.
  (if current-prefix-arg
      (setq reverse-direction
	    (and current-prefix-arg
		 (< (prefix-numeric-value current-prefix-arg) 0))

	    toggle-style
	    (and current-prefix-arg (not reverse-direction))))

  (let* (;; Check if we're on an underline around a section title, and move the
         ;; cursor to the title if this is the case.
         (moved (rest-normalize-cursor-position))

         ;; Find the decoration and completeness around point.
         (curdeco (rest-get-decoration))
         (char (car curdeco))
         (style (cadr curdeco))
         (indent (caddr curdeco))

	 ;; New values to be computed.
	 char-new style-new indent-new
         )

    ;; We've moved the cursor... if we're not looking at some text, we have
    ;; nothing to do.
    (if (save-excursion (beginning-of-line)
                        (looking-at rest-section-text-regexp))
	(progn
	  (cond
	   ;;---------------------------------------------------------------------
	   ;; Case 1: No Decoration
	   ((and (eq char nil) (eq style nil))

	    (let* ((alldecos (rest-find-all-decorations))

		   (around (rest-get-decorations-around alldecos))
		   (prev (car around))
		   cur

		   (hier (rest-get-hierarchy alldecos))
		   )

	      ;; Advance one level down.
	      (setq cur
		    (if prev
			(if (not reverse-direction)
			    (or (cadr (rest-get-decoration-match hier prev))
				(rest-suggest-new-decoration hier prev))
			  prev)
		      (copy-list (car rest-preferred-decorations))
		      ))

	      ;; Invert the style if requested.
	      (if toggle-style
		  (setcar (cdr cur) (if (eq (cadr cur) 'simple)
					'over-and-under 'simple)) )

	      (setq char-new (car cur)
		    style-new (cadr cur)
		    indent-new (caddr cur))
	      ))

	   ;;---------------------------------------------------------------------
	   ;; Case 2: Incomplete Decoration
	   ((not (rest-decoration-complete-p curdeco))

	    ;; Invert the style if requested.
	    (if toggle-style
		(setq style (if (eq style 'simple) 'over-and-under 'simple)))

            (setq char-new char
		  style-new style
		  indent-new indent))

	   ;;---------------------------------------------------------------------
	   ;; Case 3: Complete Existing Decoration
	   (t
	    (if toggle-style

		;; Simply switch the style of the current decoration.
		(setq char-new char
		      style-new (if (eq style 'simple) 'over-and-under 'simple)
		      indent-new rest-default-indent)

	      ;; Else, we rotate, ignoring the decoration around the current
	      ;; line...
	      (let* ((alldecos (rest-find-all-decorations))

		     (hier (rest-get-hierarchy alldecos (line-number-at-pos)))

		     ;; Suggestion, in case we need to come up with something
		     ;; new
		     (suggestion (rest-suggest-new-decoration
				  hier
				  (car (rest-get-decorations-around alldecos))))

		     (nextdeco (rest-get-next-decoration
				curdeco hier suggestion reverse-direction))

		     )

		;; Indent, if present, always overrides the prescribed indent.
		(setq char-new (car nextdeco)
		      style-new (cadr nextdeco)
		      indent-new (caddr nextdeco))

		)))
	   )

	  ;; Override indent with present indent!
	  (setq indent-new (if (> indent 0) indent indent-new))

	  (if (and char-new style-new)
	      (rest-update-section char-new style-new indent-new))
	  ))


    ;; Correct the position of the cursor to more accurately reflect where it
    ;; was located when the function was invoked.
    (if (not (= moved 0))
        (progn (forward-line (- moved))
               (end-of-line)))

    ))

;; Maintain an alias for compatibility.
(defalias 'rest-adjust-section-title 'rest-adjust)


(defun rest-promote-region (&optional demote)
  "Promote the section titles within the region.

With argument DEMOTE or a prefix argument, demote the
section titles instead.  The algorithm used at the boundaries of
the hierarchy is similar to that used by rest-adjust-decoration."
  (interactive)

  (let* ((demote (or current-prefix-arg demote))
	 (alldecos (rest-find-all-decorations))
	 (cur alldecos)

	 (hier (rest-get-hierarchy alldecos))
	 (suggestion (rest-suggest-new-decoration hier))

	 (region-begin-line (line-number-at-pos (region-beginning)))
	 (region-end-line (line-number-at-pos (region-end)))

	 marker-list
	 )

    ;; Skip the markers that come before the region beginning
    (while (and cur (< (caar cur) region-begin-line))
      (setq cur (cdr cur)))

    ;; Create a list of markers for all the decorations which are found within
    ;; the region.
    (save-excursion
      (let (m line)
	(while (and cur (< (setq line (caar cur)) region-end-line))
	  (setq m (make-marker))
	  (goto-line line)
	  (push (list (set-marker m (point)) (cdar cur)) marker-list)
	  (setq cur (cdr cur)) ))

      ;; Apply modifications.
      (let (nextdeco)
	(dolist (p marker-list)
	  ;; Go to the decoration to promote.
	  (goto-char (car p))

	  ;; Rotate the next decoration.
	  (setq nextdeco (rest-get-next-decoration
			  (cadr p) hier suggestion demote))

	  ;; Update the decoration.
	  (apply 'rest-update-section nextdeco)

	  ;; Clear marker to avoid slowing down the editing after we're done.
	  (set-marker (car p) nil)
	  ))
      (setq deactivate-mark nil)
    )))



(defun rest-display-decorations-hierarchy (&optional decorations)
  "Display the current file's section title decorations hierarchy.
  This function expects a list of (char, style, indent) triples."
  (interactive)

  (if (not decorations)
      (setq decorations (rest-get-hierarchy)))
  (with-output-to-temp-buffer "*rest section hierarchy*"
    (let ((level 1))
      (with-current-buffer standard-output
        (dolist (x decorations)
          (insert (format "\nSection Level %d" level))
          (apply 'rest-update-section x)
          (end-of-buffer)
          (insert "\n")
          (incf level)
          ))
    )))


(defun rest-rstrip (str)
  "Strips the whitespace at the end of a string."
  (let ((tmp))
    (string-match "[ \t\n]*\\'" str)
    (substring str 0 (match-beginning 0))
    ))

(defun rest-get-stripped-line ()
  "Returns the line at cursor, stripped from whitespace."
  (re-search-forward "\\S-.*\\S-" (line-end-position))
  (buffer-substring-no-properties (match-beginning 0)
				  (match-end 0)) )


(defcustom rest-toc-indent 2
  "Indentation for table-of-contents display (also used for
  formatting insertion, when numbering is disabled).")


(defun rest-section-tree (alldecos)
  "Returns a pair of a hierarchical tree of the sections titles
in the document, and a reference to the node where the cursor
lives. This can be used to generate a table of contents for the
document.

Each section title consists in a cons of the stripped title
string and a marker to the section in the original text document.

If there are missing section levels, the section titles are
inserted automatically, and are set to nil."

  (let* (thelist
	 (hier (rest-get-hierarchy alldecos))
	 (levels (make-hash-table :test 'equal :size 10))
	 lines)

    (let ((lev 0))
      (dolist (deco hier)
	(puthash deco lev levels)
	(incf lev)))

    ;; Create a list of lines that contains (text, level, marker) for each
    ;; decoration.
    (save-excursion
      (setq lines
	    (mapcar (lambda (deco)
		      (goto-line (car deco))
		      (list (gethash (cdr deco) levels)
			    (rest-get-stripped-line)
			    (let ((m (make-marker)))
			      (beginning-of-line 1)
			      (set-marker m (point)))
			    ))
		    alldecos)))

    (let ((lcontnr (cons nil lines)))
      (rest-section-tree-rec lcontnr -1))))


(defun rest-section-tree-rec (decos lev)
  "Recursive function for the implementation of the section tree
  building. DECOS is a cons cell whose cdr is the remaining list
  of decorations, and we change it as we consume them.  LEV is
  the current level of that node.  This function returns a pair
  of the subtree that was built.  This treats the decos list
  destructively."

  (let ((ndeco (cadr decos))
	node
	children)
    ;; If the next decoration matches our level
    (if (= (car ndeco) lev)
	(progn
	  ;; Pop the next decoration and create the current node with it
	  (setcdr decos (cddr decos))
	  (setq node (cdr ndeco)) ))
      ;; Else we let the node title/marker be unset.

    ;; Build the child nodes
    (while (and (cdr decos) (> (caadr decos) lev))
      (setq children
	    (cons (rest-section-tree-rec decos (1+ lev))
		  children)))

    ;; Return this node with its children.
    (cons node (reverse children))
    ))


(defun rest-toc-insert (&optional pfxarg)
  "Insert a simple text rendering of the table of contents.
By default the top level is ignored if there is only one, because
we assume that the document will have a single title.

If a numeric prefix argument is given,
- if it is zero or generic, include the top level titles;
- otherwise insert the TOC up to the specified level.

The TOC is inserted indented at the current column."

  (interactive "P")

  (let* (;; Check maximum level override
	 (rest-toc-insert-max-level
	  (if (and (integerp pfxarg) (> (prefix-numeric-value pfxarg) 0))
	      (prefix-numeric-value pfxarg) rest-toc-insert-max-level))

	 ;; Get the section tree.
	 (sectree (rest-section-tree (rest-find-all-decorations)))

	 ;; If there is only one top-level title, remove it by starting to print
	 ;; one index lower (revert this behaviour with the prefix arg),
	 ;; otherwise print all.
	 (gen-pfx-arg (or (and pfxarg (listp pfxarg))
			  (and (integerp pfxarg)
			       (= (prefix-numeric-value pfxarg) 0))))
	 (start-lev (if (and (not rest-toc-insert-always-include-top)
			     (= (length (cdr sectree)) 1)
			     (not gen-pfx-arg))  -1 0))

	 ;; Figure out initial indent.
	 (initial-indent (make-string (current-column) ? ))
	 (init-point (point)))

    (rest-toc-insert-node sectree start-lev initial-indent "")

    ;; Fixup for the first line.
    (delete-region init-point (+ init-point (length initial-indent)))
    
    ;; Delete the last newline added.
    (delete-backward-char 1)
    ))


(defcustom rest-toc-insert-always-include-top nil
  "Set this to 't if you want to always include top-level titles,
  even when there is only one.")

(defcustom rest-toc-insert-style 'fixed
  "Set this to one of the following values to determine numbering and
indentation style:
- plain: no numbering (fixed indentation)
- fixed: numbering, but fixed indentation
- aligned: numbering, titles aligned under each other
- listed: numbering, with dashes like list items (EXPERIMENTAL)
")

(defcustom rest-toc-insert-number-separator "  "
  "Separator that goes between the TOC number and the title.")

;; This is used to avoid having to change the user's mode.
(defvar rest-toc-insert-click-keymap
  (let ((map (make-sparse-keymap)))
       (define-key map [mouse-1] 'rest-toc-mode-mouse-goto)
       map)
  "(Internal) What happens when you click on propertized text in the TOC.")

(defcustom rest-toc-insert-max-level nil
  "If non-nil, maximum depth of the inserted TOC.")

(defun rest-toc-insert-node (node level indent pfx)
  "Recursive function that does the print of the inserted
toc. PFX is the prefix numbering, that includes the alignment
necessary for all the children of this level to align."
  (let ((do-print (> level 0))
	(count 1)
	b)
    (if do-print
	(progn
	  (insert indent)
	  (let ((b (point)))
	    (if (not (equal rest-toc-insert-style 'plain))
		(insert pfx rest-toc-insert-number-separator))
	    (insert (or (caar node) "[missing node]"))
	    ;; Add properties to the text, even though in normal text mode it
	    ;; won't be doing anything for now.  Not sure that I want to change
	    ;; mode stuff.  At least the highlighting gives the idea that this
	    ;; is generated automatically.
	    (put-text-property b (point) 'mouse-face 'highlight)
	    (put-text-property b (point) 'rest-toc-target (cadar node))
	    (put-text-property b (point) 'keymap rest-toc-insert-click-keymap)

	    )
	  (insert "\n")

	  ;; Prepare indent for children.
	  (setq indent
		(cond
		 ((eq rest-toc-insert-style 'plain)
		  (concat indent rest-toc-indent))

		 ((eq rest-toc-insert-style 'fixed)
		  (concat indent (make-string rest-toc-indent ? )))

		 ((eq rest-toc-insert-style 'aligned)
		  (concat indent (make-string (+ (length pfx) 2) ? )))

		 ((eq rest-toc-insert-style 'listed)
		  (concat (substring indent 0 -3)
			  (concat (make-string (+ (length pfx) 2) ? ) " - ")))
		 ))

	  ))

    (if (or (eq rest-toc-insert-max-level nil)
	    (< level rest-toc-insert-max-level))
	(let ((do-child-numbering (>= level 0))
	      fmt)
	  (if do-child-numbering
	      (progn
		;; Add a separating dot if there is already a prefix
		(if (> (length pfx) 0)
		    (setq pfx (concat (rest-rstrip pfx) ".")))

		;; Calculate the amount of space that the prefix will require for
		;; the numbers.
		(if (cdr node)
		    (setq fmt (format "%%-%dd"
				      (1+ (floor (log10 (length (cdr node))))))))
		))

	  (dolist (child (cdr node))
	    (rest-toc-insert-node child
				  (1+ level)
				  indent
				  (if do-child-numbering
				      (concat pfx (format fmt count)) pfx))
	    (incf count)))

      )))


(defun rest-toc-insert-find-delete-contents ()
  "Finds and deletes an existing comment after the first contents directive and
delete that region. Return t if found and the cursor is left after the comment."
  (goto-char (point-min))
  ;; We look for the following and the following only (in other words, if your
  ;; syntax differs, this won't work.  If you would like a more flexible thing,
  ;; contact the author, I just can't imagine that this requirement is
  ;; unreasonable for now).
  ;;
  ;;   .. contents:: [...anything here...]
  ;;   ..
  ;;      XXXXXXXX
  ;;      XXXXXXXX
  ;;      [more lines]
  ;;
  (let ((beg
	 (re-search-forward "^\\.\\. contents[ \t]*::\\(.*\\)\n\\.\\."
			    nil t))
	last-real)
    (when beg
      ;; Look for the first line that starts at the first column.
      (forward-line 1)
      (beginning-of-line)
      (while (or (and (looking-at "[ \t]+[^ \t]")
		      (setq last-real (point)) t)
		 (looking-at "\\s-*$"))
	(forward-line 1)
	)
      (if last-real
	  (progn
	    (goto-char last-real)
	    (end-of-line)
	    (delete-region beg (point)))
	(goto-char beg))
      t
      )))
  
(defun rest-toc-insert-update ()
  "Automatically find the .. contents:: section of a document and update the
inserted TOC if present.  You can use this in your file-write hook to always
make it up-to-date automatically."
  (interactive)
  (save-excursion
    (if (rest-toc-insert-find-delete-contents)
	(progn (insert "\n    ")
	       (rest-toc-insert))) )
  ;; Note: always return nil, because this may be used as a hook.
  )


;;------------------------------------------------------------------------------

(defun rest-toc-node (node level)
  "Recursive function that does the print of the TOC in rest-toc-mode."

  (if (> level 0)
      (let ((b (point)))
	;; Insert line text.
	(insert (make-string (* rest-toc-indent (1- level)) ? ))
	(insert (if (car node) (caar node) "[missing node]"))

	;; Highlight lines.
	(put-text-property b (point) 'mouse-face 'highlight)

	;; Add link on lines.
	(put-text-property b (point) 'rest-toc-target (cadar node))

	(insert "\n")))

  (dolist (child (cdr node))
    (rest-toc-node child (1+ level))))


(defun rest-toc ()
  "Finds all the section titles and their decorations in the
  file, and displays a hierarchically-organized list of the
  titles, which is essentially a table-of-contents of the
  document.

  The emacs buffer can be navigated, and selecting a section
  brings the cursor in that section."
  (interactive)
  (let* ((curbuf (current-buffer))
	 outline

	 ;; Get the section tree
	 (alldecos (rest-find-all-decorations))
	 (sectree (rest-section-tree alldecos))

	 ;; Create a temporary buffer.
	 (buf (get-buffer-create rest-toc-buffer-name))
	 )

    ;; Find the index of the section where the cursor currently is.
    (setq outline (let ((idx 1)
			(curline (line-number-at-pos (point)))
			(decos alldecos))
		    (while (and decos (<= (caar decos) curline))
		      (setq decos (cdr decos))
		      (incf idx))
		    idx))
    ;; FIXME: if there is a missing node inserted, the calculation of the
    ;; current line will be off. You need to fix this by moving the finding of
    ;; the current line somewhere else.


    (with-current-buffer buf
      (let ((inhibit-read-only t))
	(rest-toc-mode)
	(delete-region (point-min) (point-max))
	(insert (format "Table of Contents: %s\n" (or (caar sectree) "")))
	(put-text-property (point-min) (point)
			   'face (list '(background-color . "lightgray")))
	(rest-toc-node sectree 0)
	))
    (display-buffer buf)
    (pop-to-buffer buf)

    ;; Save the buffer to return to.
    (set (make-local-variable 'rest-toc-return-buffer) curbuf)

    ;; Move the cursor near the right section in the TOC.
    (goto-line outline)
    ))


(defun rest-toc-mode-find-section ()
  (let ((pos (get-text-property (point) 'rest-toc-target)))
    (unless pos
      (error "No section on this line"))
    (unless (buffer-live-p (marker-buffer pos))
      (error "Buffer for this section was killed"))
    pos))

(defvar rest-toc-buffer-name "*Table of Contents*"
  "Name of the Table of Contents buffer.")

(defun rest-toc-mode-goto-section ()
  "Go to the section the current line describes."
  (interactive)
  (let ((pos (rest-toc-mode-find-section)))
    (kill-buffer (get-buffer rest-toc-buffer-name))
    (pop-to-buffer (marker-buffer pos))
    (goto-char pos)
    (recenter 5)))

(defun rest-toc-mode-mouse-goto (event)
  "In Rest-Toc mode, go to the occurrence whose line you click on."
  (interactive "e")
  (let (pos)
    (save-excursion
      (set-buffer (window-buffer (posn-window (event-end event))))
      (save-excursion
	(goto-char (posn-point (event-end event)))
	(setq pos (rest-toc-mode-find-section))))
    (pop-to-buffer (marker-buffer pos))
    (goto-char pos)))

(defun rest-toc-mode-mouse-goto-kill (event)
  (interactive "e")
  (call-interactively 'rest-toc-mode-mouse-goto event)
  (kill-buffer (get-buffer rest-toc-buffer-name)))

(defvar rest-toc-return-buffer nil
  "Buffer local variable that is used to return to the original
  buffer from the TOC.")

(defun rest-toc-quit-window ()
  (interactive)
  (quit-window)
  (pop-to-buffer rest-toc-return-buffer))

(defvar rest-toc-mode-map
  (let ((map (make-sparse-keymap)))
    (define-key map [mouse-1] 'rest-toc-mode-mouse-goto-kill)
    (define-key map [mouse-2] 'rest-toc-mode-mouse-goto)
    (define-key map "\C-m" 'rest-toc-mode-goto-section)
    (define-key map "f" 'rest-toc-mode-goto-section)
    (define-key map "q" 'rest-toc-quit-window)
    (define-key map "z" 'kill-this-buffer)
    map)
  "Keymap for `rest-toc-mode'.")

(put 'rest-toc-mode 'mode-class 'special)

(defun rest-toc-mode ()
  "Major mode for output from \\[rest-toc]."
  (interactive)
  (kill-all-local-variables)
  (use-local-map rest-toc-mode-map)
  (setq major-mode 'rest-toc-mode)
  (setq mode-name "Rest-TOC")
  (setq buffer-read-only t)
  )

;; Note: use occur-mode (replace.el) as a good example to complete missing
;; features.


;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;
;; Section movement commands.
;;

(defun rest-forward-section (&optional offset)
  "Skip to the next restructured text section title.
  OFFSET specifies how many titles to skip.  Use a negative OFFSET to move
  backwards in the file (default is to use 1)."
  (interactive)
  (let* (;; Default value for offset.
	 (offset (or offset 1))

	 ;; Get all the decorations in the file, with their line numbers.
	 (alldecos (rest-find-all-decorations))

	 ;; Get the current line.
	 (curline (line-number-at-pos))

	 (cur alldecos)
	 (idx 0)
	 line
	 )

    ;; Find the index of the "next" decoration w.r.t. to the current line.
    (while (and cur (< (caar cur) curline))
      (setq cur (cdr cur))
      (incf idx))
    ;; 'cur' is the decoration on or following the current line.

    (if (and (> offset 0) cur (= (caar cur) curline))
  	(incf idx))

    ;; Find the final index.
    (setq idx (+ idx (if (> offset 0) (- offset 1) offset)))
    (setq cur (nth idx alldecos))

    ;; If the index is positive, goto the line, otherwise go to the buffer
    ;; boundaries.
    (if (and cur (>= idx 0))
	(goto-line (car cur))
      (if (> offset 0) (end-of-buffer) (beginning-of-buffer)))
    ))

(defun rest-backward-section ()
  "Like rest-forward-section, except move back one title."
  (interactive)
  (rest-forward-section -1))








;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;
;; Generic text functions that are more convenient than the defaults.
;;

(defun replace-lines (fromchar tochar)
  "Replace flush-left lines, consisting of multiple FROMCHAR characters,
with equal-length lines of TOCHAR."
  (interactive "\
cSearch for flush-left lines of char:
cand replace with char: ")
  (save-excursion
    (let* ((fromstr (string fromchar))
           (searchre (concat "^" (regexp-quote fromstr) "+ *$"))
           (found 0))
      (condition-case err
          (while t
            (search-forward-regexp searchre)
            (setq found (1+ found))
            (search-backward fromstr)  ;; point will be *before* last char
            (setq p (1+ (point)))
            (beginning-of-line)
            (setq l (- p (point)))
            (rest-delete-line)
            (insert-char tochar l))
        (search-failed
         (message (format "%d lines replaced." found)))))))

(defun join-paragraph ()
  "Join lines in current paragraph into one line, removing end-of-lines."
  (interactive)
  (let ((fill-column 65000)) ; some big number
    (call-interactively 'fill-paragraph)))

(defun force-fill-paragraph ()
  "Fill paragraph at point, first joining the paragraph's lines into one.
This is useful for filling list item paragraphs."
  (interactive)
  (join-paragraph)
  (fill-paragraph nil))



;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;
;; Generic character repeater function.
;;
;; For sections, better to use the specialized function above, but this can
;; be useful for creating separators.

(defun repeat-last-character (&optional tofill)
  "Fills the current line up to the length of the preceding line (if not
empty), using the last character on the current line.  If the preceding line is
empty, we use the fill-column.

If a prefix argument is provided, use the next line rather than the preceding
line.

If the current line is longer than the desired length, shave the characters off
the current line to fit the desired length.

As an added convenience, if the command is repeated immediately, the alternative
column is used (fill-column vs. end of previous/next line)."
  (interactive)
  (let* ((curcol (current-column))
         (curline (+ (count-lines (point-min) (point))
                     (if (eq curcol 0) 1 0)))
         (lbp (line-beginning-position 0))
         (prevcol (if (and (= curline 1) (not current-prefix-arg))
                      fill-column
                    (save-excursion
                      (forward-line (if current-prefix-arg 1 -1))
                      (end-of-line)
                      (skip-chars-backward " \t" lbp)
                      (let ((cc (current-column)))
                        (if (= cc 0) fill-column cc)))))
         (rightmost-column
          (cond (tofill fill-column)
                ((equal last-command 'repeat-last-character)
                 (if (= curcol fill-column) prevcol fill-column))
                (t (save-excursion
                     (if (= prevcol 0) fill-column prevcol)))
                )) )
    (end-of-line)
    (if (> (current-column) rightmost-column)
        ;; shave characters off the end
        (delete-region (- (point)
                          (- (current-column) rightmost-column))
                       (point))
      ;; fill with last characters
      (insert-char (preceding-char)
                   (- rightmost-column (current-column))))
    ))


(provide 'restructuredtext)
