import traceback
from datetime import datetime
from enum import Enum
from typing import Dict, List, Optional, Any, Union
from dataclasses import dataclass, field
import json
import time
from contextlib import contextmanager

from langchain_groq import ChatGroq
from langchain.document_loaders import WebBaseLoader, PyPDFLoader, TextLoader
from langchain.text_splitter import RecursiveCharacterTextSplitter
from langchain.vectorstores import FAISS
from langchain_core.documents import Document
from langchain_core.prompts import ChatPromptTemplate
from langchain_core.pydantic_v1 import BaseModel, Field
from langchain import hub
from langchain_core.output_parsers import StrOutputParser
from langchain.prompts import PromptTemplate
from typing_extensions import TypedDict
from langgraph.graph import END, StateGraph, START
from duckduckgo_search import DDGS
from langchain_core.retrievers import BaseRetriever
from langchain.embeddings import HuggingFaceEmbeddings
from langchain_core.runnables.history import RunnableWithMessageHistory
from langchain.memory import ChatMessageHistory
from langchain.memory.chat_memory import BaseChatMessageHistory
from collections import defaultdict
from flask import Flask, request, jsonify
import os


class ErrorType(Enum):
    RETRIEVAL_ERROR = "retrieval_error"
    GENERATION_ERROR = "generation_error"
    GRADING_ERROR = "grading_error"
    SEARCH_ERROR = "search_error"
    VALIDATION_ERROR = "validation_error"
    NETWORK_ERROR = "network_error"
    SYSTEM_ERROR = "system_error"


class ProcessingState(Enum):
    INITIALIZED = "initialized"
    RETRIEVING = "retrieving"
    GRADING = "grading"
    GENERATING = "generating"
    TRANSFORMING = "transforming"
    SEARCHING = "searching"
    COMPLETED = "completed"
    FAILED = "failed"
    RETRYING = "retrying"


@dataclass
class SystemError:
    error_type: ErrorType
    message: str
    timestamp: datetime
    node: str
    retry_count: int = 0
    recoverable: bool = True


@dataclass
class ResponseResult:
    success: bool
    response: str
    error_message: Optional[str] = None
    state: ProcessingState = ProcessingState.COMPLETED
    retry_count: int = 0
    context_used: bool = False
    fallback_used: bool = False


class StateManager:
    
    def __init__(self):
        self.session_states: Dict[str, Dict] = {}
        self.max_retry_attempts = 3
        
    def initialize_session(self, session_id: str) -> Dict:
        if session_id not in self.session_states:
            self.session_states[session_id] = {
                'state': ProcessingState.INITIALIZED,
                'errors': [],
                'retry_count': 0,
                'start_time': datetime.now(),
                'last_activity': datetime.now(),
                'context': {},
                'consecutive_failures': 0
            }
        return self.session_states[session_id]
    
    def update_state(self, session_id: str, state: ProcessingState, context: Dict = None):
        session_state = self.initialize_session(session_id)
        session_state['state'] = state
        session_state['last_activity'] = datetime.now()
        if context:
            session_state['context'].update(context)
    
    def log_error(self, session_id: str, error: SystemError):
        session_state = self.initialize_session(session_id)
        session_state['errors'].append(error)
        session_state['consecutive_failures'] += 1
        
        
        if len(session_state['errors']) > 5:
            session_state['errors'] = session_state['errors'][-5:]
    
    def should_retry(self, session_id: str, error_type: ErrorType) -> bool:
        session_state = self.session_states.get(session_id, {})
        retry_count = session_state.get('retry_count', 0)
        consecutive_failures = session_state.get('consecutive_failures', 0)
        
        if error_type == ErrorType.VALIDATION_ERROR or consecutive_failures >= 3:
            return False
        
        return retry_count < self.max_retry_attempts
    
    def increment_retry(self, session_id: str):
        session_state = self.initialize_session(session_id)
        session_state['retry_count'] += 1
    
    def reset_failures(self, session_id: str):
        session_state = self.initialize_session(session_id)
        session_state['consecutive_failures'] = 0
        session_state['retry_count'] = 0
    
    def get_session_health(self, session_id: str) -> Dict:
        """Check session health - MISSING METHOD ADDED"""
        session_state = self.session_states.get(session_id, {})
        consecutive_failures = session_state.get('consecutive_failures', 0)
        
        return {
            'healthy': consecutive_failures < 5,
            'consecutive_failures': consecutive_failures,
            'retry_count': session_state.get('retry_count', 0)
        }

class SelectedIndices(BaseModel):
            indices: List[int] = Field(description="Indices of selected documents", example=[0, 1, 2, 3])

class SubQueries(BaseModel):
        sub_queries: List[str] = Field(description="List of sub-queries for comprehensive analysis", example=["What is the population of New York?", "What is the GDP of New York?"])


