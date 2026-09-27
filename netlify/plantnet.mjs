export default async (request) => {
  if (request.method !== "POST") {
    return new Response("Method Not Allowed", { status: 405 });
  }

  try {
    const apiKey = process.env.PLANTNET_API_KEY;

    if (!apiKey) {
      return new Response(
        JSON.stringify({ error: "PLANTNET_API_KEY is not configured" }),
        {
          status: 500,
          headers: { "Content-Type": "application/json" },
        }
      );
    }

    const incoming = await request.formData();
    const image = incoming.get("image");

    if (!image || typeof image === "string") {
      return new Response(
        JSON.stringify({ error: "Image is missing" }),
        {
          status: 400,
          headers: { "Content-Type": "application/json" },
        }
      );
    }

    const form = new FormData();
    form.append("images", image, image.name || "tree.jpg");

    const url =
      "https://my-api.plantnet.org/v2/identify/all" +
      "?api-key=" +
      encodeURIComponent(apiKey) +
      "&lang=uk" +
      "&nb-results=3";

    const response = await fetch(url, {
      method: "POST",
      body: form,
    });

    const text = await response.text();

    return new Response(text, {
      status: response.status,
      headers: {
        "Content-Type":
          response.headers.get("Content-Type") ||
          "application/json",
      },
    });
  } catch (error) {
    return new Response(
      JSON.stringify({
        error: error?.message || "Unknown error",
      }),
      {
        status: 500,
        headers: { "Content-Type": "application/json" },
      }
    );
  }
};

export const config = {
  path: "/api/plantnet",
};