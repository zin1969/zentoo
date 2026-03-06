export function getToken() {
  return document.cookie
    .split("; ")
    .find((row) => row.startsWith("token="))
    ?.split("=")[1];
}

export function setToken(token: string) {
  document.cookie = `token=${token}; path=/`;
}
