import * as util from "util";
import {
    APIGatewayProxyEvent,
    APIGatewayProxyResult,
    SQSEvent
} from "aws-lambda";

import {
    CopyObjectCommand,
    GetObjectCommand,
    GetObjectCommandOutput,
    S3Client
} from "@aws-sdk/client-s3";

// import {fromIni} from "@aws-sdk/credential-provider-ini";

const REGION = process.env.REGION || "ap-southeast-2";

const s3 = new S3Client({
    region: REGION,
    // credentials: fromIni({profile: 'opc'})
});

import * as tar from "tar-stream";
import * as stream from "stream";

import * as fs from "fs";
import {createGunzip, createGzip} from "zlib";

import {Upload} from "@aws-sdk/lib-storage";

const BUCKET = process.env.BUCKET || 'opal-policy-dev';

/*
import AWS from "aws-sdk";
AWS.config.update({region: "ap-southeast-2"});
const credentials = new AWS.SharedIniFileCredentials({profile: 'opc'});
AWS.config.credentials = credentials;
const s3v2 = new AWS.S3({apiVersion: '2006-03-01'});
*/

const now = () => new Date().toISOString().replace(/[:.]/g, '-');
const mkBckBundleKey = (accountNo: number) => `${accountNo}/backup/bundle-${now()}.tar.gz`;

/**
 * steps:
 * 1. create a new temp bundle-sync-$DATE.tar.gz in s3
 * 2. for all policies for account
 *  2.a. add policy to temp bundle file from policies
 * 3. close stream to temp bundle
 * 4. cp temp bundle over existing bundle.tar.gz
 */

const bundleKey = (accountNo: number, bundle: string = 'bundle.tar.gz') => `${accountNo}/bundles/${bundle}`;
const policyKey = (accountNo: number, policy: string) => `${accountNo}/policies/${policy}`;

const mkS3OutputStream = (key: string): { pass: stream.Writable, upload: Upload } => {
    const pass = new stream.PassThrough();

    console.log(`uploading to s3://${BUCKET}/${key}`);

    const params = {Bucket: BUCKET, Key: key, Body: pass};

    // https://www.npmjs.com/package/@aws-sdk/lib-storage

    const upload = new Upload({
        client: s3,
        leavePartsOnError: false, // optional manually handle dropped parts
        params
    });

    upload.on("httpUploadProgress", (progress) => {
        console.log(progress);
    });

    /*
    s3v2.upload(params, (err: Error, data: SendData) => {
        console.log(err, data);
    });
    */

    return {pass, upload};
};

const addContentToBundle = async (accountNo: number, adding: boolean, content: string, sourceKey: string, bundle: string = 'bundle.tar.gz'): Promise<void> => {

    const input = adding ? await mkS3InputStream(policyKey(accountNo, content)) : { size: 0, stream: fs.createReadStream('/dev/null') };

    const outputStream = mkS3OutputStream(bundleKey(accountNo, bundle));

    const pack = tar.pack();
    pack.pipe(createGzip()).pipe(outputStream.pass);

    const bundleContent = await mkS3TarGzInputStream(sourceKey);

    return new Promise((accept) => {
        let overwrite = false;

        bundleContent.on('entry', ((headers, bs, next) => {
            console.log(`working on bundle entry: ${headers.name}`);
            if (headers.name === content) {
                if(adding) {
                    console.log('overwriting content: ' + content);
                    const entry = pack.entry({name: content, size: input.size}, err => {
                        console.log(err);
                        pack.finalize();
                    });
                    input.stream.pipe(entry);
                    overwrite = true;
                } else {
                    console.log('skipping deleted content: ' + content);
                }
                next();
            } else {
                bs.pipe(pack.entry(headers, next));
            }
            // bs.on('end', () => {next();});
            bs.resume();
        }));

        bundleContent.on('finish', async () => {
            console.log('reached end of bundle content');
            if (!overwrite && adding) {
                console.log('no overwrite. writing new file: ' + content);
                const entry = pack.entry({name: content, size: input.size}, err => {
                    console.log(err);
                    pack.finalize();
                });
                input.stream.pipe(entry);
            }
            pack.finalize();
            await outputStream.upload.done();
            accept();
        });
    });
};

