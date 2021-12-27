function defineGlobals(user, context, callback) {

    async function allocateAccountNo(user_id) {
        let accessToken = await getCachedAdminToken();
        //console.log('admin access token', accessToken);
        const axios = require('axios').default;

        const API_BASE_URL = configuration.API_BASE_URL;

        const instance = axios.create({
            baseURL: API_BASE_URL,
            timeout: 10000,
            headers: {'Authorization': 'Bearer ' + accessToken}
        });

        const response = await instance.post('/v1/account', {
            user_id: user_id
        });

        console.log('axios.post response', response.data);

        return response.data.account_no;
    }


    async function getCachedAdminToken() {
        if (!global.cache)
            global.cache = getNewCache();

        const token = global.cache.get('access_token');
        if (token) {
            console.log('HIT found access_token in cache');
            return token;
        }

        const {access_token, expires_in} = await getNewAdminToken();
        global.cache.set('access_token', access_token, expires_in * 1000);

        console.log('MIS added new access_token to cache');
        return access_token;
    }


    function getNewCache() {
        const LRU = require("lru-cache");
        const DAY_IN_MS = 1000 * 3600 * 24;
        const options = {max: 1, maxAge: DAY_IN_MS};
        return new LRU(options);
    }

    async function getNewAdminToken() {
        const NODE_AUTH0_VERSION = '2.31.0';

        const AuthenticationClient = require(`auth0@${NODE_AUTH0_VERSION}`).AuthenticationClient;

        const domain = 'id.openpolicy.cloud';

        const auth0 = new AuthenticationClient({
            domain: domain,
            clientId: configuration.client_id,
            clientSecret: configuration.client_secret
        });

        const AdminAudience = 'opc.admin';

        return auth0.clientCredentialsGrant({audience: AdminAudience, scope: 'create:account'});
    }

    if (!global.dumpContext) {
        global.dumpContext = function (u, c) {
            console.log('==== user ====');
            console.log('user: ' + JSON.stringify(u));
            console.log('==== context ====');
            console.log('context: ' + JSON.stringify(c));
        };
    }

    if (!global.allocateAndPersistAccountNo) {
        global.allocateAndPersistAccountNo = async function (user) {
            let account_no = await allocateAccountNo(user.user_id);
            let app_metadata = user.app_metadata || {};
            app_metadata.account_no = account_no;
            auth0.users.updateAppMetadata(user.user_id, app_metadata);
            return account_no;
        };
    }

    return callback(null, user, context);
}
