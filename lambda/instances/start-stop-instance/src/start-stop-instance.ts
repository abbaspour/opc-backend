import {
    ECSClient, ListTasksCommand,
    StopTaskCommand,
    UpdateServiceCommand
} from '@aws-sdk/client-ecs';

// import {fromIni} from '@aws-sdk/credential-provider-ini';
import {APIGatewayProxyEventV2, APIGatewayProxyResultV2} from 'aws-lambda';

const REGION = process.env.REGION || 'ap-southeast-2';
// const AWS_ACCOUNT = process.env.AWS_ACCOUNT || '377258293252';


const ecs = new ECSClient({
    region: REGION,
    // credentials: fromIni({profile: 'opc'})
});

// eslint-disable-next-line @typescript-eslint/no-unused-vars
const clusterByAccount = (accountNo: number) => 'opa-ecs-cluster'; // todo: account shard
const service = (accountNo: number) => `opa-${accountNo}`;

const startStopInstance = async (accountNo: number, doStart: boolean): Promise<void> => {
    await ecs.send(new UpdateServiceCommand({
        cluster: clusterByAccount(accountNo),
        service: service(accountNo),
        desiredCount: doStart ? 1 : 0
    }));
    if (!doStart) await stopAnyRunningTasks(accountNo);
};

const stopAnyRunningTasks = async (accountNo: number): Promise<void> => {
    const cluster = clusterByAccount(accountNo);
    const listTasksCommand = new ListTasksCommand({cluster, serviceName: service(accountNo)});
    const tasks = await ecs.send(listTasksCommand);
    if (!tasks.taskArns) return;
    for await (const task of tasks.taskArns) {
        await ecs.send(new StopTaskCommand({task, cluster}));
    }
};

const error = (msg: string) => ({
    statusCode: 401,
    headers: {'Content-Type': 'application/json'},
    body: JSON.stringify({error: 'unauthorized', error_message: msg})
});

export const handler = async (event: APIGatewayProxyEventV2): Promise<APIGatewayProxyResultV2> => {

    const claims = event.requestContext.authorizer?.jwt?.claims;
    if (!claims) return error('missing authorization context');

    const accountNo = claims['https://opc.ns/account_no'] as number;
    if (!accountNo) return error('missing account_no claim');

    console.log(`event: ${JSON.stringify(event)}`);

    const doStart = event.rawPath === '/v1/instances/start';

    await startStopInstance(accountNo, doStart);

    return {
        statusCode: 200,
        body: JSON.stringify({start: doStart}),
        headers: {
            'Content-Type': 'application/json',
            'Access-Control-Allow-Origin': '*'
        }
    };
};

/*
const run = async () => {
    await startStopInstance(100368421, false);
};

run();
*/
