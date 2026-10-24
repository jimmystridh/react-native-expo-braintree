# Repository Guidelines

## Project Structure & Module Organization
The publishable TypeScript source lives in `src/`; avoid editing any generated `lib/` or `nitrogen/` output. The Nitro Modules spec is `src/ExpoBraintree.nitro.ts`; its Swift (`ios/ExpoBraintree.swift`) and Kotlin (`android/.../ExpoBraintree.kt`) implementations must both implement every method in it. The Expo config plugin files sit in `src/plugin/`, while shared types reside in `src/types.ts`. The `example/` workspace hosts a bare React Native demo app and `expo-examples/` hosts Expo SDK 53–55 apps for manual validation. Jest specs live under `src/__tests__/`.

## Build, Test, and Development Commands
Use Yarn 3 (`yarn -v` should report 3.6.x). `yarn lint` runs ESLint across JS/TS sources. `yarn typecheck` executes `tsc` against `tsconfig.json`. `yarn nitrogen` regenerates the native bindings in `nitrogen/` after the Nitro spec changes; rerun `pod install` / Gradle sync afterwards. `yarn test` launches the Jest suite with the React Native preset. `yarn prepare` invokes `bob build` to run nitrogen and emit CommonJS, ES modules, and type declarations into `lib/`—run it before publishing.

## Coding Style & Naming Conventions
Follow the React Native ESLint config plus Prettier rules: two-space indentation, semicolons, single quotes, trailing commas on multi-line literals, and consistent quoted property keys. Prefer PascalCase for components, camelCase for functions/variables, and SCREAMING_SNAKE_CASE for constants. Keep modules focused; platform-specific logic belongs in `*.android.ts` / `*.ios.ts` siblings when appropriate.

## Testing Guidelines
Write Jest specs beside the code under `src/__tests__`, using the `.test.tsx` suffix. Mock native modules selectively; integration specifics should be exercised in the `example` or `expo-examples` apps instead. When fixing bugs, add regression tests first. Ensure the suite passes with `yarn test` and include type coverage via `yarn typecheck` before opening a PR.

## Commit & Pull Request Guidelines
Commits follow Conventional Commits (`feat:`, `fix:`, `chore:`) enforced by commitlint through Lefthook. Stage focused changes and allow the hooks to run (`npx eslint` + `npx tsc`). PRs should summarize intent, link related issues, and note relevant SDK versions or platform impacts. Add screenshots or reproduction steps for user-facing changes and call out any manual QA done in the `example` app.

## Automation & Release Notes
Lefthook runs on `pre-commit` and `commit-msg`; rerun `yarn install` if hooks misbehave. Releases are handled via `yarn release`, which triggers `release-it` to draft changelogs and npm packages—coordinate with maintainers before publishing.
