#!/usr/bin/env ruby
# frozen_string_literal: true

require "scraperwiki"
require "mechanize"
require "date"

class Scraper
  INITIAL_PAGE_URL = "https://my.armadale.wa.gov.au/service/planning-and-building/planning/advertised-planning-applications-out-for-comment/"
  STATE = "WA"

  def clean_whitespace(text)
    text.gsub("\r", " ").gsub("\n", " ").squeeze(" ").strip
  end

  attr_accessor :pause_duration

  def throttle_block(extra_delay: 0.5)
    if @pause_duration
      puts "  Pausing #{@pause_duration}s" if ENV["DEBUG"]
      sleep(@pause_duration)
    end
    start_time = Time.now.to_f
    page = yield
    @pause_duration = (Time.now.to_f - start_time + extra_delay).round(3)
    page
  end

  def cleanup_old_records
    cutoff_date = (Date.today - 30).to_s
    vacuum_cutoff_date = (Date.today - 35).to_s

    stats = ScraperWiki.sqliteexecute(
      "SELECT COUNT(*) as count, MIN(date_scraped) as oldest FROM data WHERE date_scraped < ?",
      [cutoff_date]
    ).first

    deleted_count = stats["count"]
    oldest_date = stats["oldest"]

    return unless deleted_count.positive? || ENV["VACUUM"]

    puts "Deleting #{deleted_count} applications scraped between #{oldest_date} and #{cutoff_date}"
    ScraperWiki.sqliteexecute("DELETE FROM data WHERE date_scraped < ?", [cutoff_date])

    return unless rand < 0.03 || (oldest_date && oldest_date < vacuum_cutoff_date) || ENV["VACUUM"]

    puts "  Running VACUUM to reclaim space..."
    ScraperWiki.sqliteexecute("VACUUM")
  end

  def generate_council_reference(url)
    sanitized = url.sub(%r{/*\z}, "").sub(%r{\A.*/}, "")

    if sanitized.length > 50
      "#{sanitized[0..48]}-"
    else
      sanitized
    end
  end

  def parse_notice_date(text)
    # "Open for comments until Thu, 29 January 2026 - 4:00 pm"
    match = text.match(/until\s+\w+,\s+(\d+\s+\w+\s+\d{4})/)
    return nil unless match

    Date.parse(match[1]).to_s
  rescue StandardError
    nil
  end

  def run
    agent = Mechanize.new
    agent.verify_mode = OpenSSL::SSL::VERIFY_NONE

    page = throttle_block do
      puts "Getting planning page"
      agent.get(INITIAL_PAGE_URL)
    end

    # Find all MuiStack-root divs
    sections = page.search("div.MuiStack-root")

    dev_app_section = sections.find do |section|
      h4 = section.at("h4")
      h4 && clean_whitespace(h4.text) == "Development applications"
    end

    raise "Could not find 'Development applications' section" unless dev_app_section

    process_applications(agent, dev_app_section)
  end

  def process_applications(agent, section)
    rows = section.search("tbody tr")
    added = found = 0

    rows.each do |row|
      th = row.at("th[scope='row']")
      next unless th

      link = th.at("a")
      next unless link

      info_url = link["href"]
      td = row.at("td")
      next unless td

      found += 1
      notice_text = clean_whitespace(td.text)
      notice_date = parse_notice_date(notice_text)

      # Fetch detail page
      detail_page = throttle_block do
        puts "Fetching: #{info_url}"
        agent.get(info_url)
      end

      project_div = detail_page.at("div.project_details")
      unless project_div
        puts "Warning: No project_details div found in detail page (skipped)"
        next
      end

      h1 = project_div.at("h1")
      h2 = project_div.at("h2")

      unless h1 && h2
        puts "Warning: Missing h1 or h2 in detail page (skipped)"
        next
      end

      address = clean_whitespace(h1.text)
      description_raw = clean_whitespace(h2.text)

      # Remove address from end of description if it matches
      description = if description_raw.end_with?(address)
                      clean_whitespace(description_raw[0...(description_raw.length - address.length)])
                    else
                      description_raw
                    end

      # Add state to address if not present
      address = "#{address}, #{STATE}" unless address.end_with?(STATE)

      council_reference = generate_council_reference(info_url)

      record = {
        "council_reference" => council_reference,
        "address" => address,
        "description" => description,
        "info_url" => info_url,
        "date_scraped" => Date.today.to_s,
      }

      record["on_notice_to"] = notice_date if notice_date

      added += 1
      puts "  Saving record #{council_reference}"
      ScraperWiki.save_sqlite(["council_reference"], record)
    end

    cleanup_old_records
    puts "Finished! Added #{added} records, skipped #{found - added} from #{found} rows found with links."
  end
end

Scraper.new.run if __FILE__ == $PROGRAM_NAME
