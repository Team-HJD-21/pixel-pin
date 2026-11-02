# Policies and release review

Policy copy: `site/policies.mjs`. Korean, English, and Simplified Chinese each contain Terms, Privacy, and Support/payment information. All pages have localized policy navigation and website preference reset. Update all languages together.

The current checkout remains disabled. The site embeds no Lemon Squeezy script, checkout form, customer integration, or payment webhook.

## Required before enabling Lemon Squeezy

Lemon Squeezy prohibits donations with no product. Do not relabel a donation as a product to bypass this. Confirm that the actual digital product, fulfillment, value, and pricing are accepted. Pay-what-you-want describes product pricing, not permission to collect unrestricted donations.

Confirm and publish the actual seller identity, applicable business registration/contact disclosures, private support email, product/delivery, total price/currency/taxes, one-time or recurring billing, cancellation/refund conditions, and statutory consumer rights. Current public pages identify TeamHJD and its existing GitHub contact route; no unverified legal name, address, registration number, or email has been invented.

Before processing orders, document the actual fields TeamHJD receives, purpose/legal basis, access permissions, retention/deletion schedule, recipients and international processing, and a private channel for buyer/rights requests. Update the privacy notice and any required consent before launch. Do not request payment information in public GitHub issues. No marketing mailing list or opt-in is configured.

GitHub Pages cannot host a commercial SaaS or a site primarily facilitating commercial transactions. Reassess hosting before adding paid features or a sales-led checkout. The current site introduces a free desktop app. Keep the domain when migrating if required.

Sources checked 2026-11-02:

- https://docs.lemonsqueezy.com/help/getting-started/prohibited-products
- https://docs.lemonsqueezy.com/help/products/pay-what-you-want
- https://www.lemonsqueezy.com/privacy
- https://docs.github.com/en/pages/getting-started-with-github-pages/github-pages-limits#usage-limits
- https://docs.github.com/en/pages/getting-started-with-github-pages/what-is-github-pages#data-collection

## Validation and deployment

Run `node scripts/build-site.mjs`, `node scripts/check-site.mjs`, `node scripts/test-site.mjs`, and `node scripts/check-policies.mjs`. The last check covers 9 policy routes, localized language destinations, absent checkout, and >=4.5:1 normal-text foreground/background palette pairs. These checks do not substitute for a complete screen-reader or interactive browser accessibility audit.

Review the website locally before pushing/deploying, as requested by the owner. The app changes require a new release; publishing only the site does not update previously downloaded v1.1.0 binaries. The new app's policy buttons resolve to public URLs, which become usable after the website deployment. Do not release the new app before those URLs are live.

App checks: `dotnet run --project tests/PixelPin.Checks/Check.csproj`. They use temporary history files, preserve unrelated files, test a blocked write, and instantiate settings in three languages and two themes without showing windows or saving the user's preferences. Run `dotnet list PixelPin.csproj package --vulnerable --include-transitive` with access to the vulnerability source. The 2026-11-02 check reported no known vulnerable direct or transitive package; this is not a full security audit.
