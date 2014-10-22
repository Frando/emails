americano = require 'americano-cozy'

# Public: Account
# a {JugglingDBModel} for an account
class Account # make biscotto happy

module.exports = Account = americano.getModel 'Account',
    label: String               # human readable label for the account
    name: String                # user name to put in sent mails
    login: String               # IMAP & SMTP login
    password: String            # IMAP & SMTP password
    accountType: String         # "IMAP" or "TEST"
    smtpServer: String          # SMTP host
    smtpPort: Number            # SMTP port
    smtpSSL: Boolean            # Use SSL
    smtpTLS: Boolean            # Use STARTTLS
    imapServer: String          # IMAP host
    imapPort: Number            # IMAP port
    imapSSL: Boolean            # Use SSL
    imapTLS: Boolean            # Use STARTTLS
    inboxMailbox: String        # INBOX Maibox id
    draftMailbox: String        # \Draft Maibox id
    sentMailbox: String         # \Sent Maibox id
    trashMailbox: String        # \Trash Maibox id
    junkMailbox: String         # \Junk Maibox id
    allMailbox: String          # \All Maibox id
    favorites: (x) -> x         # [String] Maibox id of displayed boxes
    mailboxes: (x) -> x         # [BLAMEJDB] mailboxes should not saved

# There is a circular dependency between ImapProcess & Account
# node handle if we require after module.exports definition
nodemailer  = require 'nodemailer'
Mailbox     = require './mailbox'
ImapProcess = require '../processes/imap_processes'
Promise     = require 'bluebird'
Message     = require './message'
{AccountConfigError} = require '../utils/errors'
log = require('../utils/logging')(prefix: 'models:account')

# @TODO : import directly ?
SMTPConnection = require 'nodemailer/node_modules/' +
    'nodemailer-smtp-transport/node_modules/smtp-connection'

# Public: refresh all accounts
#
# Returns {Promise} for task completion
Account.refreshAllAccounts = ->
    allAccounts = Account.requestPromised 'all'
    Promise.serie allAccounts, (account) ->
        if not (account.accountType is 'TEST')
            ImapProcess.fetchAccount account

# Public: refresh this account
#
# Returns a {Promise} for task completion
Account::fetchMails = ->
    if not (account.accountType is 'TEST')
        ImapProcess.fetchAccount this

# Public: include the mailboxes tree on this account instance
#
# Returns {Promise} for the account itself
Account::includeMailboxes = ->
    Mailbox.getClientTree @id
    .then (mailboxes) =>
        @mailboxes = mailboxes
    .return this

# Public: fetch the mailbox tree of a new {Account}
# if the fetch succeeds, create the account and mailbox in couch
#
# data - account parameters
#
# Returns {Promise} promise for the created {Account}, boxes included
Account.createIfValid = (data) ->

    if not (data.accountType is 'TEST')
        Account.testSMTPConnection data
        .then (err) ->
            ImapProcess.fetchBoxesTree data

        .then (rawBoxesTree) ->
            # We managed to get boxes, login settings are OK
            # create Account and Mailboxes
            log.info "GOT BOXES", rawBoxesTree

            Account.createPromised data
            .then (account) ->
                Mailbox.createBoxesFromImapTree account.id, rawBoxesTree
                .then (specialUses) ->
                    account.updateAttributesPromised specialUses

        .then (account) ->

            # in a detached chain, fetch the Account
            # first fetch 100 mails from each box
            ImapProcess.fetchAccount account, 100
            # then fectch the rest
            .then -> ImapProcess.fetchAccount account
            .catch (err) -> console.log "FETCH MAIL FAILED", err

            return account.includeMailboxes()
    else
        log.info "TEST ACCOUNT"
        Account.createPromised data
        .then (account) ->
            Mailbox.createBoxesFromImapTree account.id, null
            .then (specialUses) ->
                account.updateAttributesPromised specialUses

        .then (account) ->

            return account.includeMailboxes()

# Public: send a message using this account SMTP config
#
# message - a raw message
# callback - a (err, info) callback with the following parameters
#            :err
#            :info the nodemailer's info
#
# Returns void
Account::sendMessage = (message, callback) ->
    transport = nodemailer.createTransport
        port: @smtpPort
        host: @smtpServer
        auth:
            user: @login
            pass: @password

    transport.sendMail message, callback

# Private: check smtp credentials
# used in createIfValid
# throws AccountConfigError
#
# Returns a {Promise} that reject/resolve if the credentials are corrects
Account.testSMTPConnection = (data) ->

    # we need a smtp server in tests
    # disable this for now
    return Promise.resolve('ok') if Account.testHookDisableSMTPCheck

    connection = new SMTPConnection
        port: data.smtpPort
        host: data.smtpServer

    auth =
        user: data.login
        pass: data.password

    return new Promise (resolve, reject) ->
        connection.once 'error', (err) ->
            console.log "ERROR CALLED"
            reject new AccountConfigError 'smtpServer'

        # in case of wrong port, the connection takes forever to emit error
        setTimeout ->
            reject new AccountConfigError 'smtpPort'
            connection.close()
        , 10000

        connection.connect (err) ->
            if err then reject new AccountConfigError 'smtpServer'
            else connection.login auth, (err) ->
                if err then reject new AccountConfigError 'auth'
                else resolve 'ok'
                connection.close()

# Public: destroy an account and all messages within
# returns fast after destroying account
# in the background, proceeds to erase all boxes & message
#
# Returns a {Promise} for account destroyed completion
Account::destroyEverything = ->
    accountDestroyed = @destroyPromised()

    accountID = @id

    # this runs in the background
    accountDestroyed.then ->
        Mailbox.rawRequestPromised 'treemap',
            startkey: [accountID]
            endkey: [accountID, {}]

    .map (row) ->
        new Mailbox(id: row.id).destroy()
        .catch (err) -> log.warn "FAIL TO DELETE BOX", row.id

    .then ->
        Message.safeDestroyByAccountID accountID

    # return as soon as the account is destroyed
    # (the interface will be correct)
    return accountDestroyed



Promise.promisifyAll Account, suffix: 'Promised'
Promise.promisifyAll Account::, suffix: 'Promised'