class AgenticRAG:

    def __init__(self):
        self.state_manager = StateManager()
        self.setup_system()

    def setup_system(self):
        try:
            
            os.environ["GROQ_API_KEY"] = "YOUR_GROQ_API_KEY"

            self.llm = ChatGroq(model_name="llama-3.1-8b-instant", temperature=0)

            self.chat_histories = defaultdict(ChatMessageHistory)

            self.setup_documents()

            self.setup_retrieval()

            self.setup_grading()

            self.setup_workflow()

            print("System setup completed successfully!")

        except Exception as e:
            print(f"System initialization failed: {str(e)}")
            print(f"Error traceback: {traceback.format_exc()}")
            raise

    def setup_documents(self):
        urls = [
            "https://www.assessli.com/",
            "https://www.assessli.com/contactus",
            "https://www.youtube.com/@assessli",
            "https://www.linkedin.com/company/assessli"
        ]

        try:
      
            docs = []
            for url in urls:
                try:
                    print(f"Loading URL: {url}")
                    loader = WebBaseLoader(url)
                    loaded_docs = loader.load()
                    docs.extend(loaded_docs)
                    print(f"Loaded {len(loaded_docs)} documents from {url}")
                except Exception as e:
                    print(f"Failed to load {url}: {str(e)}")
                    continue

            if not docs:
                print("No documents could be loaded from URLs")
                fallback_doc = Document(
                    page_content="Assessli is a company that provides assessment solutions. For more information, visit their website at assessli.com or contact them through their contact page.",
                    metadata={"source": "fallback"}
                )
                docs = [fallback_doc]
                print("Created fallback document")


            def split_text_to_chunks_with_indices(text: str, chunk_size: int, chunk_overlap: int) -> List[Document]:
                chunks = []
                start = 0
                while start < len(text):
                    end = start + chunk_size
                    chunk = text[start:end]
                    chunks.append(Document(page_content=chunk, metadata={"index": len(chunks), "text": text}))
                    start += chunk_size - chunk_overlap
                return chunks

            chunk_size = 400
            chunk_overlap = 200
            doc_splits = []
            for doc in docs:
                doc_text = doc.page_content
                doc_chunks = split_text_to_chunks_with_indices(doc_text, chunk_size, chunk_overlap)
                doc_splits.extend(doc_chunks)

            self.doc_splits = doc_splits
            print(f"Split documents into {len(self.doc_splits)} chunks")

            embedding_model = HuggingFaceEmbeddings(model_name="sentence-transformers/all-MiniLM-L6-v2")
            self.vectorstore = FAISS.from_documents(
                documents=self.doc_splits,
                embedding=embedding_model,
            )
            print("Created vector store")
            self.retriever = self.vectorstore.as_retriever(search_kwargs={"k": 1})

        except Exception as e:
            print(f"Document setup failed: {str(e)}")
            print(f"Error traceback: {traceback.format_exc()}")
            raise Exception(f"Document setup failed: {str(e)}")


    def get_chunk_by_index(self, target_index: int) -> Document:
      all_docs = self.vectorstore.similarity_search("", k=self.vectorstore.index.ntotal)
      for doc in all_docs:
          if doc.metadata.get('index') == target_index:
              return doc
      return None

    def retrieve_with_context_overlap(self, query: str, num_neighbors: int = 1, chunk_size: int = 400, chunk_overlap: int = 200) -> List[str]:
          relevant_chunks = self.retriever.get_relevant_documents(query)
          result_sequences = []

          for chunk in relevant_chunks:
              current_index = chunk.metadata.get('index')
              if current_index is None:
                  continue

              start_index = max(0, current_index - num_neighbors)
              end_index = current_index + num_neighbors + 1

              neighbor_chunks = []
              for i in range(start_index, end_index):
                  neighbor_chunk = self.get_chunk_by_index(i)
                  if neighbor_chunk:
                      neighbor_chunks.append(neighbor_chunk)

              neighbor_chunks.sort(key=lambda x: x.metadata.get('index', 0))

              concatenated_text = neighbor_chunks[0].page_content
              for i in range(1, len(neighbor_chunks)):
                  current_chunk = neighbor_chunks[i].page_content
                  overlap_start = max(0, len(concatenated_text) - chunk_overlap)
                  concatenated_text = concatenated_text[:overlap_start] + current_chunk

              result_sequences.append(concatenated_text)

          return result_sequences

    def wrap_chunks_with_documents(self, chunks: List[str]) -> List[Document]:
          return [Document(page_content=chunk) for chunk in chunks]

    def adaptive_retrieve(self, query: str, k: int = 4, user_context: str = None) -> List[Document]:
          """Adaptive retrieval based on query classification"""
          try:
              category = self.classify_query(query)
              print(f"Query category classified as: {category}")

              if category == "Factual":
                  return self.retrieve_factual(query, k)
              elif category == "Analytical":
                  return self.retrieve_analytical(query, k)
              elif category == "Opinion":
                  return self.retrieve_opinion(query, k)
              elif category == "Contextual":
                  return self.retrieve_contextual(query, k, user_context)
              else:
                  print(f"Unrecognized category '{category}', using basic similarity search.")
                  return self.vectorstore.similarity_search(query, k)

          except Exception as e:
              print(f"Adaptive retrieval failed: {str(e)}")
              try:
                  return self.vectorstore.similarity_search(query, k)
              except Exception as e2:
                  print(f"Basic retrieval also failed: {str(e2)}")
                  return []
    
    def setup_retrieval(self):
          """Setup retrieval components"""
          try:
              class RelevantScore(BaseModel):
                  score: float = Field(description="The relevance score of the document to the query", example=8.0)
              
              self.RelevantScore = RelevantScore
              
              class PydanticAdaptiveRetriever(BaseRetriever):
                  adaptive_retriever: callable = Field(exclude=True)
                  
                  class Config:
                      arbitrary_types_allowed = True
                  
                  def get_relevant_documents(self, query: str) -> List[Document]:
                      return self.adaptive_retriever(query)
                  
                  async def aget_relevant_documents(self, query: str) -> List[Document]:
                      return self.get_relevant_documents(query)
              
              self.retriever = PydanticAdaptiveRetriever(adaptive_retriever=self.adaptive_retrieve)
              print("Retrieval components setup completed")
              
          except Exception as e:
              print(f"Retrieval setup failed: {str(e)}")
              raise
    
    def setup_grading(self):
          """Setup document and response grading"""
          try:
              class GradeDocuments(BaseModel):
                  binary_score: str = Field(description="Documents are relevant to the question, 'yes' or 'no'")
              
              class GradeHallucinations(BaseModel):
                  binary_score: str = Field(description="Answer is grounded in the facts, 'yes' or 'no'")
              
              class GradeAnswer(BaseModel):
                  binary_score: str = Field(description="Answer addresses the question, 'yes' or 'no'")
              
              self.setup_grading_chains(GradeDocuments, GradeHallucinations, GradeAnswer)
              print("Grading components setup completed")
              
          except Exception as e:
              print(f"Grading setup failed: {str(e)}")
              raise
    
    def setup_grading_chains(self, GradeDocuments, GradeHallucinations, GradeAnswer):
          """Setup grading chain components"""
          try:
              system = """You are a grader assessing relevance of a retrieved document to a user question. 
              If the document contains keyword(s) or semantic meaning related to the user question, grade it as relevant. 
              Give a binary score 'yes' or 'no' score to indicate whether the document is relevant to the question."""
              
              grade_prompt = ChatPromptTemplate.from_messages([
                  ("system", system),
                  ("human", "Retrieved document: \n\n {document} \n\n User question: {question}")
              ])
              
              self.retrieval_grader = grade_prompt | self.llm.with_structured_output(GradeDocuments)
              
              system = """You are a grader assessing whether an LLM generation is grounded in / supported by a set of retrieved facts. 
              Give a binary score 'yes' or 'no'. 'Yes' means that the answer is grounded in / supported by the set of facts."""
              
              hallucination_prompt = ChatPromptTemplate.from_messages([
                  ("system", system),
                  ("human", "Set of facts: \n\n {documents} \n\n LLM generation: {generation}"),
              ])
              
              self.hallucination_grader = hallucination_prompt | self.llm.with_structured_output(GradeHallucinations)
              
              system = """You are a grader assessing whether an answer addresses / resolves a question 
              Give a binary score 'yes' or 'no'. Yes' means that the answer resolves the question."""
              
              answer_prompt = ChatPromptTemplate.from_messages([
                  ("system", system),
                  ("human", "User question: \n\n {question} \n\n LLM generation: {generation}"),
              ])
              
              self.answer_grader = answer_prompt | self.llm.with_structured_output(GradeAnswer)
              
              system = """You a question re-writer that converts an input question to a better version that is optimized 
              for vectorstore retrieval. Look at the input and try to reason about the underlying semantic intent / meaning."""
              
              re_write_prompt = ChatPromptTemplate.from_messages([
                  ("system", system),
                  ("human", "Here is the initial question: \n\n {question} \n Formulate an improved question."),
              ])
              
              self.question_rewriter = re_write_prompt | self.llm | StrOutputParser()
              
          except Exception as e:
              print(f"Grading chains setup failed: {str(e)}")
              raise Exception(f"Grading setup failed: {str(e)}")
    
    def setup_workflow(self):
          """Setup the workflow graph"""
          try:
              class GraphState(TypedDict):
                  question: str
                  generation: str
                  documents: List[str]
                  session_id: str
                  error_message: str
                  retry_count: int
              
              self.GraphState = GraphState
              
              workflow = StateGraph(GraphState)
              
              workflow.add_node("retrieve", self.safe_retrieve)
              workflow.add_node("grade_documents", self.safe_grade_documents)
              workflow.add_node("generate", self.safe_generate)
              workflow.add_node("transform_query", self.safe_transform_query)
              
              workflow.add_edge(START, "retrieve")
              workflow.add_edge("retrieve", "grade_documents")
              workflow.add_conditional_edges(
                  "grade_documents",
                  self.decide_to_generate,
                  {
                      "transform_query": "transform_query",
                      "generate": "generate",
                  },
              )
              workflow.add_edge("transform_query", "retrieve")
              workflow.add_conditional_edges(
                  "generate",
                  self.grade_generation_v_documents_and_question,
                  {
                      "not supported": "generate",
                      "useful": END,
                      "not useful": "transform_query",
                  },
              )
              
              self.app = workflow.compile()
              print("Workflow setup completed")
              
          except Exception as e:
              print(f"Workflow setup failed: {str(e)}")
              raise
    
    def safe_operation(self, operation_name: str, operation_func, *args, **kwargs):
          """Wrapper for safe operation execution"""
          try:
              return operation_func(*args, **kwargs)
          except Exception as e:
              error_message = f"Error in {operation_name}: {str(e)}"
              print(f"{error_message}")
              return {"error": error_message, "success": False}
    
    def classify_query(self, query: str) -> str:
          """Classify query type with error handling"""
          try:
              prompt = PromptTemplate(
                  input_variables=["query"],
                  template=(
                      "Classify the following query into one of these categories: "
                      "Factual, Analytical, Opinion, or Contextual.\n\n"
                      "Query: {query}\n\n"
                      "Category:"
                  )
              )
              chain = prompt | self.llm | StrOutputParser()
              result = chain.invoke({"query": query})
              return result.strip()
          except Exception as e:
              print(f"Query classification failed: {str(e)}")
              return "Factual" 
        


    def retrieve_factual(self, query: str, k: int = 4) -> List[Document]:
      """
      Retrieve enriched factual documents using context overlap,
      with error handling and fallback mechanisms.

      Args:
          query (str): The user's factual query.
          k (int): Number of enriched documents to return.

      Returns:
          List[Document]: List of Documents with context-enriched content.
      """
      print("Retrieving factual")

      try:
          enhance_prompt = PromptTemplate(
              input_variables=["query"],
              template="Enhance this factual query for better information retrieval: {query}"
          )
          query_chain = enhance_prompt | self.llm
          enhanced_query = query_chain.invoke({"query": query}).content
          print(f"Enhanced query: {enhanced_query}")

          try:
              enriched_chunks = self.retrieve_with_context_overlap(
                  self.vectorstore,
                  self.retriever,
                  enhanced_query,
                  num_neighbors=1
              )
              if not enriched_chunks:
                  raise ValueError("No enriched chunks found")
              return self.wrap_chunks_with_documents(enriched_chunks[:k])
          
          except Exception as retrieval_error:
              print(f"Contextual retrieval failed: {str(retrieval_error)}")
              print("Falling back to basic similarity search")

              docs = self.vectorstore.similarity_search(enhanced_query, k=k*2)

              try:
                  ranking_prompt = PromptTemplate(
                      input_variables=["query", "doc"],
                      template="On a scale of 1-10, how relevant is this document to the query: '{query}'?\nDocument: {doc}\nRelevance score:"
                  )
                  ranking_chain = ranking_prompt | self.llm.with_structured_output(self.RelevantScore)

                  ranked_docs = []
                  for doc in docs:
                      try:
                          input_data = {"query": enhanced_query, "doc": doc.page_content}
                          score = float(ranking_chain.invoke(input_data).score)
                          ranked_docs.append((doc, score))
                      except Exception:
                          ranked_docs.append((doc, 5.0))  
                  
                  ranked_docs.sort(key=lambda x: x[1], reverse=True)
                  return [doc for doc, _ in ranked_docs[:k]]

              except Exception as ranking_error:
                  print(f"Document ranking failed: {str(ranking_error)}")
                  return docs[:k]

      except Exception as e:
          print(f"Factual retrieval failed: {str(e)}")
          return self.vectorstore.similarity_search(query, k=k)

          
    def retrieve_analytical(self, query: str, k: int = 4) -> List[Document]:
      print("Retrieving Analytical Documents...")

      try:
          sub_queries_prompt = PromptTemplate(
              input_variables=["query", "k"],
              template="Generate {k} sub-questions for: {query}"
          )
          sub_queries_chain = sub_queries_prompt | self.llm.with_structured_output(self.SubQueries)
          sub_queries = sub_queries_chain.invoke({"query": query, "k": k}).sub_queries
          print(f"Generated Sub-queries: {sub_queries}")

          all_chunks = []
          for sub_query in sub_queries:
              try:
                  enriched_chunks = self.retrieve_with_context_overlap(
                      sub_query,
                      num_neighbors=1
                  )
                  all_chunks.extend(enriched_chunks)
              except Exception as chunk_err:
                  print(f"Chunk retrieval failed for sub-query '{sub_query}': {chunk_err}")
                  fallback_docs = self.vectorstore.similarity_search(sub_query, k=2)
                  all_chunks.extend([doc.page_content for doc in fallback_docs])

          all_docs = self.wrap_chunks_with_documents(all_chunks)

          docs_text = "\n".join([f"{i}: {doc.page_content[:100]}..." for i, doc in enumerate(all_docs)])

          diversity_prompt = PromptTemplate(
              input_variables=["query", "docs", "k"],
              template="Select the most diverse and relevant set of {k} documents for the query: '{query}'\nDocuments: {docs}\nReturn only the indices of selected documents as a list of integers."
          )
          diversity_chain = diversity_prompt | self.llm.with_structured_output(self.SelectedIndices)
          selected_indices = diversity_chain.invoke({"query": query, "docs": docs_text, "k": k}).indices

          return [all_docs[i] for i in selected_indices if i < len(all_docs)]

      except Exception as e:
          print(f"Analytical retrieval error: {e}")
          return self.vectorstore.similarity_search(query, k=k)




    def retrieve_opinion(self, query: str, k: int = 3) -> List[Document]:
      print("Retrieving Opinion-based Documents...")

      try:
          opinion_prompt = PromptTemplate(
              input_variables=["query", "k"],
              template="Identify {k} distinct viewpoints or perspectives on the topic: {query}"
          )
          viewpoints = (opinion_prompt | self.llm).invoke({"query": query, "k": k}).content.split('\n')
          viewpoints = [vp.strip() for vp in viewpoints if vp.strip()]
          print(f"Identified Viewpoints: {viewpoints}")

          all_chunks = []
          for vp in viewpoints:
              try:
                  enriched_chunks = self.retrieve_with_context_overlap(
                      self.vectorstore,
                      self.retriever,
                      f"{query} {vp}",
                      num_neighbors=1
                  )
                  all_chunks.extend(enriched_chunks)
              except Exception as sub_err:
                  print(f"Contextual retrieval failed for viewpoint '{vp}': {sub_err}")
                  fallback_docs = self.vectorstore.similarity_search(f"{query} {vp}", k=2)
                  all_chunks.extend([doc.page_content for doc in fallback_docs])

          all_docs = self.wrap_chunks_with_documents(all_chunks)

          docs_text = "\n".join([f"{i}: {doc.page_content[:100]}..." for i, doc in enumerate(all_docs)])

          opinion_select_prompt = PromptTemplate(
              input_variables=["query", "docs", "k"],
              template="Classify these documents into distinct opinions on '{query}' and select the {k} most representative and diverse viewpoints:\nDocuments: {docs}\nSelected indices:"
          )
          opinion_chain = opinion_select_prompt | self.llm.with_structured_output(self.SelectedIndices)

          selected_indices = opinion_chain.invoke({
              "query": query,
              "docs": docs_text,
              "k": k
          }).indices

          return [all_docs[i] for i in selected_indices if i < len(all_docs)]

      except Exception as e:
          print(f"Opinion retrieval error: {e}")
          return self.vectorstore.similarity_search(query, k=k)

        
    def retrieve_contextual(self, query: str, k: int = 4, user_context: str = None) -> List[Document]:
      print("Retrieving Contextual Documents...")

      try:
          context_str = user_context or "No specific context provided"

          contextualize_prompt = PromptTemplate(
              input_variables=["query", "context"],
              template="Given the user context: {context}\nReformulate the query to best address the user's needs: {query}"
          )
          contextualized_query = (contextualize_prompt | self.llm).invoke({
              "query": query,
              "context": context_str
          }).content
          print(f"Contextualized Query: {contextualized_query}")

          try:
              enriched_chunks = self.retrieve_with_context_overlap(
                  self.vectorstore,
                  self.retriever,
                  contextualized_query,
                  num_neighbors=1
              )
              all_docs = self.wrap_chunks_with_documents(enriched_chunks)

              contextual_rank_prompt = PromptTemplate(
                  input_variables=["query", "context", "doc"],
                  template="Given the query: '{query}' and user context: '{context}', rate the relevance of this document on a scale of 1-10:\nDocument: {doc}\nRelevance score:"
              )
              contextual_rank_chain = contextual_rank_prompt | self.llm.with_structured_output(self.RelevantScore)

              ranked_docs = []
              for doc in all_docs:
                  try:
                      input_data = {
                          "query": contextualized_query,
                          "context": context_str,
                          "doc": doc.page_content
                      }
                      score = float(contextual_rank_chain.invoke(input_data).score)
                      ranked_docs.append((doc, score))
                  except Exception as score_err:
                      print(f"Scoring failed for a doc: {score_err}")
                      ranked_docs.append((doc, 5.0))  # default score

              ranked_docs.sort(key=lambda x: x[1], reverse=True)
              return [doc for doc, _ in ranked_docs[:k]]

          except Exception as overlap_error:
              print(f"Context overlap retrieval failed: {overlap_error}")
              print("Falling back to standard similarity search...")

              fallback_docs = self.vectorstore.similarity_search(contextualized_query, k=k*2)

              contextual_rank_prompt = PromptTemplate(
                  input_variables=["query", "context", "doc"],
                  template="Given the query: '{query}' and user context: '{context}', rate the relevance of this document on a scale of 1-10:\nDocument: {doc}\nRelevance score:"
              )
              contextual_rank_chain = contextual_rank_prompt | self.llm.with_structured_output(self.RelevantScore)

              ranked_docs = []
              for doc in fallback_docs:
                  try:
                      input_data = {
                          "query": contextualized_query,
                          "context": context_str,
                          "doc": doc.page_content
                      }
                      score = float(contextual_rank_chain.invoke(input_data).score)
                      ranked_docs.append((doc, score))
                  except Exception as score_err:
                      ranked_docs.append((doc, 5.0))

              ranked_docs.sort(key=lambda x: x[1], reverse=True)
              return [doc for doc, _ in ranked_docs[:k]]

      except Exception as e:
          print(f"Contextual retrieval error: {e}")
          return self.vectorstore.similarity_search(query, k=k)

      
    def duckduckgo_search(self, query, max_results=3):
        """DuckDuckGo search with error handling"""
        try:
            print(f"🔍 Searching web for: {query}")
            time.sleep(1)
            with DDGS() as ddgs:
                results = ddgs.text(query, max_results=max_results)
                docs = []
                for r in results:
                    if 'body' in r:
                        docs.append(Document(page_content=r['body'], metadata={"source": r['href']}))
                        if len(docs) >= max_results:
                            break
                print(f"Found {len(docs)} web results")
                return docs
        except Exception as e:
            print(f"Web search failed: {str(e)}")
            return []
      
    def safe_retrieve(self, state):
        """Safe document retrieval"""
        try:
            question = state["question"]
            session_id = state.get("session_id", "default")
            
            print(f"Retrieving documents for: {question}")
            self.state_manager.update_state(session_id, ProcessingState.RETRIEVING)
            
            documents = self.retriever.invoke(question)
            
            if not documents:
                print("No documents found, will trigger search fallback")
                return {"documents": [], "question": question, "session_id": session_id, 
                    "error_message": "No documents found for your query."}
            
            print(f"Retrieved {len(documents)} documents")
            return {"documents": documents, "question": question, "session_id": session_id}
            
        except Exception as e:
            print(f"Retrieval failed: {str(e)}")
            session_id = state.get("session_id", "default")
            error = SystemError(
                error_type=ErrorType.RETRIEVAL_ERROR,
                message=str(e),
                timestamp=datetime.now(),
                node="retrieve"
            )
            self.state_manager.log_error(session_id, error)
            
            return {"documents": [], "question": state["question"], "session_id": session_id,
                "error_message": "I'm having trouble finding relevant information. Let me try a different approach."}
    
    def safe_grade_documents(self, state):
        """Safe document grading"""
        try:
            question = state["question"]
            documents = state["documents"]
            session_id = state.get("session_id", "default")
            
            print(f"Grading {len(documents)} documents")
            self.state_manager.update_state(session_id, ProcessingState.GRADING)
            
            if not documents:
                print("No documents found, trying web search")
                search_docs = self.duckduckgo_search(question)
                if search_docs:
                    print(f"Web search found {len(search_docs)} documents")
                    return {"documents": search_docs, "question": question, "session_id": session_id}
                else:
                    print("Web search also failed")
                    return {"documents": [], "question": question, "session_id": session_id,
                        "error_message": "I couldn't find relevant information for your question."}
            
            filtered_docs = []
            for i, d in enumerate(documents):
                try:
                    score = self.retrieval_grader.invoke(
                        {"question": question, "document": d.page_content}
                    )
                    if score.binary_score == "yes":
                        filtered_docs.append(d)
                        print(f"Document {i+1} is relevant")
                    else:
                        print(f"Document {i+1} is not relevant")
                except Exception as e:
                    print(f"Failed to grade document {i+1}: {str(e)}")
                    filtered_docs.append(d)
            
            if not filtered_docs:
                print("🔍 No relevant docs found, trying web search")
                search_docs = self.duckduckgo_search(question)
                filtered_docs = search_docs if search_docs else documents[:2]  
            
            print(f"Final document count: {len(filtered_docs)}")
            return {"documents": filtered_docs, "question": question, "session_id": session_id}
            
        except Exception as e:
            print(f"Document grading failed: {str(e)}")
            session_id = state.get("session_id", "default")
            error = SystemError(
                error_type=ErrorType.GRADING_ERROR,
                message=str(e),
                timestamp=datetime.now(),
                node="grade_documents"
            )
            self.state_manager.log_error(session_id, error)
            
            return {"documents": state.get("documents", []), "question": question, "session_id": session_id}
      
    def safe_generate(self, state):
        """Safe response generation"""
        try:
            question = state["question"]
            documents = state["documents"]
            session_id = state.get("session_id", "default")
            
            print(f"Generating response using {len(documents)} documents")
            self.state_manager.update_state(session_id, ProcessingState.GENERATING)
            
            if not documents:
                print("No documents available for generation")
                return {"documents": documents, "question": question, "session_id": session_id,
                    "generation": "I apologize, but I don't have enough information to answer your question properly. Could you please rephrase your question or provide more context?"}
            
            try:
                prompt = hub.pull("rlm/rag-prompt")
                rag_chain = prompt | self.llm | StrOutputParser()
                
                generation = rag_chain.invoke({"context": documents, "question": question})
                
                if not generation or len(generation.strip()) < 10:
                    generation = "I found some relevant information but couldn't generate a complete response. Could you please ask your question in a different way?"
                
                print(f"Generated response: {generation[:100]}...")
                return {"documents": documents, "question": question, "generation": generation, "session_id": session_id}
                
            except Exception as e:
                print(f"RAG chain failed: {str(e)}")
                context_text = "\n".join([doc.page_content for doc in documents[:3]])
                simple_prompt = f"Based on this context: {context_text}\n\nAnswer this question: {question}"
                
                try:
                    generation = self.llm.invoke(simple_prompt).content
                    print(f"Fallback generation successful")
                    return {"documents": documents, "question": question, "generation": generation, "session_id": session_id}
                except Exception as e2:
                    print(f"Fallback generation also failed: {str(e2)}")
                    raise e2
            
        except Exception as e:
            print(f"Generation completely failed: {str(e)}")
            session_id = state.get("session_id", "default")
            error = SystemError(
                error_type=ErrorType.GENERATION_ERROR,
                message=str(e),
                timestamp=datetime.now(),
                node="generate"
            )
            self.state_manager.log_error(session_id, error)
            
            fallback_response = "I'm experiencing some technical difficulties generating a response. Please try asking your question again, or rephrase it for better results."
            return {"documents": state.get("documents", []), "question": question, 
                "generation": fallback_response, "session_id": session_id}
    
    def safe_transform_query(self, state):
        """Safe query transformation"""
        try:
            question = state["question"]
            session_id = state.get("session_id", "default")
            
            print(f"Transforming query: {question}")
            self.state_manager.update_state(session_id, ProcessingState.TRANSFORMING)
            
            better_question = self.question_rewriter.invoke({"question": question})
            
            if not better_question or len(better_question.strip()) < 5:
                better_question = question  
            
            print(f"Transformed query: {better_question}")
            return {"documents": state.get("documents", []), "question": better_question, "session_id": session_id}
            
        except Exception as e:
            print(f"Query transformation failed: {str(e)}")
            session_id = state.get("session_id", "default")
            error = SystemError(
                error_type=ErrorType.SYSTEM_ERROR,
                message=str(e),
                timestamp=datetime.now(),
                node="transform_query"
            )
            self.state_manager.log_error(session_id, error)
            
            return {"documents": state.get("documents", []), "question": question, "session_id": session_id}
      
    def decide_to_generate(self, state):
        """Decide whether to generate or transform query"""
        documents = state.get("documents", [])
        
        if not documents:
            print("No documents found, will transform query")
            return "transform_query"
        else:
            print("Documents found, proceeding to generate")
            return "generate"
      
    def grade_generation_v_documents_and_question(self, state):
        """Grade generation quality"""
        try:
            question = state["question"]
            documents = state["documents"]
            generation = state["generation"]
            session_id = state.get("session_id", "default")
            
            print("Grading generation quality")
            
            if "technical difficulties" in generation.lower() or "apologize" in generation.lower():
                print("Generation contains error messages")
                return "not useful"
            
            try:
                score = self.hallucination_grader.invoke(
                    {"documents": documents, "generation": generation}
                )
                if score.binary_score == "no":
                    print("Generation not supported by documents")
                    return "not supported"
                else:
                    print("Generation is supported by documents")
            except Exception as e:
                print(f"Hallucination grading failed: {str(e)}")
                pass 
            
            try:
                score = self.answer_grader.invoke({"question": question, "generation": generation})
                if score.binary_score == "no":
                    print("Generation doesn't address the question")
                    return "not useful"
                else:
                    print("Generation addresses the question")
            except Exception as e:
                print(f"Answer grading failed: {str(e)}")
                pass  
            
            print("Generation is useful")
            self.state_manager.reset_failures(session_id)
            return "useful"
            
        except Exception as e:
            print(f"Generation grading failed: {str(e)}")
            return "useful"  
      
    def generate_response(self, question: str, session_id: str = "default") -> str:
        """Generate response with comprehensive error handling"""
        try:
            print(f"Starting response generation for: {question}")
            
            
            self.state_manager.initialize_session(session_id)
            
            if not question or len(question.strip()) < 3:
                print("Question too short")
                return "Please provide a more specific question so I can help you better."
            
            health = self.state_manager.get_session_health(session_id)
            if not health['healthy']:
                print("Session unhealthy")
                return "I'm experiencing some issues. Please try starting a new conversation."
            
            inputs = {"question": question, "session_id": session_id}
            
            try:
                print("Running workflow...")
                final_output = None
                step_count = 0
                
                for output in self.app.stream(inputs):
                    step_count += 1
                    print(f"Step {step_count}: {list(output.keys())}")
                    
                    for key, value in output.items():
                        if key == "generate":
                            final_output = value
                            print(f"Found final output in step {step_count}")
                            break
                    
                    if final_output:
                        break
                    
                    if step_count > 10:
                        print("Too many workflow steps, breaking")
                        break
                
                if final_output and "generation" in final_output:
                    response = final_output["generation"]
                    
                    if len(response.strip()) < 10:
                        print("Response too short")
                        return "I found some information but couldn't provide a complete answer. Could you please rephrase your question?"
                    
                    print("Response generation successful")
                    self.state_manager.update_state(session_id, ProcessingState.COMPLETED)
                    return response
                else:
                    print("No generation found in workflow output")
                    return "I'm having trouble processing your question right now. Please try rephrasing it or ask something else."
                    
            except Exception as e:
                print(f"Workflow execution failed: {str(e)}")
                print(f"Workflow traceback: {traceback.format_exc()}")
                
                if self.state_manager.should_retry(session_id, ErrorType.SYSTEM_ERROR):
                    print("Retrying...")
                    self.state_manager.increment_retry(session_id)
                    return "Let me try that again... " + self.generate_response(question, session_id)
                else:
                    print("Max retries reached")
                    return "I'm having trouble answering your question. Please try asking something else or rephrase your question."
        
        except Exception as e:
            print(f"Complete failure in generate_response: {str(e)}")
            print(f"Complete traceback: {traceback.format_exc()}")
            return "I'm experiencing technical difficulties. Please try your question again."


