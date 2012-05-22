wget.callbacks.init = function()
end

wget.callbacks.get_urls = function(file, url, is_css, iri)
  user = string.match(url, "http://www.tabblo.com/studio/person/([^/]+)$")
  if user then
    return {
      { url="http://www.tabblo.com/studio/view/tabblos/"..user.."/",
        link_expect_html=1, link_expect_css=0 },
      { url="http://www.tabblo.com/studio/view/favorites/"..user,
        link_expect_html=1, link_expect_css=0 },
      { url="http://www.tabblo.com/studio/photos/"..user.."/",
        link_expect_html=1, link_expect_css=0 }
    }
  end

  user = string.match(url, "http://www.tabblo.com/studio/view/tabblos/([^/]+)/[0-9]*$")
  if user then
    urls = {}
    for line in io.lines(file) do
      more = string.match(line, "/studio/view/tabblos/"..user.."/([0-9]+)\"")
      if more then
        table.insert(urls, 
          { url="http://www.tabblo.com/studio/view/tabblos/"..user.."/"..more,
            link_expect_html=1, link_expect_css=0 }
        )
      end
      id = string.match(line, "/studio/stories/view/([0-9]+)/")
      if id then
        table.insert(urls, 
          { url="http://www.tabblo.com/studio/stories/view/"..id.."/",
            link_expect_html=1, link_expect_css=0 }
        )
      end
    end
    return urls
  end

  user = string.match(url, "http://www.tabblo.com/studio/photos/([^/]+)/$")
  if user then
    for line in io.lines(file) do
      more = string.match(line, "var totalPages = ([0-9]+);")
      if more then
        urls = {}
        local i = tonumber(more)
        while i > 0 do
          table.insert(urls, 
            { url="http://www.tabblo.com/studio/photos/"..user.."/"..i,
              link_expect_html=1, link_expect_css=0 }
          )
          i = i - 1
        end
        return urls
      end
    end
  end

  user = string.match(url, "http://www.tabblo.com/studio/photos/([^/]+)/[0-9]+$")
  if user then
    urls = {}
    for line in io.lines(file) do
      id = string.match(line, "photo_id=\"([0-9]+)\"")
      if id then
        table.insert(urls, 
          { url="http://www.tabblo.com/studio/item/"..id,
            link_expect_html=1, link_expect_css=0 }
        )
      end
    end
    return urls
  end

  return {}
end


