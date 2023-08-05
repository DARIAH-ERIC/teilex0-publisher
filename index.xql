xquery version "3.1";

module namespace idx="http://teipublisher.com/index";

declare namespace tei="http://www.tei-c.org/ns/1.0";
declare namespace dbk="http://docbook.org/ns/docbook";

declare variable $idx:app-root :=
    let $rawPath := system:get-module-load-path()
    return
        (: strip the xmldb: part :)
        if (starts-with($rawPath, "xmldb:exist://")) then
            if (starts-with($rawPath, "xmldb:exist://embedded-eXist-server")) then
                substring($rawPath, 36)
            else
                substring($rawPath, 15)
        else
            $rawPath
    ;

(:~
 : Helper function called from collection.xconf to create index fields and facets.
 : This module needs to be loaded before collection.xconf starts indexing documents
 : and therefore should reside in the root of the app.
 :)
declare function idx:get-metadata($root as element(), $field as xs:string) {
    let $header := $root/tei:teiHeader
    return
        switch ($field)
            case "title" return
                string-join((
                    $header//tei:msDesc/tei:head, $header//tei:titleStmt/tei:title[@type = 'main'],
                    $header//tei:titleStmt/tei:title,
                    $root/dbk:info/dbk:title,
                    root($root)//article-meta/title-group/article-title,
                    root($root)//article-meta/title-group/subtitle
                ), " - ")
            case "author" return (
                $header//tei:correspDesc/tei:correspAction/tei:persName,
                $header//tei:titleStmt/tei:author,
                $root/dbk:info/dbk:author,
                root($root)//article-meta/contrib-group/contrib/name
            )
            case "language" return
                head((
                    $header//tei:langUsage/tei:language/@ident,
                    $root/@xml:lang,
                    $header/@xml:lang,
                    root($root)/*/@xml:lang
                ))
            case "date" return head((
                $header//tei:correspDesc/tei:correspAction/tei:date/@when,
                $header//tei:sourceDesc/(tei:bibl|tei:biblFull)/tei:publicationStmt/tei:date,
                $header//tei:sourceDesc/(tei:bibl|tei:biblFull)/tei:date/@when,
                $header//tei:fileDesc/tei:editionStmt/tei:edition/tei:date,
                $header//tei:publicationStmt/tei:date
            ))
            case "genre" return (
                idx:get-genre($header),
                root($root)//dbk:info/dbk:keywordset[@vocab="#genre"]/dbk:keyword,
                root($root)//article-meta/kwd-group[@kwd-group-type="genre"]/kwd
            )
            case "feature" return (
                idx:get-classification($header, 'feature'),
                $root/dbk:info/dbk:keywordset[@vocab="#feature"]/dbk:keyword
            )
            case "form" return (
                idx:get-classification($header, 'form'),
                $root/dbk:info/dbk:keywordset[@vocab="#form"]/dbk:keyword
            )
            case "period" return (
                idx:get-classification($header, 'period'),
                $root/dbk:info/dbk:keywordset[@vocab="#period"]/dbk:keyword
            )
            case "content" return (
                root($root)//body,
                $root/dbk:section
            )
            case "sortKey-realisation"                    return if($root/@sortKey) 
                                                            then $root/@sortKey 
                                                          else $root//tei:form[@type=('lemma', 'variant')][1]/tei:orth[1]
            case "head[@type=letter]-content"             return $root/ancestor-or-self::tei:div[@type='letter']/tei:head[@type='letter']
            case "chapter[@xml:id]-value"                 return $root/ancestor-or-self::tei:div[1]/@xml:id
            case "div[@type=letter]/@n-content"           return $root/ancestor-or-self::tei:div[@type='letter']/@n
            case "form[@type=lemma]-content"              return $root//tei:form[@type=('lemma')]/tei:orth
            case "def-content"                            return $root//tei:sense//tei:def
            case "cit[@type=example]-content"             return $root//tei:sense//tei:cit[@type='example']/tei:quote
            case "gram[@type=pos]-realisation"            return idx:get-pos($root)
            case "title[@type=main]-content"              return string-join((
                                                               $header//tei:msDesc/tei:head, $header//tei:titleStmt/tei:title[@type = 'main'],
                                                               $header//tei:titleStmt/tei:title), " - ")
            case "gram[@type=pos]-content"                return idx:get-pos($root)
            case "orth[xml:lang]-content"                 return idx:get-object-language($root)
            case "polysemy"                               return count($root//tei:sense)
            case "gloss-content"                          return $root//tei:gloss
            case "entry[@type]-realisation"               return $root/@type
            case "usg[@type=attitude]-realisation"        return $root//tei:usg[@type='attitude']
            case "usg[@type=domain]-realisation"          return $root//tei:usg[@type='domain']
            case "usg[@type=frequency]-realisation"       return $root//tei:usg[@type='frequency']
            case "usg[@type=geographic]-realisation"      return $root//tei:usg[@type='geographic']
            case "usg[@type=hint]-realisation"            return $root//tei:usg[@type='hint'] | $root/tei:usg[not(@type)]
            case "usg[@type=meaningType]-realisation"     return $root//tei:usg[@type='meaningType']
            case "usg[@type=normativity]-realisation"     return $root/tei:usg[@type='normativity']
            case "usg[@type=socioCultural]-realisation"   return $root//tei:usg[@type='socioCultural']
            case "usg[@type=textType]-realisation"        return $root//tei:usg[@type='textType']
            case "usg[@type=time]-realisation"            return $root//tei:usg[@type='time']
            case "bibl[@type=attestation]-realisation"    return idx:get-attestation-bibl($root) 
            case "bibl[@type=attestation]/author-content" return $root//tei:bibl[@type='attestation']/tei:author
            case "bibl[@type=attestation]/title-content"  return $root//tei:bibl[@type='attestation']/tei:title
            case "metamark[@function]-value"              return $root//tei:metamark/@function
            default return
                ()
};

declare function idx:get-genre($header as element()?) {
    for $target in $header//tei:textClass/tei:catRef[@scheme="#genre"]/@target
    let $category := id(substring($target, 2), doc($idx:app-root || "/data/taxonomy.xml"))
    return
        $category/ancestor-or-self::tei:category[parent::tei:category]/tei:catDesc
};

declare function idx:get-classification($header as element()?, $scheme as xs:string) {
    for $target in $header//tei:textClass/tei:catRef[@scheme="#" || $scheme]/@target
    let $category := id(substring($target, 2), doc($idx:app-root || "/data/taxonomy.xml"))
    return
        $category/ancestor-or-self::tei:category[parent::tei:category]/tei:catDesc
};

(: 
    Returns values of all part-of-speech classifications in the entry. 
    Returns both values, normalized (in @norm attribute) 
    and shortened (content of the element), if available.
:)
declare function idx:get-pos($entry as element()?) {
  for $item in $entry//tei:gram[@type='pos'] return ($item/@norm/data(), $item/data())
};

(: 
    Returns value of the @xml:attribute of all tei:orth elements in the entry.
:)
declare function idx:get-object-language($entry as element()?) {
    for $target in $entry//tei:form[@type=('lemma', 'variant')]/tei:orth[@xml:lang]
    let $category := $target/@xml:lang
    return
        $category
};


(: 
    Returns the content of tei:title, or tei:author element or concatenation of them
    if both of them are available.
:)
declare function idx:get-attestation-bibl($entry as element()?) {
  for $bibl in $entry//tei:bibl[@type='attestation'] 
  return
   if(not($bibl/tei:author)) then $bibl/tei:title
   else if(not($bibl/tei:title)) then $bibl/tei:author
   else concat($bibl/tei:author, ', ', $bibl/tei:title)
};