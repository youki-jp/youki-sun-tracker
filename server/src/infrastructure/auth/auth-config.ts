export function authMode(): "apple" | "temporary" {
  const mode = process.env.AUTH_MODE ?? "apple";
  if (mode !== "apple" && mode !== "temporary") {
    throw new Error("AUTH_MODE must be apple or temporary.");
  }
  return mode;
}

export function testUserPassword(): string {
  const password = process.env.YOOKI_TEST_USER_PASSWORD;
  if (!password || password.length > 128) {
    throw new Error("YOOKI_TEST_USER_PASSWORD is required and must be at most 128 characters.");
  }
  if (process.env.NODE_ENV === "production" && password.length < 24) {
    throw new Error("Production temporary login requires a password of at least 24 characters.");
  }
  return password;
}
