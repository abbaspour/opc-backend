import {DescribeServicesCommand, DescribeTaskDefinitionCommand, ECSClient} from "@aws-sdk/client-ecs";

// import {fromIni} from "@aws-sdk/credential-provider-ini";
import {APIGatewayProxyEventV2, APIGatewayProxyResultV2} from "aws-lambda";

const REGION = process.env.REGION || "ap-southeast-2";
const AWS_ACCOUNT = process.env.AWS_ACCOUNT || "377258293252";


const ecs = new ECSClient({
    region: REGION,
    // credentials: fromIni({profile: 'opc'})
});

const cluster = (accountNo: number) => "opa-ecs-cluster"; // todo: account shard
const service = (accountNo: number) => `opa-${accountNo}`;

const serviceArn = (accountNo: number) => `arn:aws:ecs:${REGION}:${AWS_ACCOUNT}:service/${cluster(accountNo)}/${service(accountNo)}`;

type ServiceStatus = 'ACTIVE' | 'DRAINING' | 'INACTIVE';

class Instance {
    constructor(readonly name: string | undefined,
                readonly status: ServiceStatus,
                readonly runningCount: number = 0,
                readonly pendingCount: number = 0,
                readonly bundleId: string | undefined /*Bundle[]*/) {
    }
}

// tslint:disable-next-line:max-classes-per-file
class Bundle {
    constructor(readonly id : string) {
    }
}

const listInstances = async (accountNo: number): Promise<Instance[] | undefined> => {
    const command = new DescribeServicesCommand({cluster: cluster(accountNo), services: [serviceArn(accountNo)]});
    const services = await ecs.send(command);
    // console.log(JSON.stringify(services, null, ' '));
    if(! services.services )
        return undefined;

    const instances : Promise<Instance[]> =  Promise.all(services.services.map( async (s) => {
        const { taskDefinition } = s;
        const taskDefCmd = new DescribeTaskDefinitionCommand({taskDefinition});
        const taskDefRsp = await ecs.send(taskDefCmd);
        // console.log('taskDefRsp ' + JSON.stringify(taskDefRsp, null, ' '));
        const rootBundle = taskDefRsp.taskDefinition?.containerDefinitions?.[0].entryPoint?.find( e => e.startsWith('bundles.root.resource='))?.split('/').pop();
        const bundle = rootBundle ? [new Bundle(rootBundle)] : undefined;
        return new Instance(s.serviceName, s.status as ServiceStatus, s.runningCount, s.pendingCount, /*bundle*/rootBundle);
    }));

    return instances;
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

    const instances = await listInstances(accountNo);

    console.log('instances: '  + JSON.stringify(instances));

    return {
        statusCode: 200,
        body: JSON.stringify(instances),
        headers: {
            "Content-Type": "application/json",
            "Access-Control-Allow-Origin": "*"
        }
    };
};

/*
const run = async () => {
    const result = await listInstances(100368421);
    console.log(JSON.stringify(result));
};

run();
*/
