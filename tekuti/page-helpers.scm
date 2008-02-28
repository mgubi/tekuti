;; Tekuti
;; Copyright (C) 2008 Andy Wingo <wingo at pobox dot com>

;; This program is free software; you can redistribute it and/or    
;; modify it under the terms of the GNU General Public License as   
;; published by the Free Software Foundation; either version 3 of   
;; the License, or (at your option) any later version.              
;;                                                                  
;; This program is distributed in the hope that it will be useful,  
;; but WITHOUT ANY WARRANTY; without even the implied warranty of   
;; MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the    
;; GNU General Public License for more details.                     
;;                                                                  
;; You should have received a copy of the GNU General Public License
;; along with this program; if not, contact:
;;
;; Free Software Foundation           Voice:  +1-617-542-5942
;; 59 Temple Place - Suite 330        Fax:    +1-617-542-2652
;; Boston, MA  02111-1307,  USA       gnu@gnu.org

;;; Commentary:
;;
;; Helper bits, mostly verbose-like SXML stuff.
;;
;;; Code:

(define-module (tekuti page-helpers)
  #:use-module (tekuti config)
  #:use-module (tekuti util)
  #:use-module (tekuti git)
  #:use-module (tekuti post)
  #:use-module (tekuti comment)
  #:use-module (tekuti url)
  #:use-module (tekuti request)
  #:use-module (srfi srfi-19)
  #:use-module (scheme kwargs)
  #:export (relurl rellink
            published-posts
            post-editing-form
            sidebar-ul main-sidebar tag-cloud
            post-link admin-post-link
            show-post
            atom-header atom-entry))

(define (relurl path)
  (string-append *public-url-base* path))

(define (rellink path . body)
  `(a (@ (href ,(relurl path)))
      ,@body))

(define (published-posts index n)
  (filter-mapn (lambda (post)
                 (and (post-published? post) post))
               (assq-ref index 'posts)
               n))

(define (post-editing-form post)
  `(form (@ (method "POST")
            (action ,(relurl (if post
                                 (string-append "admin/modify-post/"
                                                (url:encode (assq-ref post 'key)))
                                 "admin/new-post"))))
         (p "title: "
            (input (@ (name "title") (type "text")
                      (value ,(if post (post-title post) "")))))
         (div (textarea (@ (name "body") (rows "20") (cols "80"))
                        ,(if post (post-raw-content post) "")))
         (input (@ (type "submit")
                   (value ,(if post "edit post" "new post"))))))

(define (sidebar-ul body)
  `(div (@ (id "menu"))
        (ul ,@body)))

;; double-encoding is a hack to trick apache
(define (admin-post-link post)
  (rellink (string-append "admin/posts/"
                         (url:encode (post-key post)))
           (assq-ref post 'title)))

(define (post-link post)
  (rellink (string-append "archives/" (url:decode (post-key post)))
           (assq-ref post 'title)))

(define (show-post post comments?)
  `((h2 (@ (class "storytitle"))
        ,(post-link post))
    (div (@ (class "post"))
         (h3 (@ (class "meta"))
             ,(post-readable-date post)
             " (" ,@(list-intersperse (post-tag-links post)
                                      " | ")
             ")")
         (div (@ (class "storycontent"))
              ,(post-sxml-content post))
         ,@(if comments? '()
               (list (post-sxml-n-comments post))))
    ,@(if comments?
          (list (post-sxml-comments post))
          '())))

;; fixme: borks in the no-tags case
(define (tag-cloud index)
  (define (determine-sizes counts)
    (let ((maxcount (apply max counts)))
      (map (lambda (x)
             (floor (+ 80 (* 120 (/ x maxcount)))))
           counts)))
  (let* ((hash (assq-ref index 'tags))
         (cats (if hash
                   (hash-fold (lambda (k v seed) (acons k (length v) seed))
                              '() hash)
                   '()))
         (top-20 (dsu-sort (take-max (dsu-sort cats cdr >) 20)
                           car string<?)))
    `(ul (li (@ (style "line-height: 150%"))
             ,@(list-intersperse
                (map (lambda (name size)
                       `(a (@ (href ,(string-append
                                      *public-url-base* "tags/"
                                      (url:encode name)))
                              (rel "tag")
                              (style ,(format #f "font-size: ~d%" size)))
                           ,name))
                     (map car top-20)
                     (determine-sizes (map cdr top-20)))
                " "))
         )))

(define (main-sidebar request index)
  (sidebar-ul
   `((li (h2 (a (@ (href ,(relurl "feed/atom")))
                "subscribe "
                (img (@ (src ,(relurl "wp-content/feed-icon-14x14.png"))
                        (alt "subscribe to this feed")))
                )))
     (li (h2 "tags "
             (a (@ (href ,(string-append *public-url-base* "tags/")))
                ">>"))
         ,(tag-cloud index)))))

(define (atom-header server-name last-modified)
  (define (relurl tail)
    (string-append "http://" server-name *public-url-base* tail))
  `(feed
     (@ (xmlns "http://www.w3.org/2005/Atom")
        (xml:base ,(relurl "feed/atom")))
     (title (@ (type "text")) ,*title*)
     (subtitle (@ (type "text")) ,*subtitle*)
     (updated ,(timestamp->atom-date last-modified))
     (generator (@ (uri "http://wingolog.org/software/tekuti")
                   (version "what"))
                "tekuti")
     (link (@ (rel "alternate") (type "text/html")
              (href ,(relurl ""))))
     (id ,(relurl "feed/atom"))
     (link (@ (rel "self") (type "application/atom+xml")
              (href ,(relurl "feed/atom"))))))

(define (atom-entry server-name post)
  (define (relurl tail)
    (string-append "http://" server-name *public-url-base* tail))
  `(entry
    (author (name ,*name*) (uri ,(relurl "")))
    (title (@ (type "text")) ,(post-title post))
    (id ,(relurl (url:decode (post-key post)))) ;hack
    (published ,(timestamp->atom-date (post-timestamp post)))
    (updated ,(timestamp->atom-date (post-timestamp post)))
    (content (@ (type "xhtml"))
             (div (@ (xmlns "http://www.w3.org/1999/xhtml"))
                  ,(post-sxml-content post)))))