const makeBackup = async (accountNo: number, /*tmpBundleKey: string,*/ bundle: string = 'bundle.tar.gz') : Promise<string> => {
    const backupKey = mkBckBundleKey(accountNo);
    const main = bundleKey(accountNo, bundle);

    console.log(`backing up ${main} to ${backupKey}`);
    await s3.send(new CopyObjectCommand({Bucket: BUCKET, CopySource: `${BUCKET}/${main}`, Key: backupKey}));

    return backupKey;
};

const mkS3InputStream = async (key: string): Promise<{ size: number, stream: stream.Readable }> => {
    console.log(`downloading from s3://${BUCKET}/${key}`);

    const command = new GetObjectCommand({
        Bucket: BUCKET,
        Key: key
    });

    const resp: GetObjectCommandOutput = await s3.send(command);

    const fileStream = resp.Body!;

    if (!fileStream || !(fileStream instanceof stream.Readable))
        throw new Error('Unknown object stream type.');

    return {size: resp.ContentLength || 0, stream: fileStream};
};

const mkS3TarGzInputStream = async (key: string): Promise<tar.Extract> =>
    (await mkS3InputStream(key)).stream.pipe(createGunzip()).pipe(tar.extract());


const listBundleContent = async (accountNo: number, bundle: string = 'bundle.tar.gz') =>
    listTarGzStreamContent(await mkS3TarGzInputStream(bundleKey(accountNo, bundle)));

const listTarGzStreamContent = async (s: tar.Extract): Promise<string[]> =>
    new Promise((accept) => {
        const files: string[] = [];
        s.on('entry', (header, st, next) => {
            // console.log(header);
            if (header?.type === 'file')
                files.push(header.name);
            st.on('end', () => {
                next();
            });
            st.resume();
        });
        s.on('finish', () => accept(files));
    });

type Method = 'POST' | 'DELETE';

exports.handler = async (event: SQSEvent) => {
    console.log("Reading options from event:\n", util.inspect(event, {depth: 5}));
    // console.log("Reading options from context:\n", util.inspect(context, {depth: 5}));

    const body = JSON.parse(event.Records[0].body);

    const {account_no, bundle, content, method}: { account_no: number, bundle: string, content: string, method : Method } = body;

    console.log(`receive SQS for bundle sync for account_no: ${account_no} on ${bundle} for content ${content}`);

    const bckKey = await makeBackup(account_no);
    console.log(`back up at: ${bckKey}`);
    await addContentToBundle(account_no, method === 'POST', content, bckKey);

    return {};
};

const error = (msg: string) => ({
    statusCode: 401,
    headers: {'Content-Type': 'application/json'},
    body: JSON.stringify({error: 'unauthorized', error_message: msg})
});

exports.getHandler = async (event: APIGatewayProxyEvent): Promise<APIGatewayProxyResult> => {

    const accountNo = event.requestContext?.authorizer?.account_no;
    if (!accountNo)
        return error('missing account_no');

    console.log(`receive bundle get content for account ${accountNo}`);
    const files = await listBundleContent(accountNo);

    return {
        statusCode: 200,
        body: JSON.stringify(files),
        headers: {
            "Content-Type": "application/json",
            "Access-Control-Allow-Origin": "*"
        }
    };

};

/*
const mkFsInputStream = (file: string) => fs.createReadStream(file).pipe(createGunzip()).pipe(tar.extract());

const ACCOUNT_NO = 100368421;

const run = async () => {
    const bckKey = await makeBackup(ACCOUNT_NO);
    console.log(`back up at: ${bckKey}`);
    await addContentToBundle(ACCOUNT_NO, 'opa/examples/sample-policy.rego', bckKey);
};

run().then(() => console.log('done')).catch((e) => console.log('error', e)).finally(() => console.log('finished'));
*/
