# Vendored libraries

## ethers 6.15.0 (vendor/ethers-6.15.0.min.js)
- Self-hosted copy of `dist/ethers.min.js` from the npm tarball ethers@6.15.0 (single-file ESM bundle, MIT, see ethers-LICENSE.md).
- Tarball integrity (matches `npm view ethers@6.15.0 dist.integrity`): sha512-Kf/3ZW54L4UT0pZtsY/rf+EkBU7Qi5nnhonjUb8yTXcxH3cdcWrV2cRyk0Xk/4jK6OoHhxxZHriyhje20If2hQ==
- File hash: sha384-5TjFfQUy6pFWffe1+gf+DryChtDNiEkBvEOmQvzKYKf67wpw6oiqewnjtwSfjcCU
- Replaces the jsDelivr `/+esm` URL (audit M-4): served same-origin from this repo, so no third-party CDN can change the code the app runs.
- To update: `npm pack ethers@<v>`, check the tarball integrity against npm, copy `package/dist/ethers.min.js` here under the new version name, update every page + tools/*.tpl.html, bump sw.js.
