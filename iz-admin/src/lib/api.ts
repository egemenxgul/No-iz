export const API_URL = process.env.NEXT_PUBLIC_API_URL || "https://api.no-iz.app";

export async function fetchApi(endpoint: string, options: RequestInit = {}) {
  const token = getCookie("token");
  
  const headers: any = {
    "Content-Type": "application/json",
    ...options.headers,
    ...(token ? { Authorization: `Bearer ${token}` } : {}),
  };

  if (typeof window !== "undefined") {
    const lang = localStorage.getItem("iz_admin_language") || navigator.language.slice(0, 2).toLowerCase();
    headers["Accept-Language"] = lang;
  }

  const response = await fetch(`${API_URL}${endpoint}`, {
    ...options,
    headers,
  });

  if (!response.ok) {
    const errorData = await response.json().catch(() => null);
    throw new Error(errorData?.error || `API error: ${response.status}`);
  }

  return response.json();
}

// Simple cookie getter for client-side
export function getCookie(name: string) {
  if (typeof document === "undefined") return null;
  const value = `; ${document.cookie}`;
  const parts = value.split(`; ${name}=`);
  if (parts.length === 2) return parts.pop()?.split(";").shift();
  return null;
}

// Simple cookie setter for client-side
export function setCookie(name: string, value: string, days = 7) {
  if (typeof document === "undefined") return;
  const date = new Date();
  date.setTime(date.getTime() + days * 24 * 60 * 60 * 1000);
  document.cookie = `${name}=${value};expires=${date.toUTCString()};path=/;Secure;SameSite=Lax`;
}

// Delete cookie
export function deleteCookie(name: string) {
  if (typeof document === "undefined") return;
  document.cookie = `${name}=;expires=Thu, 01 Jan 1970 00:00:00 GMT;path=/;Secure;SameSite=Lax`;
}
