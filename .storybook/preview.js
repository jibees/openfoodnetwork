export const parameters = {
  server: {
    assetsURL: `http://localhost:3000`,
    url: `http://localhost:3000/rails/stories`,
  },
};

document.querySelector('head').innerHTML = document.querySelector("head").innerHTML.replaceAll(/\${SERVER_URL}/g, parameters.server.assetsURL)
