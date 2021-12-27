/**
 * ref: https://dev.to/lucis/how-to-push-files-programatically-to-a-repository-using-octokit-with-typescript-1nj0
 */
const {Octokit} = require("@octokit/rest");

exports.default = class AccountsGitHub {
    constructor(owner, repo, personal_token) {
        this.owner = owner;
        this.repo = repo;
        this.branch = 'main'

        this.octo = new Octokit({
            auth: personal_token
        });
    }

    async upload(account_no) {

        const content = AccountsGitHub.renderAccountFile(account_no);
        const pathForBlob = `account-${account_no}.tf`;
        const commitMessage = `commit account ${account_no}`;

        const currentCommit = await this.getCurrentCommit();
        const blob = await this.createBlobForContent(content);
        const newTree = await this.createNewTree(blob, pathForBlob, currentCommit.treeSha);
        const newCommit = await this.createNewCommit(commitMessage, newTree.sha, currentCommit.commitSha);

        await this.setBranchToCommit(newCommit.sha)
    }

    static renderAccountFile(account_no) {
        return `module "account-${account_no}" {
  source = "./modules/account"
  account_no = ${account_no}
  policy_bucket = var.policy_bucket
  region = var.region
  status_api_url = var.status_api_url
  ecs_cluster_arn = var.ecs_cluster_arn
  ecs_cluster_subnets = var.ecs_cluster_subnets
  ecs_sg_id = var.ecs_sg_id
  vpc_id = var.vpc_id
  listener_arn = var.listener_arn
}`;
    }

    async createNewCommit(message, currentTreeSha, currentCommitSha) {
        return (await this.octo.git.createCommit({owner: this.owner, repo: this.repo, message, tree: currentTreeSha, parents: [currentCommitSha]})).data
    }

    async createBlobForContent(content) {
        const blobData = await this.octo.git.createBlob({owner: this.owner, repo: this.repo, content, encoding: 'utf-8'});
        return blobData.data
    }

    async createNewTree(blob, path, parentTreeSha) {
        const tree = [{path: path, mode: `100644`, type: `blob`, sha: blob.sha}];
        const {data} = await this.octo.git.createTree({owner: this.owner, repo: this.repo, tree, base_tree: parentTreeSha});
        return data
    }

    async getCurrentCommit() {
        const {data: refData} = await this.octo.git.getRef({owner: this.owner, repo: this.repo, ref: `heads/${this.branch}`});
        const commitSha = refData.object.sha;
        const {data: commitData} = await this.octo.git.getCommit({owner: this.owner, repo: this.repo, commit_sha: commitSha,});
        return {commitSha, treeSha: commitData.tree.sha};
    }

    async setBranchToCommit(commitSha) {
        return this.octo.git.updateRef({owner: this.owner, repo: this.repo, ref: `heads/${this.branch}`, sha: commitSha});
    }
}

