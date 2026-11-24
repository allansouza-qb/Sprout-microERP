// Thin client for the Phoenix JSON API. Every write carries the CSRF token.
// Errors become ApiError with the server's message.
import {csrfToken} from "./boot"

export class ApiError extends Error {
  constructor(status, body) {
    super(body?.message || body?.errors?.detail || `Request failed (${status})`)
    this.status = status
    this.code = body?.error
    this.messages = body?.messages || [this.message]
  }

  // 409: the record changed since this screen loaded it.
  get stale() {
    return this.status === 409
  }
}

const query = (params) => {
  const entries = Object.entries(params || {}).filter(([, v]) => v !== null && v !== undefined && v !== "")
  return entries.length ? "?" + new URLSearchParams(entries).toString() : ""
}

async function request(method, path, body) {
  const headers = {accept: "application/json"}
  if (body !== undefined) headers["content-type"] = "application/json"
  if (method !== "GET") headers["x-csrf-token"] = csrfToken()

  const response = await fetch("/api" + path, {
    method,
    headers,
    credentials: "same-origin",
    body: body === undefined ? undefined : JSON.stringify(body),
  })

  if (response.status === 204) return null

  let payload = null
  try {
    payload = await response.json()
  } catch (_) {
    // not JSON (e.g. a proxy error page): reported through the status below
  }

  if (!response.ok) throw new ApiError(response.status, payload)
  return payload
}

export const api = {
  get: (path, params) => request("GET", path + query(params)),
  post: (path, body = {}) => request("POST", path, body),
  patch: (path, body = {}) => request("PATCH", path, body),
  delete: (path) => request("DELETE", path),
}
