---
title: Update an existing AKS article
description: Learn how to update a published Azure Kubernetes Service article in the azure-aks-docs repository and submit your changes for review.
ms.topic: how-to
ms.service: azure-kubernetes-service
ms.date: 08/13/2026
ai-usage: ai-assisted
---

# Update an existing AKS article

Learn how to update a published Azure Kubernetes Service (AKS) article in the `MicrosoftDocs/azure-aks-docs` repository. You can make a small edit in GitHub or work locally in Visual Studio Code for larger changes. After you validate your changes, submit them in a pull request (PR) for review.

## Prerequisites

- A GitHub account.
- Permission to contribute to the `MicrosoftDocs/azure-aks-docs` repository.
- Git, if you use the local editing workflow.
- Visual Studio Code or another Markdown editor, if you edit locally.

## Find the article source file

The published Learn article links to its source file in the `azure-aks-docs` repository.

1. Open the AKS article that you want to update on Microsoft Learn.
1. Select the link to the article source.
1. Confirm that the link opens the corresponding Markdown file in the `MicrosoftDocs/azure-aks-docs` repository.

For example, the source file for the AKS overview article is `articles/aks/what-is-aks.md`. The source path varies by article.

## Choose an editing method

Use GitHub in your browser for small changes, such as wording, links, formatting, or notes.

Use the local workflow for larger changes, including multi-file updates, image additions, article restructuring, or changes that require local validation.

## Edit the article in GitHub

1. Open the article's Markdown source file in GitHub.
1. Select **Edit this file**.
1. Make your changes in the Markdown editor.
1. Enter a short commit message that describes the change.
1. Select the option to create a new branch for the change.
1. Select **Propose changes**.
1. Select **Create pull request**.

The available GitHub options depend on your repository permissions and the repository's contribution settings.

## Edit the article locally

Clone the repository and move to its root directory:

```bash
git clone https://github.com/MicrosoftDocs/azure-aks-docs.git
cd azure-aks-docs
```

Create a branch for your change:

```bash
git checkout -b update-article-name
```

Open the repository in Visual Studio Code:

```bash
code .
```

Open the Markdown source file for the article and make your changes. Review the resulting diff before you commit:

```bash
git diff
```

## Follow Learn writing and Markdown conventions

Follow the Microsoft Writing Style Guide and the contribution guidance for this repository. Match the terminology and tone of the surrounding article.

Use standard Markdown for headings, lists, links, tables, and code blocks. Use Learn alert syntax when you need to call attention to important information:

```md
> [!NOTE]
> This information provides helpful context.

> [!IMPORTANT]
> This information is important for completing the task.

> [!WARNING]
> This information describes a potential risk.
```

For AKS content, use product terminology consistently. For example, use **Azure Kubernetes Service (AKS)** on first mention, followed by **AKS**, and verify terms such as **control plane**, **containerized applications**, and **node pools** against the surrounding article.

## Validate your changes

Before you open a PR:

- Preview the rendered Markdown.
- Check headings and list structure.
- Verify internal links.
- Check tables and images.
- Confirm that alert blocks use valid Learn syntax.
- Review the diff for unintended changes.
- Run the repository-specific validation commands described in the contribution guidance.

## Commit and push your changes

Stage the files that you changed. For example:

```bash
git add articles/aks/what-is-aks.md
```

Commit your changes with a concise message:

```bash
git commit -m "docs: update AKS article"
```

Push your branch:

```bash
git push origin update-article-name
```

## Open a pull request

After you push your branch, open GitHub and select **Compare & pull request**.

Include the following information in the PR:

- A clear title.
- A summary of the change.
- The sections or files that changed.
- The validation steps that you completed.

Use the repository pull request template when one is provided. A concise description might use this structure:

```md
## Summary

Describe the purpose of the documentation update.

## Changes

- Describe the main content changes.
- Mention link, example, or formatting updates.

## Validation

- Describe the checks or preview performed.
- Mention any repository validation results.
```

## Address validation and reviewer feedback

Review the automated checks on the PR. Checks might include Markdown linting, link validation, metadata validation, or documentation build validation.

If a check fails:

1. Open the workflow details.
1. Identify the reported file and problem.
1. Fix the issue locally.
1. Commit and push the correction to the same branch.

If a reviewer requests changes, update the same branch and push another commit. The existing PR updates automatically.

Reviewers might request wording changes, style corrections, technical verification, or clarification of AKS architecture and behavior.

## Merge and publish

After the PR is approved, a repository maintainer merges it. The documentation pipeline publishes the updated article according to the repository's publishing process. Publishing time can vary after the PR is merged.
