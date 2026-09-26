.pragma library

// A small TOML reader and writer, for config.toml (see config.js for what goes in it). It covers what
// the launcher needs and what a person is likely to type by hand: comments, `key = value`, dotted keys,
// `[table.sub]` headers, basic ("...") and literal ('...') strings, integers, floats, booleans, arrays
// (also over several lines, with a trailing comma) and inline tables. Not supported, and refused with
// an error naming the line: arrays of tables (`[[x]]`), multi-line strings, dates and times, hex/octal/
// binary numbers. Plain functions, no state.

function isPlainObject(v) { return v !== null && typeof v === "object" && !Array.isArray(v); }

// ---------------------------------------------------------------------------------------- reading
// The text as an object. Throws Error("line N: what is wrong").
function parse(text) {
    const src = String(text).replace(/\r\n?/g, "\n");
    const n = src.length;
    let i = 0;
    let line = 1;
    const root = {};
    const defined = {}; // dotted paths of the tables a header has opened already

    function fail(msg) { throw new Error("line " + line + ": " + msg); }
    function peek() { return src[i]; }
    function skipSpaces() { while (i < n && (src[i] === " " || src[i] === "\t")) i++; }
    function skipComment() { if (src[i] === "#") while (i < n && src[i] !== "\n") i++; }
    // spaces, comments and line breaks, for the places where a value may go on to the next line
    function skipBlank() {
        for (;;) {
            skipSpaces();
            if (src[i] === "#") skipComment();
            if (src[i] === "\n") { i++; line++; continue; }
            return;
        }
    }
    function endOfLine() {
        skipSpaces();
        skipComment();
        if (i < n && src[i] !== "\n") fail("unexpected \"" + src.slice(i, i + 12).split("\n")[0] + "\"");
    }

    function bareKey() {
        const m = /^[A-Za-z0-9_-]+/.exec(src.slice(i, i + 200));
        if (!m) fail("expected a key");
        i += m[0].length;
        return m[0];
    }
    function keyPath() {
        const path = [];
        for (;;) {
            skipSpaces();
            path.push(src[i] === "\"" ? basicString() : (src[i] === "'" ? literalString() : bareKey()));
            skipSpaces();
            if (src[i] === ".") { i++; continue; }
            return path;
        }
    }

    function basicString() {
        if (src.startsWith("\"\"\"", i)) fail("multi-line strings are not supported");
        i++; // opening quote
        let out = "";
        for (;;) {
            if (i >= n || src[i] === "\n") fail("unterminated string");
            const c = src[i++];
            if (c === "\"") return out;
            if (c !== "\\") { out += c; continue; }
            const e = src[i++];
            switch (e) {
            case "b": out += "\b"; break;
            case "t": out += "\t"; break;
            case "n": out += "\n"; break;
            case "f": out += "\f"; break;
            case "r": out += "\r"; break;
            case "\"": out += "\""; break;
            case "\\": out += "\\"; break;
            case "u": case "U": {
                const len = e === "u" ? 4 : 8;
                const hex = src.slice(i, i + len);
                if (!new RegExp("^[0-9a-fA-F]{" + len + "}$").test(hex)) fail("bad \\" + e + " escape");
                out += String.fromCodePoint(parseInt(hex, 16));
                i += len;
                break;
            }
            default: fail("unknown escape \\" + e);
            }
        }
    }
    function literalString() {
        if (src.startsWith("'''", i)) fail("multi-line strings are not supported");
        const end = src.indexOf("'", i + 1);
        const nl = src.indexOf("\n", i);
        if (end < 0 || (nl >= 0 && nl < end)) fail("unterminated string");
        const s = src.slice(i + 1, end);
        i = end + 1;
        return s;
    }

    function array() {
        i++; // [
        const out = [];
        for (;;) {
            skipBlank();
            if (src[i] === "]") { i++; return out; }
            out.push(value());
            skipBlank();
            if (src[i] === ",") { i++; continue; }
            if (src[i] === "]") { i++; return out; }
            fail("expected , or ] in the array");
        }
    }
    function inlineTable() {
        i++; // {
        const out = {};
        skipSpaces();
        if (src[i] === "}") { i++; return out; }
        for (;;) {
            const path = keyPath();
            skipSpaces();
            if (src[i] !== "=") fail("expected = after the key");
            i++;
            skipSpaces();
            assign(out, path, value());
            skipSpaces();
            if (src[i] === ",") { i++; continue; }
            if (src[i] === "}") { i++; return out; }
            fail("expected , or } in the inline table");
        }
    }
    function value() {
        skipSpaces();
        const c = src[i];
        if (c === "\"") return basicString();
        if (c === "'") return literalString();
        if (c === "[") return array();
        if (c === "{") return inlineTable();
        if (src.startsWith("true", i) && !/[A-Za-z0-9_]/.test(src[i + 4] || "")) { i += 4; return true; }
        if (src.startsWith("false", i) && !/[A-Za-z0-9_]/.test(src[i + 5] || "")) { i += 5; return false; }
        const m = /^[+-]?(?:[0-9][0-9_]*)(?:\.[0-9][0-9_]*)?(?:[eE][+-]?[0-9][0-9_]*)?/.exec(src.slice(i, i + 64));
        if (!m) fail(c === undefined || c === "\n" ? "a value is missing" : "cannot read the value \"" + src.slice(i, i + 12).split("\n")[0] + "\"");
        if (/^0[xob]/.test(src.slice(i, i + 2))) fail("hex, octal and binary numbers are not supported");
        i += m[0].length;
        if (src[i] === "-" || src[i] === ":") fail("dates and times are not supported");
        return Number(m[0].replace(/_/g, ""));
    }

    // put `v` at `path` inside `obj`, opening the tables on the way
    function assign(obj, path, v) {
        let t = obj;
        for (let k = 0; k < path.length - 1; k++) {
            if (t[path[k]] === undefined) t[path[k]] = {};
            else if (!isPlainObject(t[path[k]])) fail("\"" + path[k] + "\" is not a table");
            t = t[path[k]];
        }
        const last = path[path.length - 1];
        if (Object.prototype.hasOwnProperty.call(t, last)) fail("the key \"" + path.join(".") + "\" is set twice");
        t[last] = v;
    }
    function openTable(path) {
        const id = path.join("\u0000");
        if (defined[id]) fail("the table [" + path.join(".") + "] is defined twice");
        defined[id] = true;
        let t = root;
        for (const k of path) {
            if (t[k] === undefined) t[k] = {};
            else if (!isPlainObject(t[k])) fail("\"" + k + "\" is not a table");
            t = t[k];
        }
        return t;
    }

    let table = root;
    for (;;) {
        skipBlank();
        if (i >= n) return root;
        if (src[i] === "[") {
            if (src[i + 1] === "[") fail("arrays of tables ([[...]]) are not supported");
            i++;
            const path = keyPath();
            skipSpaces();
            if (src[i] !== "]") fail("expected ] to close the table name");
            i++;
            endOfLine();
            table = openTable(path);
            continue;
        }
        const path = keyPath();
        skipSpaces();
        if (src[i] !== "=") fail("expected = after the key");
        i++;
        assign(table, path, value());
        endOfLine();
    }
}

