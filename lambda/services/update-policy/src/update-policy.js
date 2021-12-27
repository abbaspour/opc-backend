'use strict';

const { createGzip } = require('zlib');
const util = require('util');
const tar = require('tar-stream');
const stream = require('stream');
const AWS = require('aws-sdk');

AWS.config.update({region: "ap-southeast-2"});
/*
const credentials = new AWS.SharedIniFileCredentials({profile: 'opal'});
AWS.config.credentials = credentials;
*/

/*
AWS.config.loadFromPath('../iam.json');
const BUCKET    = 'opal-policy-dev';
*/

const s3 = new AWS.S3({apiVersion: '2006-03-01'});

const BUCKET    = process.env.BUCKET;

exports.handler = async (event, context) => {
    console.log("Reading options from event:\n", util.inspect(event, {depth: 5}));
    console.log("Reading options from context:\n", util.inspect(context, {depth: 5}));

    let account_no = event.Records[0].messageAttributes.account_no.stringValue;
    //let name = event.Records[0].messageAttributes.name.stringValue;
    let name = 'bundle';
    let policyPayload = event.Records[0].messageAttributes.payload.stringValue;

    console.log(`receive SQS for policy update account_no: ${account_no}, name: ${name}`);

    await uploadPolicyToS3(account_no, name, policyPayload);

    return {};
}

async function uploadPolicyToS3(account_no, name, policyPayload) {
    let policyFileName =  /*account_no + '/' +*/ name + '.rego';
    let policyS3Key =  account_no + '/' + name + '.tar.gz';

    console.log(`uploading policy account_no: ${account_no}, name: ${name}, policyFileName: ${policyFileName}, bucket: ${BUCKET}, policyS3Key: ${policyS3Key}, payload: ${policyPayload} `);
    const pack = tar.pack() // pack is a streams2 stream
    pack.entry({ name: policyFileName }, policyPayload);
    pack.finalize();

    const gzip = createGzip();
    const s3stream = mkS3Stream(BUCKET, policyS3Key);

    const ret = stream.pipeline(pack, gzip, s3stream,
        e => {
            if(e) {
                console.error('error streaming to s3', e);
                throw e;
            } else {
                console.log(`finished writing to s3 object: s3://${BUCKET}/${policyS3Key}`);

            }
        });


    await stream.finished(ret, e => {
        if(e) {
            console.error('error streaming finish', e);
            throw e;
        } else {
            console.log(`finished waiting to s3 object: s3://${BUCKET}/${policyS3Key}`);
        }
    });

    await listObjects(BUCKET);

}

async function listObjects(bucket) {
    const { Contents } = await s3.listObjectsV2({Bucket: bucket}).promise();
    console.log('s3 contents: ' , Contents);
}

function mkS3Stream(bucket, key) {
    let pass = new stream.PassThrough();

    let params = {Bucket: BUCKET, Key: key, Body: pass};
    s3.upload(params, function(err, data) {
        console.log(err, data);
    });

    return pass;
}

/*
(async() => {
    await uploadPolicyToS3('cli1', 'test7', 'some policy');
    await listObjects(BUCKET);
})();
*/
