/*
 * -------------------------------------------------------------------------------
 * comm.js
 *
 * Interface between the server via Socket.io and the Elm client via ports. We use
 * Socket.io namespaces to separate communications into several broad categories:
 *
 *    data: bi-directional for any and all data, whether it is changed or not.
 *    site: server to client stats regarding the application.
 *    system: server to client information regarding system status, notices, etc.
 *
 * We do not use Socket.io rooms.
 *
 * We use custom events within namespaces to further differentiate the types of
 * communications.
 *
 *    system namespace: the only custom event used is 'system'.
 *    site namespace: the only custom event used is 'site'.
 *    data namespace: more than one event is used within the data interface.
 *
 *        The 'data' event is used for server initiated communications to the
 *        client within the data namespace.
 *
 *        The 'DATA_CHANGE' event is used by either the server or the client to
 *        inform the other about changed data.
 *
 *            When the client changes data, the message will use a DATA_CHANGE
 *            event and the payload will contain a transactionId. The server
 *            will respond with a payload that also contains a transactionId but
 *            the event will be the transactionId as well. This allows the interface
 *            on the client to clear any timeouts and do anything else to insure
 *            that there is always a one to one correspondence between the client's
 *            data change request and the server's response, or else reliably
 *            detect if that is not the case.
 *
 *        The 'DATA_TABLE_REQUEST' is used by the client to ask for a lookup table.
 *
 *        The 'DATA_TABLE_SUCCESS' or 'DATA_TABLE_FAILURE' events are used by the
 *        server to respond to a DATA_TABLE_REQUEST from the client.
 *
 *    THE WAY THAT IT SHOULD BE:
 *
 *        - Retire the 'data' event. We already have the data namespace and that
 *          is not adding value to a significant degree.
 *        - The 'CHG' event will be used by the client to request a data change
 *          from the server. The client will still send the transactionId within
 *          the payload and the server will still respond with the event of the
 *          transactionId itself prepended with 'CHG:'. For example,
 *          'CHG:19283728475'.
 *        - The 'INFORM' event will be used by the server to inform the client
 *          of data changes that the client may be interested in.
 *        - The 'SELECT' event will be used by the client to retrieve data from
 *          the server. The payload will specify details such as a lookup table
 *          in it's entirety or a query by specified criteria.
 *        - The 'SELECT_RESPONSE' event will be used by the server to return data
 *          to the client that was requested with a prior 'SELECT' event to the
 *          server. This response may contain a failure and the client needs to
 *          check the payload accordingly.
 *
 *
 *
 * Finally, messages are wrapped in an object that has a type field, which is
 * known as msgType within Elm due to the conflict with the 'type' keyword.
 * -------------------------------------------------------------------------------
 */

io = require('socket.io-client');
var app;      // Required: set by caller via setApp().


// --------------------------------------------------------
// Setup three different Socket.io namespaces for data,
// site, and system communications with the server.
// --------------------------------------------------------
var ioData = io.connect(window.location.origin + '/data');
var ioSite = io.connect(window.location.origin + '/site');
var ioSystem = io.connect(window.location.origin + '/system');

// --------------------------------------------------------
// Socket.io event types that we will use.
// TODO: implement new events.
// --------------------------------------------------------
var DATA = 'data';
var DATA_CHANGE = 'DATA_CHANGE';      // All data change messages, bi-directional.
var SITE = 'site';                    // All site messages use this message key.
var SYSTEM = 'system';                // All system messages use this message key.

/* --------------------------------------------------------
 * getNextTransactionId()
 *
 * Returns the next transaction id to use. This is used for
 * data when the communication starts on the client.
 * -------------------------------------------------------- */
var nextTransactionId = 0
var getNextTransactionId = function() {
  return ++nextTransactionId;
};

/* --------------------------------------------------------
 * sendMsg()
 *
 * Sends a data message to the server using the event and
 * the payload passed.
 * -------------------------------------------------------- */
var sendMsg = function(msg, payload) {
  ioData.emit(msg, JSON.stringify(payload));
}

ioData.on(DATA, function(data) {
  if (! app) return;
});

ioSystem.on(SYSTEM, function(data) {
  if (! app) return;

  // type is a reserved term in Elm, so we rename it before sending it in.
  if (data.type) {
    data.msgType = data.type;
    delete data.type;
  }

  // Elm does not like uppercase keys in records, so rename and remove
  // extraneous nesting while we are at it.
  if (data.data && data.data.SYSTEM_LOG) {
    data.systemLog = data.data.SYSTEM_LOG;
    delete data.data;
  }
  app.ports.systemMessages.send(data);
});


/* --------------------------------------------------------
 * setApp()
 *
 * Save the reference to the Elm client. Nearly everything
 * in this module requires this so this needs to be set by
 * the caller as soon as possbile after the Elm client is
 * created.
 * -------------------------------------------------------- */
var setApp = function(theApp) {
  app = theApp;
};

module.exports = {
  setApp: setApp
};