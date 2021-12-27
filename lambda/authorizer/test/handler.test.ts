import {expect} from 'chai';
import {APIGatewayAuthorizerEvent, APIGatewayAuthorizerResult} from "aws-lambda";

const AUTH0_DOMAIN = 'id.openpolicy.cloud';

process.env.TOKEN_ISSUER = `https://${AUTH0_DOMAIN}/`;
process.env.JWKS_URI = `https://${AUTH0_DOMAIN}/.well-known/jwks.json`;
process.env.AUDIENCE = 'opc.api';
process.env.PUBLIC_KEY = '123';

import {authorize} from '../src/handler';
import {APIGatewayRequestAuthorizerEvent} from "aws-lambda/trigger/api-gateway-authorizer";
import {readFileSync} from 'fs';
import {join} from 'path';

describe('authorize', () => {
    it('should accept valid jwt', async () => {
        const event: APIGatewayRequestAuthorizerEvent = JSON.parse(readFileSync( join(__dirname, './request.json')).toString());
        const result = await authorize(event);
        const expectedPolicy: APIGatewayAuthorizerResult = {
            principalId: '*',
            policyDocument: {
                Version: '2012-10-17',
                Statement: [{
                    Action: 'execute-api:Invoke',
                    Effect: 'Deny',
                    Resource: 'arn:aws:execute-api:ap-southeast-2:377258293252:0vghplwa7g/stg/GET/discovery',
                }
                ]
            }
        };

        console.log(JSON.stringify(result));
        console.log(JSON.stringify(expectedPolicy));
        expect(result).to.eql(expectedPolicy);
    });
});
