atom_feed do |feed|
  feed.title(@title)
  feed.updated(@updated)
  @campaigns.each do |campaign|
    feed.entry(campaign) do |entry|
      entry.title(h(campaign.title))
      entry.content(strip_tags(campaign.description))
      entry.author do |author|
        author.name(campaign.initiator.name)
      end
    end
  end
end
