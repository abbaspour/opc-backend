import {
    DynamoDBClient,
    GetItemCommand,
    GetItemCommandInput, PutItemCommand,
    PutItemCommandInput
} from "@aws-sdk/client-dynamodb";
// import {fromIni} from "@aws-sdk/credential-provider-ini";

import AccountGitHub from "accounts-github";

import {APIGatewayProxyEventV2, APIGatewayProxyResultV2} from "aws-lambda";

const REGION = process.env.REGION || "ap-southeast-2";
const GITHUB_PERSONAL_TOKEN = process.env.GITHUB_PERSONAL_TOKEN;
const GITHUB_OWNER = process.env.GITHUB_OWNER;
const GITHUB_REPO = process.env.GITHUB_REPO;


const TABLE_NAME = "account";
const SHARD = 1000; // TODO: comes from shard table

const dbClient = new DynamoDBClient({
    region: REGION,
    // credentials: fromIni({profile: 'opc'})
});

const gh = new AccountGitHub(GITHUB_OWNER, GITHUB_REPO, GITHUB_PERSONAL_TOKEN);

const generator = function* (shard: number = SHARD) {
    while (true) yield (shard * 100_000) + Math.floor(Math.random() * 900_000 + 100_000);
}();

async function isTaken(accountNo: number): Promise<boolean> {

    const input: GetItemCommandInput = {
        TableName: TABLE_NAME,
        Key: {
            account_no: {N: `${accountNo}`}
        },
        ConsistentRead: true,
        AttributesToGet: ['account_no']
    };
    const data = await dbClient.send(new GetItemCommand(input));
    return !!data.Item;
}

async function take(accountNo: number, adminSub: string, shard: number = SHARD) {
    const input: PutItemCommandInput = {
        TableName: TABLE_NAME,
        Item: {
            account_no: {N: `${accountNo}`},
            shard: {N: `${shard}`},
            admin_sub: {S: `${adminSub}`},
            create_at: {S: `${new Date().toISOString()}`},
        },
    };

    await dbClient.send(new PutItemCommand(input));
}

async function allocateAccountNo(adminSub: string): Promise<number> {
    let overlap = true;
    let accountNo: number;

    do {
        accountNo = generator.next().value;
        overlap = await isTaken(accountNo);
    } while (overlap);

    await take(accountNo, adminSub);
    return accountNo;

}

function get_admin_user_id(event: APIGatewayProxyEventV2): string | undefined {
    if (!event.body)
        return undefined;

    let body = event.body;

    if (event.isBase64Encoded) {
        const buff = Buffer.from(event.body, 'base64');
        body = buff.toString('ascii');
    }

    const json = JSON.parse(body);
    return json.user_id;
}


const error = (msg: string) => ({
    statusCode: 401,
    headers: {'Content-Type': 'application/json'},
    body: JSON.stringify({error: 'unauthorized', error_message: msg})
});

export const handler = async (event: APIGatewayProxyEventV2): Promise<APIGatewayProxyResultV2> => {

    const claims = event.requestContext.authorizer?.jwt?.claims;
    if (!claims) return error('missing authorization context');

    if (claims.gty !== 'client-credentials') return error('only client-credentials grant allowed.');

    const adminUserId = get_admin_user_id(event);
    if (!adminUserId)
        return error('missing admin user_id in payload');

    try {
        const accountNo = await allocateAccountNo(adminUserId);
        console.log(`admin_user_id: ${adminUserId} -> account_no: ${accountNo}`);

        await gh.upload(accountNo);

        const body = JSON.stringify({'account_no': accountNo});

        const payload = {
            statusCode: 200,
            body,
            headers: {"Content-Type": "application/json"}
        };

        console.info(`response from: POST /v1/account: ${JSON.stringify(payload)}`);
        return payload;
    } catch (e) {
        console.error('exception on account create', e);

        return {
            statusCode: 500,
            body: JSON.stringify({error: 'internal', 'error_message': e.toString()}),
            headers: {"Content-Type": "application/json"}
        };
    }
};


/*
const run = async () => {
    // console.log('sample No: 100368421');
    // const accountNo = generator.next().value;
    const accountNo = await allocateAccountNo('CLI');
    console.log(`accountNo: ${accountNo}`);
};

run();
*/
