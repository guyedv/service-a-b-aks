from fastapi import FastAPI
from fastapi.responses import HTMLResponse
import requests
import asyncio
from statistics import mean
from contextlib import asynccontextmanager

BITCOIN_API = "https://api.coindesk.com/v1/bpi/currentprice/BTC.json"
app = FastAPI()
prices = []
avg_price = 0


# The fetch function
async def fetch_bitcoin_price():
    global prices
    global avg_price
    minute_count = 0  # Counter to track the number of minutes

    while True:
        try:
            response = requests.get(BITCOIN_API)
            data = response.json()
            price = float(data["bpi"]["USD"]["rate"].replace(',', ''))
            print(f"Current Bitcoin Price is: ${price}")
            prices.append(price)

            # Keep only the last 10 prices
            if len(prices) > 10:
                prices.pop(0)

            # Increment the minute counter
            minute_count += 1

            # Calculate the average price over the last 10 minutes
            avg_price = mean(prices)
        except Exception as e:
            print(f"Error fetching Bitcoin price: {e}")

        await asyncio.sleep(60)  # Non-blocking sleep for 1 minute


# Define the lifespan context manager
@asynccontextmanager
async def lifespan(app: FastAPI):
    # Start the Bitcoin price fetch loop in the background
    task = asyncio.create_task(fetch_bitcoin_price())
    yield  # Keep the app running
    task.cancel()  # Ensure the task is canceled when the app shuts down


app = FastAPI(lifespan=lifespan)


@app.get("/", response_class=HTMLResponse)
def home():
    if prices:
        current_price = prices[-1]
        html_content = f"""
        <!DOCTYPE html>
        <html>
        <head>
            <title>Bitcoin Price Tracker</title>
            <style>
                body {{
                    font-family: Arial, sans-serif;
                    background-color: #f8f9fa;
                    color: #212529;
                    padding: 20px;
                    margin: 0;
                }}
                h1 {{
                    text-align: center;
                    color: #343a40;
                }}
                .container {{
                    max-width: 800px;
                    margin: 0 auto;
                    background: #fff;
                    padding: 20px;
                    border-radius: 8px;
                    box-shadow: 0 4px 6px rgba(0, 0, 0, 0.1);
                }}
                table {{
                    width: 100%;
                    border-collapse: collapse;
                    margin-top: 20px;
                }}
                th, td {{
                    padding: 10px;
                    text-align: left;
                    border: 1px solid #dee2e6;
                }}
                th {{
                    background-color: #f1f3f5;
                }}
                .current {{
                    font-size: 1.5em;
                    margin-top: 10px;
                }}
            </style>
        </head>
        <body>
            <div class="container">
                <h1>Bitcoin Price Tracker</h1>
                <div class="current">
                    <strong>Current Bitcoin Price:</strong> ${current_price:.2f}
                </div>
                <div class="current">
                    <strong>Average Price (Last 10 Minutes):</strong> ${avg_price:.2f}
                </div>
                <h2>Price History (Last 10 Minutes)</h2>
                <table>
                    <thead>
                        <tr>
                            <th>#</th>
                            <th>Price (USD)</th>
                        </tr>
                    </thead>
                    <tbody>
        """
        for idx, price in enumerate(prices, start=1):
            html_content += f"""
                        <tr>
                            <td>{idx}</td>
                            <td>${price:.2f}</td>
                        </tr>
            """
        html_content += """
                    </tbody>
                </table>
            </div>
        </body>
        </html>
        """
        return HTMLResponse(content=html_content)
    else:
        return HTMLResponse(
            content="<h1>No data available yet. Please wait a few minutes.</h1>"
        )


@app.get("/health")
def health():
    return {"status": "healthy"}


if __name__ == "__main__":
    import uvicorn

    uvicorn.run(app, host="0.0.0.0", port=8000)