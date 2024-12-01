import axios from "axios";
import AWS from "aws-sdk";

const s3 = new AWS.S3();
const BUCKET_NAME = process.env.BUCKET_NAME;
const OPENWEATHER_API_KEY = process.env.OPENWEATHER_API_KEY;

export const handler = async (event: any) => {
  const city = event.pathParameters.city;

  if (!city) {
    return {
      statusCode: 400,
      body: JSON.stringify({ error: "City parameter is required." }),
    };
  }

  try {
    const response = await axios.get(
      `https://api.openweathermap.org/data/2.5/weather`,
      {
        params: { q: city, appid: OPENWEATHER_API_KEY, units: "metric" },
      }
    );

    const weatherData = response.data;
    const timestamp = new Date().toISOString();
    const key = `weather/${city}/${timestamp}.json`;

    await s3
      .putObject({
        Bucket: BUCKET_NAME!,
        Key: key,
        Body: JSON.stringify(weatherData),
        ContentType: "application/json",
      })
      .promise();

    return { statusCode: 200, body: JSON.stringify({ data: weatherData }) };
  } catch (error: any) {
    return {
      statusCode: error.response?.status || 500,
      body: JSON.stringify({ error: error.message }),
    };
  }
};
