require 'nokogiri'

module Preprocess
  def preprocess_text(text)
    text = safe_encode(text)

    #remove markdown url tags
    text = text.gsub(/\[.+?\]\(.+?\)/, ' ')

    #remove spam words
    text.gsub!(/\bTHE\b/i, '')

    #remove some XML grabage
    text = text.gsub(/\<\!\[CDATA.*?\]\]\>/, ' ').to_s
    text = text.gsub(/\<\!--.+?--\>/,  ' ').to_s
    text = text.gsub(/<\!\[CDATA.+?\]>/, ' ').to_s

    return text.to_s.strip.gsub(/\s+/, ' ')
  end

  def preprocess_html(html_text)
    # if text is HTML doc, then
    # extract text only from visible html tags
    text = ""

    html_doc = parse_html(html_text)
    if html_doc
      text = clean_html(html_doc)
    else
      p "match_html: failed to parse html document\n#{html_text}"
    end

    return text
  end

  def clean_html(html_doc)
    body_text = ""
    body_elements = html_doc.xpath(
      '//p | //h1 | //h2 | //h3 | //h4 | //h5 | //h6 | //em | //strong | //b | //td | //pre
      | //li[not(@id) and not(@class) and not(a)] | //section//section[@class="project-info"]
      | //blockquote | //textarea'
    ).to_a

    #extract text from html tag and separate them by space
    body_elements.each {|el| body_text += ' ' + el.text.to_s}

    #REMOVE XML CDATA like opensource.org pages has
    body_text = body_text.to_s.strip
    body_text.gsub!(/\<\!\[CDATA.+?\]\]\>/i, ' ')

    if body_text.empty?
      p "match_html: document didnt pass noise filter, will use whole body content"
      body_text = html_doc.xpath('//body').text.to_s.strip
    end

    return body_text
  end

  def parse_html(html_text)
    begin
      return Nokogiri.HTML(safe_encode(html_text))
    rescue Exception => e
      log.error "failed to parse html doc: \n #{html_text}"
      return nil
    end
  end

  def safe_encode(txt)
    txt.to_s.encode('UTF-8', 'binary', invalid: :replace, undef: :replace, replace: '')
  rescue
    p "Failed to encode text:\n #{txt}i"
    return ""
  end

end