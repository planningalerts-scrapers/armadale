# City of Armadale, WA - Advertised Development applications Scraper

* Cookie tracking - No
* Pagnation - No
* Javascript - No
* Clearly defined data within a row - yes
* System - unknown

This is a scraper that runs on [Morph](https://morph.io). 
To get started [see the documentation](https://morph.io/documentation)

Add any issues to https://github.com/planningalerts-scrapers/issues/issues

## To run the scraper

    bundle exec ruby scraper.rb

### Expected output

```
Getting planning page
Fetching: https://engage.armadale.wa.gov.au/lot-43-no-3153-albany-highway-armadale
  Saving record lot-43-no-3153-albany-highway-armadale
Fetching: https://engage.armadale.wa.gov.au/lot-18-d-p-6238-no-51-wungong-road-armadale
  Saving record lot-18-d-p-6238-no-51-wungong-road-armadale
...
Fetching: https://engage.armadale.wa.gov.au/lot-200-edison-circuit-forrestdale
  Saving record lot-200-edison-circuit-forrestdale
Fetching: https://engage.armadale.wa.gov.au/2-hensbrook-loop-forrestdale
  Saving record 2-hensbrook-loop-forrestdale
Finished! Added 33 records, skipped 1 from 34 rows found with links.
```

Execution time: ~ 1 minute

## To run style and coding checks

    bundle exec rubocop

## To check for security updates

    gem install bundler-audit
    bundle-audit
