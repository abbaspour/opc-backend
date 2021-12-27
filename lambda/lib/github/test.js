const AccountGitHub = require("./index");

(async () => {
    let account_no = 1236;

    const owner = "abbaspour";
    const repo = "opc-accounts";
    const personal_token = process.env.personal_token;

    const gh = new AccountGitHub(owner, repo, personal_token);

    try {
        let d = await gh.upload(account_no);
        console.log(d);
    } catch (e) {
        console.error(e);
    }
})();