// ---------------------------------------------------------------------------------------- writing
function keyText(k) { return /^[A-Za-z0-9_-]+$/.test(k) ? k : JSON.stringify(k); }
function scalarText(v) {
    if (typeof v === "string") return JSON.stringify(v);
    if (typeof v === "boolean") return v ? "true" : "false";
    if (typeof v === "number") return isFinite(v) ? String(v) : "0";
    if (Array.isArray(v)) return "[" + v.filter(x => x !== undefined && x !== null).map(scalarText).join(", ") + "]";
    if (isPlainObject(v)) {
        const parts = Object.keys(v).filter(k => v[k] !== undefined && v[k] !== null).map(k => keyText(k) + " = " + scalarText(v[k]));
        return parts.length ? "{ " + parts.join(", ") + " }" : "{}";
    }
    return "\"\"";
}

// The object as TOML: each table's own values first, then its sub-tables, in the order the keys
// have. `comments` maps a dotted table path ("window.panels") to a line of comment written above it;
// "" is the text at the very top. Empty tables and undefined/null values are left out.
function stringify(obj, comments) {
    const notes = comments || {};
    const out = [];
    if (notes[""]) for (const l of String(notes[""]).split("\n")) out.push("# " + l);
    function emit(table, path) {
        const keys = Object.keys(table).filter(k => table[k] !== undefined && table[k] !== null);
        const values = keys.filter(k => !isPlainObject(table[k]));
        const tables = keys.filter(k => isPlainObject(table[k]) && Object.keys(table[k]).length > 0);
        const dotted = path.map(keyText).join(".");
        if (path.length > 0 && (values.length > 0 || notes[path.join(".")])) {
            const own = notes[path.join(".")];
            // a blank line between blocks, except right under a comment written for the tables below
            if (out.length && (own || !/^# /.test(out[out.length - 1]))) out.push("");
            if (own) for (const l of String(notes[path.join(".")]).split("\n")) out.push("# " + l);
            if (values.length > 0) out.push("[" + dotted + "]");
        }
        for (const k of values) out.push(keyText(k) + " = " + scalarText(table[k]));
        for (const k of tables) emit(table[k], path.concat([k]));
    }
    emit(obj, []);
    return out.join("\n") + "\n";
}
