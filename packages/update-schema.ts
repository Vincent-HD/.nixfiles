import { pathToFileURL } from "node:url";

const modulePath = process.env.NIXFILES_UPDATE_SCHEMA_MODULE ?? Bun.argv[2];
if (modulePath === undefined || modulePath === "") {
  throw new Error("The Nix-provided Zod module path is missing");
}

export const z = (await import(pathToFileURL(modulePath).href)).z;

export const Sha256HashSchema = z.string().regex(/^sha256-[A-Za-z0-9+/]{43}=$/);
export const Sha512HashSchema = z.string().regex(/^sha512-[A-Za-z0-9+/]{86}==$/);
export const SriHashSchema = z.union([Sha256HashSchema, Sha512HashSchema]);
export const UrlSchema = z.string().url();
export const VersionSchema = z.string().regex(/^\d+\.\d+\.\d+(?:-[\w.-]+)?$/);
export const PrefetchResultSchema = z.object({ hash: Sha256HashSchema }).passthrough();
