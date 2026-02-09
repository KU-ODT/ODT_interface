@echo off
echo Starting local server for Swagger UI...
echo.
echo Please keep this window open while using the API documentation.
echo Opening http://localhost:8000/interface.html in your default browser...
echo.

start http://localhost:8000/interface.html
python -m http.server 8000
pause
