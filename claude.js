#!/usr/bin/env node

import Anthropic from "@anthropic-ai/sdk";

const input = process.argv.slice(2).join(" ");

if (!input) {
  console.log("Usage: claude \"your prompt here\"");
  process.exit(1);
}

const client = new Anthropic({
  apiKey: process.env.ANTHROPIC_API_KEY,
});

const res = await client.messages.create({
  model: "claude-3-sonnet-20240229",
  max_tokens: 300,
  messages: [{ role: "user", content: input }],
});

console.log(res.content[0].text);