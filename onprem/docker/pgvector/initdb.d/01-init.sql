CREATE EXTENSION IF NOT EXISTS vector;

DROP TABLE IF EXISTS knowledge;
CREATE TABLE knowledge (
    id SERIAL PRIMARY KEY,
    content TEXT,
    metadata JSONB,
    embedding VECTOR(1536)
);
CREATE INDEX knowledge_embedding_idx
    ON knowledge USING hnsw (embedding vector_cosine_ops);