FROM public.ecr.aws/lambda/nodejs:20
COPY package*.json ./
RUN npm install --production
COPY index.js ./
CMD ["index.handler"]