try:
    print("Initializing RAG System...")
    rag_system = AgenticRAG()
    print("RAG System initialized successfully!")
    
    def ask_question(question: str, session_id: str = "default") -> str:
        """User-friendly function to ask questions"""
        return rag_system.generate_response(question, session_id)
    
    if __name__ == "__main__":
        print("\n" + "="*50)
        print("TESTING RAG SYSTEM")
        print("="*50)
        
        test_questions = [
            "What is Assessli?",
            "Where is Assessli located?",
            "How can I contact Assessli?",
            "What services does Assessli provide?"
        ]
        
        for i, test_question in enumerate(test_questions, 1):
            print(f"\nTest {i}: {test_question}")
            print("-" * 50)
            
            try:
                response = ask_question(test_question, f"test_session")
                print(f"Response: {response}")
            except Exception as e:
                print(f"Test failed: {str(e)}")
                print(f"Traceback: {traceback.format_exc()}")
        
        print("\n" + "="*50)
        print("TESTING COMPLETE")
        print("="*50)
        
except Exception as e:
    print(f"Failed to initialize RAG system: {str(e)}")
    print(f"Initialization traceback: {traceback.format_exc()}")
    print("Please check your API keys and network connection.")
    
    class FallbackRAGSystem:
        def generate_response(self, question: str, session_id: str = "default") -> str:
            return "The RAG system is currently unavailable. Please check your configuration and try again."
    
    rag_system = FallbackRAGSystem()
    
    def ask_question(question: str, session_id: str = "default") -> str:
        return rag_system.generate_response(question, session_id)
    
app = Flask(__name__)

@app.route('/predict', methods=['POST'])
def predict():
    try:
        data = request.json
        if 'input' not in data:
            return jsonify({"error": "No input data provided"}), 400
        
        output = ask_question(data['input'], data['session_id'])
        
        return jsonify({"result": output})

    except Exception as e:
        return jsonify({"error": str(e)}), 500

if __name__ == '_main_':
    app.run(host='0.0.0.0', port=5001, debug=True)
