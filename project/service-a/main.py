from fastapi import FastAPI
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

            # Print the average every 10 minutes
            if minute_count == 10:
                avg_price = mean(prices)
                print(f"Average Bitcoin price over the last 10 minutes: ${avg_price}")
                minute_count = 0  # Reset the counter
        except Exception as e:
            print(f"Error fetching Bitcoin price: {e}")

        await asyncio.sleep(60)  # Non-blocking sleep for 1 minute

# Define the lifespan context manager
@asynccontextmanager
async def lifespan(app: FastAPI):
    # Start the Bitcoin price fetch loop in the background
    task = asyncio.create_task(fetch_bitcoin_price())
    yield  # Keep the app running
    # Optionally, here you can do cleanup tasks (not needed for this scenario)
    task.cancel()  # Ensure the task is canceled when the app shuts down

# Use the lifespan context manager to handle startup and shutdown events
app = FastAPI(lifespan=lifespan)

@app.get('/health')
def health():
    return {"status": "healthy"}

@app.get('/')
def home():
    if prices:
        current_price = prices[-1]
        return {
            "current_price": current_price,
            "average_price_last_ten_minutes": avg_price,
            "price_history": prices
        }
    else:
        return {"message": "No data available yet. Please wait a few minutes."}

# Ensure the app doesn't exit immediately by explicitly running it with `uvicorn`
if __name__ == "__main__":
    import uvicorn
    uvicorn.run(app, host="0.0.0.0", port=8000)
