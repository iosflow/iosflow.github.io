# Scott Sheble’s portfolio

View at: https://iosflow.github.io/

A static portfolio with a Lexos source link and a playable TypeRush typing test. The TypeRush demo includes live timing, speed, accuracy, and character feedback. Its React leaderboard uses Axios to save and retrieve scores through an Express API backed by MongoDB. Visitors can rename or delete scores saved from their browser.

## Preview

From this directory, run `python3 -m http.server 8000 --bind 127.0.0.1` and open [the local portfolio](http://127.0.0.1:8000/).

## Publish with GitHub Pages

Publish this folder as the root of your portfolio repository. Include `index.html`, `css/`, `images/`, `js/`, and `projects/`. Asset links are relative, so both user sites and repository sites can serve the same files without a build.

For `https://iosflow.github.io/`, the GitHub Pages repository must be named `iosflow.github.io` under the `iosflow` account. In its **Settings → Pages**, select **Deploy from a branch**, then **main** and **/ (root)**. See [GitHub Pages publishing instructions](https://docs.github.com/en/pages/getting-started-with-github-pages/configuring-a-publishing-source-for-your-github-pages-site).

Check that the home page loads, the Lexos button opens its repository, and the TypeRush demo opens at `projects/typerush/`.

## TypeRush leaderboard

The typing test works on its own. To enable the shared leaderboard locally, run the API with Node.js and a MongoDB database.

```sh
cd projects/typerush/server
npm install
MONGODB_URI='<your MongoDB connection string>' npm start
```

Serve the portfolio from its root at port 8000 as described above. Local previews use the API at `http://127.0.0.1:5050`. The leaderboard loads React and Axios from esm.sh.

For production, deploy `projects/typerush/server` as a [Render web service](https://render.com/docs/web-services) with build command `npm install` and start command `npm start`. Set `MONGODB_URI` to your Atlas connection string and `CLIENT_ORIGINS` to a comma-separated list of exact frontend origins, such as `https://iosflow.github.io`. Keep the database credentials in the backend environment.

Set the `typerush-api` meta tag in `projects/typerush/index.html` to the deployed HTTPS API origin. The portfolio can stay on GitHub Pages or be deployed as a static project from the same GitHub repository on Vercel. Add the Vercel frontend origin to `CLIENT_ORIGINS` if using Vercel. GitHub Actions runs the API integration tests when TypeRush files change.

The API reads the ten highest scores and the browser’s 25 most recent scores. New scores can be submitted once per run. A browser-local token authorizes that browser’s renames and deletions, while historical scores without an ownership token remain eligible for the public leaderboard.
