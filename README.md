# GuidO_project
Project for AI4Good Lab: An app that assists the visually impaired with crossing intersections by informing them of relevant details. Created in XCode using swift. Uses Google Gemini API. Package Dependencies: generative-ai-swift 0.5.4

ContentView.swift uses Google Gemini for all functions. You must change "YOUR_API_KEY" to your google gemini api key after downloading respective package dependencies.
ContentView_ResNET.swift uses resNet model for intersection type identification and Google Gemini for all other functions. You must change "YOUR_API_KEY" to your google gemini api key after downloading respective package dependencies. You must also change "ResNET_API_URL" in APIManager.swift to your generated public server URL from ngrok for the resNet model.
