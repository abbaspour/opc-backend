// todo: type script
'use strict';

const {DynamoDBClient, BatchWriteItemCommand} = require("@aws-sdk/client-dynamodb");
const util = require('util');

const REGION = process.env.REGION || "ap-southeast-2";

const ddb = new DynamoDBClient({
    region: REGION,
    // credentials: fromIni({profile: 'opc'})
});

exports.handler = async (event/*, context*/) => {

    console.log("Reading options from event:\n", util.inspect(event, {depth: 5}));
    //console.log("Reading options from context:\n", util.inspect(context, {depth: 5}));

    const status = [];

    for (const r of event.Records) {
        console.log('processing record: ', r);

        try {
            const body = JSON.parse(r.body);

            //console.log('parsed body: ', body);
            const { params: { account_no }, status: { bundles }} = body;

            if (!account_no || !bundles) {
                console.log('skipping, no account_no or bundles info in status.');
                continue;
            }

            status.push({ account_no : account_no, bundles : Object.values(bundles)[0] }); // TODO: fix [0]

        } catch (e) {
            console.warn('unable to json parse status message', e);
        }

    }

    if (status.length > 0)
        await insert_status(status);

    return {};
}

async function insert_status(status) {

    console.log('inserting follow status: ', status);

    const values /*: PutRequest[]*/ = [];
    for (const r of status) {
        // [s.name, s.last_request, s.last_successful_activation, s.last_successful_download, s.last_successful_request]
        const { account_no, bundles: s } = r;
        //for (const s of Object.entries(bundles)) {
            values.push(
                {
                    PutRequest: {
                        Item: {
                            "name": {"S": s.name},
                            "account_no": {"N": `${account_no}`},
                            "last_request": {"S": s.last_request},
                            "last_successful_activation": {"S": s.last_successful_activation},
                            "last_successful_download": {"S": s.last_successful_download},
                            "last_successful_request": {"S": s.last_successful_request}
                        }
                    }
                }
            );
        //}
    }


    const params /*: BatchWriteItemCommandInput*/ = {RequestItems: { "bundle_status": values}};

    console.log('inserting follow command input ', JSON.stringify(params));

    await ddb.send(new BatchWriteItemCommand(params));
}
