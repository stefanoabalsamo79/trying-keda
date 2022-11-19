ARG BASE_IMAGE
FROM "${BASE_IMAGE}"

ARG APP_NAME
ENV APP_NAME="$APP_NAME"

WORKDIR /home/app

COPY index.js package.json ./

EXPOSE 3000

RUN npm install

CMD node /home/app/index.js
