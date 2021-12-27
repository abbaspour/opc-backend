export default class AccountsGitHub {
    constructor(owner : string | undefined, repo : string | undefined, personal_token: string | undefined);
    upload(account_no : number) : Promise<any>;
}