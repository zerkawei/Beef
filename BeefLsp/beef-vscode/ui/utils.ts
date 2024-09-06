export function equals(a: any, b: any): boolean {
    const type = typeof a;
    if (type !== typeof b) return false;

    if (type === "object") {
        // Array
        const isArrayA = Array.isArray(a);
        const isArrayB = Array.isArray(b);

        if (isArrayA || isArrayB) {
            if (isArrayA && isArrayB) {
                if (a.length !== b.length) return false;
                return a.every((str, i) => equals(str, b[i]));
            }

            return false;
        }
        
        // Object
        let countA = 0;
        let countB = 0;

        for (const _ in a) countA++;
        for (const _ in b) countB++;

        if (countA !== countB) return false;

        for (const key in a) {
            if (!(key in b) || !equals(a[key], b[key])) return false;
        }
        for (const key in b) {
            if (!(key in a) || !equals(b[key], a[key])) return false;
        }

        return true;
    }

    return a === b;
}

export function clone<T>(a: T): T {
    const type = typeof a;

    if (type === "object") {
        // Array
        if (Array.isArray(a)) {
            const b: any[] = [];

            a.forEach(item => b.push(clone(item)));

            return b as T;
        }

        // Object
        const b: any = {};

        for (const key in a) {
            b[key] = clone(a[key]);
        }

        return b;
    }

    return a;
}