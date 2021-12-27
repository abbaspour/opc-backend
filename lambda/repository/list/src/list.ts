import {ListObjectsCommand, S3Client} from '@aws-sdk/client-s3';
import {APIGatewayProxyEvent, APIGatewayProxyResult} from 'aws-lambda';

const REGION = process.env.REGION || 'ap-southeast-2';

// Create the parameters for the bucket
const Bucket = process.env.BUCKET || 'opal-policy-dev';
const Type = process.env.TYPE as RepositoryType;

type RepositoryType = 'bundles' | 'policies';

// import {fromIni} from "@aws-sdk/credential-provider-ini";

const s3 = new S3Client({
    region: REGION,
    // credentials: fromIni({profile: 'opc'})
});

class Content {
    constructor(readonly name: string | undefined, readonly lastModified: Date | undefined, readonly etag: string | undefined, readonly size: number | undefined) {
    }
}

const mkPrefix = (accountNo: number, type: RepositoryType) => `${accountNo}/${type}/`;

const mkListCommand = (Prefix: string) => new ListObjectsCommand({
    Bucket,
    // Delimiter: '/',
    Prefix
});

const trimPrefix = (Key: string | undefined, Prefix: string) => Key && Key.substring(Prefix.length);

const noQuote = (str: string | undefined) => (str || '').replace(/['"]+/g, '');

// TODO: handle truncate
const list = async (accountNo: number, type: RepositoryType): Promise<Content[] | undefined> => {
    const prefix = mkPrefix(accountNo, type);
    console.log(`s3 listing s3://${Bucket}/${prefix}`);

    try {
        const data = await s3.send(mkListCommand(prefix));
        console.log(`s3 listing s3://${Bucket}/${prefix} data: ${JSON.stringify(data)}`);
        return data.Contents?.filter(c => c.Size && c.Size > 0 && c.Key).map(v => new Content(trimPrefix(v.Key, prefix), v.LastModified, noQuote(v.ETag), v.Size));
    } catch (err) {
        console.log('Error', err);
    }
};

const error = (msg: string) => ({
    statusCode: 401,
    headers: {'Content-Type': 'application/json'},
    body: JSON.stringify({error: 'unauthorized', error_message: msg})
});

export const handler = async (event: APIGatewayProxyEvent): Promise<APIGatewayProxyResult> => {

    const accountNo = event.requestContext?.authorizer?.account_no;
    if (!accountNo)
        return error('missing account_no');

    const contents = await list(accountNo, Type);
    const body = JSON.stringify(contents);

    console.log(`list repo entries of type '${Type}' for account_no ${accountNo}: ${body}`);

    return {
        statusCode: 200,
        body,
        headers: {
            'Content-Type': 'application/json',
            'Access-Control-Allow-Origin': '*'
        }
    };
};

/*
const run = async () => {

    const bundles = await list(100368421, 'bundles');
    const obj = {[keyOf('bundles' as RepositoryType)]: bundles};
    console.log(JSON.stringify(obj));

    const policies = await list(100368421, 'policies');
    console.log('Content:');
    console.log(JSON.stringify(policies));
};

run();
*/
