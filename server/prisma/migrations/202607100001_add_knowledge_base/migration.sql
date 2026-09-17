CREATE TABLE "KnowledgeBase" (
    "id" TEXT NOT NULL,
    "question" TEXT NOT NULL,
    "answer" TEXT NOT NULL,
    "keywords" TEXT[] NOT NULL DEFAULT ARRAY[]::TEXT[],
    "isActive" BOOLEAN NOT NULL DEFAULT true,
    "createdAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "updatedAt" TIMESTAMP(3) NOT NULL,
    CONSTRAINT "KnowledgeBase_pkey" PRIMARY KEY ("id")
);

CREATE INDEX "KnowledgeBase_isActive_idx" ON "KnowledgeBase"("isActive");

INSERT INTO "KnowledgeBase" ("id", "question", "answer", "keywords", "isActive", "createdAt", "updatedAt")
VALUES (
    'f0d62f98-1676-4d16-8c42-knowledge001',
    'Siapa owner dari aplikasi ini?',
    'Seandy Adryan Nugraha IT Tamvan',
    ARRAY['owner', 'pemilik', 'siapa owner', 'siapa pemilik', 'owner aplikasi', 'pemilik aplikasi']::TEXT[],
    true,
    CURRENT_TIMESTAMP,
    CURRENT_TIMESTAMP
);
