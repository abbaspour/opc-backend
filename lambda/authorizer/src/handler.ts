import {APIGatewayAuthorizerEvent, APIGatewayAuthorizerResult} from "aws-lambda";
import {decode, JsonWebTokenError, TokenExpiredError, verify} from "jsonwebtoken";
import {APIGatewayRequestAuthorizerEvent} from "aws-lambda/trigger/api-gateway-authorizer";

if (!process.env.AUDIENCE || !process.env.TOKEN_ISSUER || !process.env.PUBLIC_KEY) {
    console.log('[error] set environment value JWKS_URI, AUDIENCE, TOKEN_ISSUER, PUBLIC_KEY');
    process.exit();
}

const AUDIENCE = process.env.AUDIENCE;
const PUBLIC_KEY = process.env.PUBLIC_KEY;
const TOKEN_ISSUER = process.env.TOKEN_ISSUER;

// https://dev.classmethod.jp/articles/lambda-authorizer-verify-token-from-auth0/

// extract and return the Bearer Token from the Lambda event parameters
function getBearerToken(params: APIGatewayAuthorizerEvent): string {
    if (!params.type /*|| params.type !== 'REQUEST' || !params.headers*/) {
        throw new Error('Expected "event.type" parameter');
    }

    let tokenString;

    if(params.type === 'REQUEST' && params.headers)
        tokenString = params.headers.authorization;
    else if(params.type === 'TOKEN')
        tokenString = params.authorizationToken;
    else
        throw new Error('Unexpected params.type: ' + params.type);

    if (!tokenString) {
        throw new Error('Expected "event.authorizationToken" parameter to be set');
    }

    const match = tokenString.match(/^Bearer (.*)$/);
    if (!match || match.length < 2) {
        throw new Error(`Invalid Authorization token - ${tokenString} does not match "Bearer .*"`);
    }
    return match[1];
}

async function verifyToken(token: string): Promise<number> {
    const decoded = decode(token, {complete: true});

    if (decoded == null || typeof decoded === 'string') {
        throw new JsonWebTokenError('invalid token');
    }

    const kid = decoded.header.kid;
    if (!kid) {
        throw new JsonWebTokenError('invalid token');
    }

    console.log(`kid: ${kid}`);

    // console.log(`signingKey: ${signingKey}`);

    let decodedToken : object | string;

    try {
        decodedToken = await verify(token, PUBLIC_KEY, {audience: AUDIENCE, issuer: TOKEN_ISSUER});
    } catch (err) {
        if (err instanceof TokenExpiredError) {
            throw new Error('token expired');
        }
        if (err instanceof JsonWebTokenError) {
            throw new Error('token is invalid');
        }
        throw err;
    }

    if(typeof decodedToken === "string")
        throw new Error('invalid decoded result');

    // TODO: fix this
    // @ts-ignore
    const { 'https://opc.ns/account_no' : accountNo } = decodedToken;
    if(!accountNo)
        throw new Error('token missing account_no claim');

    return accountNo;
}

function generatePolicy(effect: 'Allow' | 'Deny', resource: string, accountNo : number, prefix : string): APIGatewayAuthorizerResult {
    return {
        principalId: '*', // principalId
        policyDocument: {
            Version: '2012-10-17',
            Statement: [
                // todo: extend this in favor of TTL = 0
                // https://www.goingserverless.com/blog/api-gateway-authorization-and-policy-ccaching
                {
                    Action: 'execute-api:Invoke',
                    Effect: effect,
                    Resource: resource,
                },
            ],
        },
        context: {
            account_no: accountNo,
            prefix
        }
    };
}

function getPrefixByPath(accountNo: number, path: string) : string {
    if(path.startsWith('/v1/bundles') || path.startsWith('/repository/v1/bundles')) return `${accountNo}/bundles/`;
    if(path.startsWith('/v1/policies') || path.startsWith('/repository/v1/policies')) return `${accountNo}/policies/`;
    if(path.startsWith('/v1/data') || path.startsWith('/repository/v1/data')) return `${accountNo}/data/`;
    return 'NA';
    // throw new Error('unsupported path: ' + path);
}

export async function authorize(event: APIGatewayAuthorizerEvent): Promise<APIGatewayAuthorizerResult> {

    console.log('jwt authorizer event: ' + JSON.stringify(event));

    try {
        const token = getBearerToken(event);

        const accountNo = await verifyToken(token);
        console.log('account_no: ' + accountNo);

        const prefix = "path" in event ? getPrefixByPath(accountNo, event.path) : '';
        console.log('prefix: ' + prefix);

        const policy = generatePolicy('Allow', event.methodArn, accountNo, prefix);
        console.log('result policy: ' + JSON.stringify(policy));
        return policy;
    } catch (err) {
        console.log('error in authorize', err);
        return generatePolicy('Deny', event.methodArn, -1, '');
    }
}
