import {APIGatewayProxyEventV2, APIGatewayProxyResultV2} from "aws-lambda";
import {AuthenticationClient} from 'auth0';
import * as qs from 'querystring';

const AUTH0_DOMAIN = process.env.AUTH0_DOMAIN;
const AUTH0_CLIENT_ID = process.env.AUTH0_CLIENT_ID;
const AUTH0_CLIENT_SECRET = process.env.AUTH0_CLIENT_SECRET;
const AUTH0_CONNECTION = process.env.AUTH0_CONNECTION;
const AUDIENCE = process.env.AUDIENCE;

if(!AUTH0_DOMAIN)
    throw new Error('AUTH0_DOMAIN undefined');

const auth0 = new AuthenticationClient({
    domain: AUTH0_DOMAIN,
    clientId: AUTH0_CLIENT_ID,
    clientSecret: AUTH0_CLIENT_SECRET,
});

const error = (msg: string) => ({
    statusCode: 401,
    headers: {'Content-Type': 'application/json'},
    body: JSON.stringify({error: 'unauthorized', error_message: msg})
});

async function authenticate(username: string, password: string) {
    const options = {
        username,
        password,
        audience: AUDIENCE,
        scope: 'read:policies read:instances get:data',
        realm: AUTH0_CONNECTION
    };

    console.log(`authenticate with: ${JSON.stringify(options)}`);

    const response = await auth0.passwordGrant(options);

    console.log(`authenticate response: ${JSON.stringify(response)}`);

    return {
        statusCode: 200,
        headers: {'Content-Type': 'application/json'},
        body: JSON.stringify(response)
    };

}

export const handler = async (event: APIGatewayProxyEventV2): Promise<APIGatewayProxyResultV2> => {

    const isBase64Encoded = event.isBase64Encoded;
    if (!event.body) return error('missing request payload');

    const authorization = event?.headers?.authorization;
    if(!authorization)
        return error('missing grant_type');

    const decoded = Buffer.from(authorization.split(' ')[1], "base64").toString('ascii');

    const body = isBase64Encoded ? Buffer.from(event.body, 'base64').toString() : event.body;

    console.log('token input: ' + body);
    const params = qs.parse(body);

    const {grant_type} = params;
    if(!grant_type)
        return error('missing grant_type');

    if(grant_type !== 'client_credentials')
        return error('invalid grant_type ' + grant_type);

    const [clientId, clientSecret] = decoded.split(':');

    if (!clientId || !clientSecret) return error('missing client_id or client_secret');

    return authenticate(clientId, clientSecret);
};

/*
async function main() {
    // @ts-ignore
    const event : APIGatewayProxyEventV2 = {
        version: "2.0",
        routeKey: "/token",
        headers: {
            authorization: 'basic cGhpNkFpbm9vdGV4OkllR2FoZmltMmRpNA='
        },
        rawPath: "/token",
        rawQueryString: "",
        isBase64Encoded: true,
        body: 'Z3JhbnRfdHlwZT1jbGllbnRfY3JlZGVudGlhbHM='
    };

    const rsp = await handler(event);
    // const rsp = await authenticate('phi6Ainootex', 'IeGahfim2di4');
    console.log(rsp);
}

main();
*/
