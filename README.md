# FACET examples

Small projects that the guides on [facet-framework.com](https://facet-framework.com/en/guides/)
use to show FACET at work. Each folder is one example.

> [!WARNING]
> **This repository exists only to demonstrate FACET.** The examples are deliberately
> pragmatic and are not a model for anything: not for structuring a project, not for
> writing code, tests or migrations, and not even for using FACET. FACET changes over time,
> and these examples are not maintained beyond the guides that link to them. When one of
> those guides is updated, the matching state here is updated with it. For how to use FACET
> today, read the [documentation](https://facet-framework.com/en/docs/).

| Folder | What it is |
| --- | --- |
| [`shop/`](shop/) | A small TypeScript shop: discount codes, orders, refunds and invoices. |

## Use an example with a guide

```sh
git clone https://github.com/facet-framework/examples.git
cd examples
```

`main` holds every example without FACET. Each guide that builds on an example has a branch
`guide/<guide>` with the state at the end of that guide. Start from the branch the guide names,
or compare your result with its end state. The example's own README lists its guides.
