import AWS from "aws-sdk";

const s3 = new AWS.S3();
const BUCKET_NAME = process.env.BUCKET_NAME;

export const handler = async (event: any) => {
  const city = event.pathParameters.city;

  if (!city) {
    return {
      statusCode: 400,
      body: JSON.stringify({ error: "City parameter is required." }),
    };
  }

  try {
    const listObjectsResponse = await s3
      .listObjectsV2({ Bucket: BUCKET_NAME!, Prefix: `weather/${city}/` })
      .promise();

    if (
      !listObjectsResponse.Contents ||
      listObjectsResponse.Contents.length === 0
    ) {
      return {
        statusCode: 404,
        body: JSON.stringify({
          error: "No historical data found for this city.",
        }),
      };
    }

    const historicalDataPromises = listObjectsResponse.Contents.map((object) =>
      s3
        .getObject({ Bucket: BUCKET_NAME!, Key: object.Key! })
        .promise()
        .then((data) => JSON.parse(data.Body!.toString()))
    );

    const historicalData = await Promise.all(historicalDataPromises);

    return { statusCode: 200, body: JSON.stringify({ data: historicalData }) };
  } catch (error: any) {
    return { statusCode: 500, body: JSON.stringify({ error: error.message }) };
  }
};
