const regex = /^\s*package\s+([\w.]+)\s*\n/;

//module.exports = class RegoParse {
module.exports = function (payload) {
        if(payload == null || payload.trim() === '') return '';

        const m = payload.match(regex);

        if(m === null || m.length < 1)
            return '';

        return m[1];
    };
//}

