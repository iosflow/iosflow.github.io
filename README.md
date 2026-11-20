# Scott Sheble’s portfolio

A static portfolio with a Lexos source link and a playable TypeRush typing test. TypeRush’s portfolio demo runs in the browser and includes live timing, speed, accuracy, and character feedback. The original app’s shared leaderboard uses Express and MongoDB.

## Preview

From this directory, run `python3 -m http.server 8000 --bind 127.0.0.1` and open [the local portfolio](http://127.0.0.1:8000/).

## Publish with GitHub Pages

Publish this folder as the root of your portfolio repository. Include `index.html`, `css/`, `images/`, and `projects/`. Asset links are relative, so both user sites and repository sites can serve the same files without a build.

For `https://iosflow.github.io/`, the GitHub Pages repository must be named `iosflow.github.io` under the `iosflow` account. In its **Settings → Pages**, select **Deploy from a branch**, then **main** and **/ (root)**. See [GitHub Pages publishing instructions](https://docs.github.com/en/pages/getting-started-with-github-pages/configuring-a-publishing-source-for-your-github-pages-site).

Check that the home page loads, the Lexos button opens its repository, and the TypeRush demo opens at `projects/typerush/`.
