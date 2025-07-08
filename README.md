
# Assessli Agentic AI Chatbot 🤖

## 🚀 Project Overview

This project presents the **Assessli Agentic AI Chatbot** which integrates advanced **Retrieval-Augmented Generation (RAG)** techniques to provide accurate, trustworthy, and contextually enriched responses.

The system enhances traditional RAG pipelines with two powerful mechanisms:
- **Adaptive Query Refinement**
- **Context-Enriched Document Indexing**

These upgrades ensure high-quality results by adapting to the user’s intent and refining both retrieval and generation in a loop until a reliable output is formed.

---

## 📊 Overall System Architecture

![Pipeline](pipeline.jpg)

---

## 🧠 Internal Workflow

### 🔹 1. **User Query Input**
The interaction starts when the user submits a query through the chatbot interface.

### 🔹 2. **Chat Memory**
Preserves context across interactions to ensure coherent, personalized responses.

### 🔹 3. **Adaptive Query Refinement**
- Classifies user query into one of: **factual, analytical, contextual, opinion-based**.
- Dynamically chooses the best retrieval strategy for that query type.
- Inspired by: [`Adaptive Retrieval`](https://github.com/NirDiamant/RAG_Techniques/blob/main/all_rag_techniques/adaptive_retrieval.ipynb)

### 🔹 4. **Context-Enriched Document Indexing**
- Segments documents into semantic chunks and enriches them with neighboring content.
- Stores enriched embeddings in a vector database.
- Inspired by: [`Context Enrichment Window`](https://github.com/NirDiamant/RAG_Techniques/blob/main/all_rag_techniques/context_enrichment_window_around_chunk.ipynb)

### 🔹 5. **Enhanced Retrieval Pipeline**
- Uses the refined query to retrieve ranked results from the vector database.
- Sends retrieved content and query to the LLM.

### 🔹 6. **Response Grading & Hallucination Filtering**
- Evaluates LLM response for:
  - ✅ Query Relevance
  - ❌ Hallucination

### 🔹 7. **Query Rewriting Loop (If Necessary)**
- If the output fails the validation check, the system triggers a **query rewriting loop** and retries.

### 🔹 8. **Output Delivery or Exception Handling**
- Delivers validated response to the user.
- Handles exceptions like incomplete queries or API rate limits with fallback messages.

---

## 🧰 Tech Stack

| Module           | Tool/Framework                           |
|------------------|------------------------------------------|
| **Orchestration**| LangGraph                                |
| **Vector DB**    | FAISS (Meta)                             |
| **Containerization** | Docker                               |
| **LLM Execution**| LLaMA 3.1 via Groq                       |
| **Web Search**   | DuckDuckGo Search API                    |
| **Web Scraping** | WebBaseLoader (LangChain)                |
| **Text Embedding** | Hugging Face Sentence Transformers     |
| **Tokenizer**    | Hugging Face                             |
| **Text Cleaning**| LangChain CharacterTextSplitter          |
| **Chat Memory**  | LangChain ConversationBufferMemory       |
| **Frontend**     | Flutter (Cross-platform)                 |
| **Backend**      | Flask (Python)                           |
| **TTS Engine**   | Deepgram                                 |

---

## 🛠️ Setup Instructions

### 🔐 API Keys Setup 

- **Groq API Key**:  
  Get a free key from [https://console.groq.com/keys](https://console.groq.com/keys)  


- **Deepgram API Key**:  
  Get a free key from [https://console.deepgram.com/signup](https://console.deepgram.com/signup)  


---

### 📱 Flutter Frontend Setup

> 🖥️ Run these commands in your **terminal (bash/cmd)**

```bash
# 1. Clone the Repository
git clone https://github.com/Kunal-3004/Assessli-AI-Hackathon.git

# 2. Navigate to Project Directory
cd Assessli-AI-Hackathon

# 3. Install Flutter Dependencies
flutter pub get

# 4. Run the Flutter App
flutter run
```

---

### 🐳 Backend Setup (Flask + Docker)

> 🖥️ Run these commands in your **terminal inside the cloned folder**

```bash
# 1. Navigate to Backend Code
cd Chatbot

# 2. Build the Docker Image
docker build -t flask-agentic .

# 3. Run the Docker Container (Exposes port 5000)
docker run -p 5000:5000 flask-agentic
```

> ✅ After running, the Flask backend should be available at `http://localhost:5000`

---

## 📚 References

- [Adaptive Retrieval - Nir Diamant](https://github.com/NirDiamant/RAG_Techniques/blob/main/all_rag_techniques/adaptive_retrieval.ipynb)  
- [Context Enrichment Window - Nir Diamant](https://github.com/NirDiamant/RAG_Techniques/blob/main/all_rag_techniques/context_enrichment_window_around_chunk.ipynb)

---

## 💡 Key Features

- Modular and scalable architecture  
- Intelligent query classification and enrichment  
- Feedback loop for reliability  
- Real-time query rewriting  
- Seamless exception handling

---

## 👨‍💻 Team

**Team Tridents** – IIT ISM Dhanbad
