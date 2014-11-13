XHRUtils = require '../utils/xhr_utils'
AppDispatcher = require '../app_dispatcher'
{ActionTypes} = require '../constants/app_constants'

AccountStore = require '../stores/account_store'
LayoutActionCreator = null

module.exports = AccountActionCreator =

    create: (inputValues, afterCreation) ->
        AccountActionCreator._setNewAccountWaitingStatus true

        XHRUtils.createAccount inputValues, (error, account) ->
            if error? or not account?
                AccountActionCreator._setNewAccountError error
            else
                AppDispatcher.handleViewAction
                    type: ActionTypes.ADD_ACCOUNT
                    value: account

                afterCreation(AccountStore.getByID account.id)


    edit: (inputValues, accountID) ->
        AccountActionCreator._setNewAccountWaitingStatus true

        account = AccountStore.getByID accountID
        newAccount = account.mergeDeep inputValues

        XHRUtils.editAccount newAccount, (error, rawAccount) ->
            if error?
                AccountActionCreator._setNewAccountError error
            else
                AppDispatcher.handleViewAction
                    type: ActionTypes.EDIT_ACCOUNT
                    value: rawAccount
                LayoutActionCreator = require '../actions/layout_action_creator'
                LayoutActionCreator.notify t('account updated'), autoclose: true

    remove: (accountID) ->
        AppDispatcher.handleViewAction
            type: ActionTypes.REMOVE_ACCOUNT
            value: accountID
        XHRUtils.removeAccount accountID
        window.router.navigate '', true

    _setNewAccountWaitingStatus: (status) ->
        AppDispatcher.handleViewAction
            type: ActionTypes.NEW_ACCOUNT_WAITING
            value: status

    _setNewAccountError: (errorMessage) ->
        AppDispatcher.handleViewAction
            type: ActionTypes.NEW_ACCOUNT_ERROR
            value: errorMessage

    selectAccount: (accountID, mailboxID) ->
        AppDispatcher.handleViewAction
            type: ActionTypes.SELECT_ACCOUNT
            value:
                accountID: accountID
                mailboxID: mailboxID

    discover: (domain, callback) ->
        XHRUtils.accountDiscover domain, (err, infos) ->
            if not infos?
                infos = []
            callback err, infos

    mailboxCreate: (inputValues, callback) ->
        XHRUtils.mailboxCreate inputValues, (error, account) ->
            if not error?
                AppDispatcher.handleViewAction
                    type: ActionTypes.MAILBOX_CREATE
                    value: account
            if callback?
                callback error

    mailboxUpdate: (inputValues, callback) ->
        XHRUtils.mailboxUpdate inputValues, (error, account) ->
            if not error?
                AppDispatcher.handleViewAction
                    type: ActionTypes.MAILBOX_UPDATE
                    value: account
            if callback?
                callback error


    mailboxDelete: (inputValues, callback) ->
        XHRUtils.mailboxDelete inputValues, (error, account) ->
            if not error?
                AppDispatcher.handleViewAction
                    type: ActionTypes.MAILBOX_DELETE
                    value: account
            if callback?
                callback error
