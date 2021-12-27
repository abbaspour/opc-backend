async function attachAccountNo(user, context, callback) {
    global.dumpContext(user, context);

    let app_metadata = user.app_metadata || {};

    let account_no = app_metadata.account_no;

    if(!account_no) {
        account_no = await global.allocateAndPersistAccountNo(user);
    }

    context.idToken['https://opc.ns/account_no'] = account_no;
    context.accessToken['https://opc.ns/account_no'] = account_no;

    return callback(null, user, context);
}
