/*
 * -------------------------------------------------------------------------------
 * util.js
 *
 * Utility functions.
 * -------------------------------------------------------------------------------
 */

var moment = require('moment')
  , _ = require('underscore')
  , cfg = require('./config')
  , INFO = 1
  , WARN = 2
  , ERROR = 3
  , ABBR = [
      {key: 'Sunday', val: 'Sun'}
      , {key: 'Monday', val: 'Mon'}
      , {key: 'Tuesday', val: 'Tue'}
      , {key: 'Wednesday', val: 'Wed'}
      , {key: 'Thursday', val: 'Thu'}
      , {key: 'Friday', val: 'Fri'}
      , {key: 'Saturday', val: 'Sat'}
    ]
  , SYSTEM_LOG = 'SYSTEM_LOG' // Initialized here due to comm module initializing later.
  , sendSystem                // This is initialized later.
  ;


// --------------------------------------------------------
// ErrorCode values for returning to the Elm client.
// --------------------------------------------------------
var LoginSuccessErrorCode = 'LoginSuccessErrorCode';
var LoginSuccessDifferentUserErrorCode = 'LoginSuccessDifferentUserErrorCode';
var LoginFailErrorCode = 'LoginFailErrorCode';
var UserProfileSuccessErrorCode = 'UserProfileSuccessErrorCode';
var UserProfileFailErrorCode = 'UserProfileFailErrorCode';
var UserProfileUpdateSuccessErrorCode = 'UserProfileUpdateSuccessErrorCode';
var UserProfileUpdateFailErrorCode = 'UserProfileUpdateFailErrorCode';
var NoErrorCode = 'NoErrorCode';
var SessionExpiredErrorCode = 'SessionExpiredErrorCode';
var SqlErrorCode = 'SqlErrorCode';
var UnknownErrorCode = 'UnknownErrorCode';
var UnknownTableErrorCode = 'UnknownTableErrorCode';


/* --------------------------------------------------------
 * msg()
 *
 * Returns a partially applied function allowing caller to
 * prefill the prefix (contextual) message and supply the
 * specifics to the returned function as needed.
 *
 * Usage:
 *    var m = msg('comm_assert/some_function()');
 *    assert.ok(user, m('user'));
 *
 * param       prefix
 * return      partially applied function
 * -------------------------------------------------------- */
function msg(prefix) {
  return function(message) {
    return prefix + (message? ': ' + message : '');
  };
}

/* --------------------------------------------------------
 * formatDohID()
 *
 * Return the specified dohID formatted per the usual spec,
 * which is xx-xx-xx.
 *
 * If useAltFormat is true, the alternate format for Phil
 * Health is used which is xx-xxxx.
 *
 * param      dohID
 * param      useAltFormat  - boolean
 * return     formatted string
 * -------------------------------------------------------- */
var formatDohID = function(dohID, useAltFormat) {
  if (! useAltFormat) {
    return dohID? dohID.slice(0,2) + '-' + dohID.slice(2,4) + '-' + dohID.slice(4): '';
  } else {
    return dohID? dohID.slice(0,2) + '-' + dohID.slice(2): '';
  }
};

/* --------------------------------------------------------
 * getProcessId()
 *
 * Return the process id of the current process.
 * -------------------------------------------------------- */
var getProcessId = function() {
  return process.env.WORKER_ID? process.env.WORKER_ID: 0;
}

/* --------------------------------------------------------
 * writeLog()
 *
 * Writes a log message to the console.
 *
 * param      msg
 * param      logType
 * return     undefined
 * -------------------------------------------------------- */
var writeLog = function(msg, logType) {
  var fn = 'info'
    , id = getProcessId()
    , theDate = moment().format('YYYY-MM-DD HH:mm:ss.SSS')
    , message = id + '|' + theDate + ': ' + msg
    ;
  if (logType === WARN || logType === ERROR) fn = 'error';
  console[fn](message);

  // --------------------------------------------------------
  // Broadcast the message to administrators if the comm layer is up.
  //
  // Note that due to the comm module not being initialized as
  // soon as this module, the sendSystem function is not
  // available immediately upon system startup.
  // --------------------------------------------------------
  if (sendSystem) {
    sendSystem(SYSTEM_LOG, message);
  } else {
    if (require('./comm').getIsInitialized()) {
      sendSystem = require('./comm').sendSystem;
      sendSystem(SYSTEM_LOG, message);
    }
  }
};

/* --------------------------------------------------------
 * logInfo()
 *
 * Writes an informative message to the console.
 *
 * param      msg
 * return     undefined
 * -------------------------------------------------------- */
var logInfo = function(msg) {
  writeLog(msg, INFO);
  //console.trace('TRACE');
};

/* --------------------------------------------------------
 * logWarn()
 *
 * Writes a warning message to the console.
 *
 * param      msg
 * return     undefined
 * -------------------------------------------------------- */
var logWarn = function(msg) {
  writeLog(msg, WARN);
};

/* --------------------------------------------------------
 * logError()
 *
 * Writes an error message to the console.
 *
 * param      msg
 * return     undefined
 * -------------------------------------------------------- */
var logError = function(msg) {
  writeLog(msg, ERROR);
};

/* --------------------------------------------------------
 * getGA()
 *
 * Returns the gestational age as a string in the format
 * 'ww d/7' where ww is the week and d is the day of the
 * current week, e.g. 38 2/7 or 32 5/7.
 *
 * Uses a reference date, which is either passed or if
 * not passed it is assumed to be today. The reference
 * date is the date that the gestational age should be
 * computed for. In other words, given the estimated
 * due date and the reference date, what is the
 * gestational age from the perspective of the reference
 * date.
 *
 * Calculation assumes a 40 week pregnancy and subtracts
 * the refDate from the estimated due date, which is
 * also passed as a parameter. Params edd and rDate can be
 * Moment objects, JS Date objects, or strings in YYYY-MM-DD
 * format.
 *
 * Note: if parameters are not 'date-like' per above specifications,
 * will return an empty string.
 *
 * param      edd - estimated due date as JS Date or Moment obj
 * param      rDate - the reference date use for the calculation
 * return     GA - as a string in ww d/7 format
 * -------------------------------------------------------- */
var getGA = function(edd, rDate) {
  if (! edd) throw new Error('getGA() must be called with an estimated due date.');
  var estDue
    , refDate
    , tmpDate
    ;
  // Sanity check for edd.
  if (typeof edd === 'string' && /....-..-../.test(edd)) {
    estDue = moment(edd, 'YYYY-MM-DD');
  }
  if (moment.isMoment(edd)) estDue = edd.clone();
  if (_.isDate(edd)) estDue = moment(edd);
  if (! estDue) return '';

  // Sanity check for rDate.
  if (rDate) {
    if (typeof rDate === 'string' && /....-..-../.test(rDate)) {
      refDate = moment(rDate, 'YYYY-MM-DD');
    }
    if (moment.isMoment(rDate)) refDate = rDate.clone();
    if (_.isDate(rDate)) refDate = moment(rDate);
    if (! refDate) return '';
  } else {
    refDate = moment();
  }

  // --------------------------------------------------------
  // Sanity check for reference date before pregnancy started.
  // --------------------------------------------------------
  tmpDate = estDue.clone();
  if (refDate.isBefore(tmpDate.subtract(280, 'days'))) {
    return '0 0/7';
  }

  var weeks = Math.abs(40 - estDue.diff(refDate, 'weeks') - 1)
    , days = Math.abs(estDue.diff(refDate.add(40 - weeks, 'weeks'), 'days'))
    ;
  if (_.isNaN(weeks) || ! _.isNumber(weeks)) return '';
  if (_.isNaN(days) || ! _.isNumber(days)) return '';
  if (days >= 7) {
    weeks++;
    days = days - 7;
  }

  // --------------------------------------------------------
  // Sanity check for too large of a GA, i.e. > 45 weeks.
  // --------------------------------------------------------
  if (weeks > 45) return 'N/A';

  return weeks + ' ' + days + '/7';
};

/* --------------------------------------------------------
 * calcEdd()
 *
 * Calculate the estimated due date based upon the date of
 * the last mentral period passed. The returned date is a
 * String in YYYY-MM-DD format unless an alternative date
 * format is passed using Moment formatting rules.
 *
 * NOTE: this function is also included in mercy.js on the
 * client side. Changes made here should also be made there.
 *
 * param       lmp - date of the last mentral period
 * param       format - the alternative format string to use
 * return      edd - due date as a String
 * -------------------------------------------------------- */
var calcEdd = function(lmp, format) {
  if (! lmp) throw new Error('calcEdd() must be called with the lmp date.');
  var edd
    ;

  // --------------------------------------------------------
  // Sanity check that we are passed a Date or Moment.
  // --------------------------------------------------------
  if (! _.isDate(lmp) && ! moment.isMoment(lmp)) {
    throw new Error('calcEdd() must be called with a valid date.');
  }
  edd = moment(lmp).add(280, 'days');
  if (format) return edd.format(format);
  return edd.format('YYYY-MM-DD');
};

/* --------------------------------------------------------
 * adjustSelectData()
 *
 * "Adjusts" the selectData list for the passed selectData
 * list to have a selected element that matches key, if key
 * is passed.
 *
 * param       list - the selectData list
 * param       key - the key that matches selectKey
 * return      the new list
 * -------------------------------------------------------- */
var adjustSelectData = function(list, key) {
    var newList = []
      ;
    _.each(list, function(obj) {
      var newObj = {}
        ;
      newObj.selectKey = obj.selectKey;
      newObj.label = obj.label;
      if (key) {
        if (obj.selectKey === key) {
          newObj.selected = true;
        } else {
          newObj.selected = false;
        }
      } else {
        newObj.selected = obj.selected;
      }
      newList.push(newObj);
    });
  return newList;
};

/* --------------------------------------------------------
 * addBlankSelectData()
 *
 * Adds a blank select data record to the beginning of the
 * select data list passed. This allows a select in a form
 * to be unselected until the user decides to select something.
 *
 * Note that this deselects all other records and causes the
 * new blank record to be the only one that is selected.
 *
 * Note also that this does nothing if there already is a
 * record with a selectKey equal to ''.
 *
 * The list is passed by reference and therefore the original
 * list is modified.
 *
 * param      list - an array of select data objects
 * return     undefined
 * -------------------------------------------------------- */
var addBlankSelectData = function(list) {
  if (_.find(list, function(e) {return e.selectKey === '';})) return list;
  _.each(list, function(obj) {obj.selected = false;});
  list.unshift({selectKey: '', label: '', selected: true});
};

/* --------------------------------------------------------
 * getAbbr()
 *
 * Returns an abbreviation for the string passed if known,
 * otherwise returns the string itself.
 *
 * TODO: store the abbreviations in the database as opposed
 * to being hard-coded in this module.
 *
 * param      key
 * return     abbreviation
 * -------------------------------------------------------- */
var getAbbr = function(key) {
  var abbr = _.find(ABBR, function(obj) {return obj.key === key;})
    ;
  if (abbr) return abbr.val;
  return key;
};


/* --------------------------------------------------------
 * isValidDate()
 *
 * Returns true if the "date" passed is valid, otherwise
 * false. The "date" field can be a JS Date object, a
 * Moment instance, or a String. If it is a string, a second
 * parameter is required that specifies the format of the
 * string. Formats accepted are the same as the Moment library.
 *
 * param      dte
 * param      format
 * return     boolean
 * -------------------------------------------------------- */
var isValidDate = function(dte, format) {
  var m;
  if (dte && _.isDate(dte)) return true;
  if (dte && moment.isMoment(dte) && dte.isValid()) return true;
  if (dte && _.isString(dte) && format && _.isString(format)) {
    m = moment(dte, format, true);    // strict parsing mode is true
    return m.isValid();
  }

  return false;
};


/* --------------------------------------------------------
 * returnStatus()
 *
 * Utility function to build an object based on the fields
 * passed.
 *
 * param       op         - the operation
 * param       table      - the table name
 * param       id         - the id
 * param       otherId    - an id with a name depending on the operation
 * param       success    - boolean
 * param       msg        - message about error, etc.
 * return      rec
 * -------------------------------------------------------- */
var returnStatusCHG = function(table, id, stateId, success, errCode, msg) {
  var msgStr = msg? msg: '';
  if (msg && typeof msg === 'object') {
    msgStr = JSON.stringify(msg);
  }
  var retVal = {
    table: table,
    id: id,
    stateId: stateId,
    success: success,
    errorCode: errCode? errCode: NoErrorCode,
    msg: msgStr
  };
  return retVal;
};

var returnStatusCHG2 = function(msgType, messageId, table, id, success, errCode, msg) {
  var msgStr = msg? msg: '';
  if (msg && typeof msg === 'object') {
    msgStr = JSON.stringify(msg);
  }

  var retVal = {
    messageId: messageId,
    namespace: 'DATA',
    msgType: msgType,
    version: 2,
    response: {
      table: table,
      id: id,
      success: success,
      errorCode: errCode? errCode: NoErrorCode,
      msg: msgStr
    }
  };
  return retVal;
};

/* --------------------------------------------------------
 * returnStatusADD2()
 *
 * Return status format for DATA messages, version 2, of
 * msgType ADD.
 *
 * Note: for version 2, msgType is either ADD, CHG, or DEL
 * for both directions.
 * -------------------------------------------------------- */
var returnStatusADD2 = function(msgType, messageId, table, newId, success, errCode, msg) {
  var msgStr = msg? msg: '';
  if (msg && typeof msg === 'object') {
    msgStr = JSON.stringify(msg);
  }
  // TODO: need to work out the structure of what is returned in light of wrapData().
  var retVal = {
    messageId: messageId,
    namespace: 'DATA',
    msgType: msgType,
    version: 2,
    response: {
      table: table,
      id: newId,
      success: success,
      errorCode: errCode? errCode: NoErrorCode,
      msg: msgStr
    }
  };
  return retVal;
};

var returnStatusADD = function(table, originalId, newId, success, errCode, msg) {
  var msgStr = msg? msg: '';
  if (msg && typeof msg === 'object') {
    msgStr = JSON.stringify(msg);
  }
  var retVal = {
    id: newId,
    table: table,
    pendingId: originalId,
    success: success,
    errorCode: errCode? errCode: NoErrorCode,
    msg: msgStr
  };
  return retVal;
};

/* --------------------------------------------------------
 * returnStatusDEL2()
 *
 * Return status format for DATA messages, version 2, of
 * msgType DEL.
 *
 * Note: for version 2, msgType is either ADD, CHG, or DEL
 * for both directions.
 * -------------------------------------------------------- */
var returnStatusDEL2 = function(msgType, messageId, table, id, success, errCode, msg) {
  var msgStr = msg? msg: '';
  if (msg && typeof msg === 'object') {
    msgStr = JSON.stringify(msg);
  }

  var retVal = {
    messageId: messageId,
    namespace: 'DATA',
    msgType: msgType,
    version: 2,
    response: {
      table: table,
      id: id,
      success: success,
      errorCode: errCode? errCode: NoErrorCode,
      msg: msgStr
    }
  };
  return retVal;
};

var returnStatusDEL = function(table, id, stateId, success, errCode, msg) {
  var msgStr = msg? msg: '';
  if (msg && typeof msg === 'object') {
    msgStr = JSON.stringify(msg);
  }
  var retVal = {
    table: table,
    id: id,
    stateId: stateId,
    success: success,
    errorCode: errCode? errCode: NoErrorCode,
    msg: msgStr
  };
  return retVal;
};

// Used for version 2 as well as legacy messages.
var returnStatusSELECT = function(obj, data, success, errCode, msg) {
  var msgStr = msg? msg: '';
  if (msg && typeof msg === 'object') {
    msgStr = JSON.stringify(msg);
  }
  var retVal = _.clone(obj);
  retVal.data = data? data: [];
  retVal.success = success;
  retVal.errorCode = errCode? errCode: NoErrorCode;
  retVal.msg = msgStr;
  return retVal;
};

// --------------------------------------------------------
// Note, defaults isLoggedIn to false. Caller needs to set
// explicitly along with other required fields.
// --------------------------------------------------------
var returnLogin = function(success, errCode, msg) {
  return {
    adhocType: 'ADHOC_LOGIN_RESPONSE',
    success: success,
    errorCode: errCode? errCode: NoErrorCode,
    msg: msg? msg: '',
    isLoggedIn: false
  };
};

// --------------------------------------------------------
// Note, defaults isLoggedIn to false. Caller needs to set
// explicitly along with other required fields.
// --------------------------------------------------------
var returnUserProfile = function(success, errCode, msg) {
  return {
    adhocType: 'ADHOC_USER_PROFILE_RESPONSE',
    success: success,
    errorCode: errCode? errCode: NoErrorCode,
    msg: msg? msg: '',
    isLoggedIn: false
  };
};

// --------------------------------------------------------
// Note, defaults isLoggedIn to false. Caller needs to set
// explicitly along with other required fields.
// --------------------------------------------------------
var returnUserProfileUpdate = function(success, errCode, msg) {
  return {
    adhocType: 'ADHOC_USER_PROFILE_UPDATE_RESPONSE',
    success: success,
    errorCode: errCode? errCode: NoErrorCode,
    msg: msg? msg: ''
  };
};

/* --------------------------------------------------------
 * validOrVoidDate()
 *
 * Insure that the parameter passed in either a valid Date
 * object and return the same, otherwise return an undefined.
 * Note that this will return undefined even if a valid
 * Moment object is passed.
 *
 * param       val - a Date object or anything
 * return      result - a Date object or undefined
 * -------------------------------------------------------- */
var validOrVoidDate = function(val) {
  var result = void 0;
  if (val === null) return result;
  if (val === '0000-00-00') return result;
  if (_.isDate(val) && moment(val).isValid()) result = val;
  return result;
};

/* --------------------------------------------------------
 * splitStringOnWordAtPerc()
 *
 * Split the specified string at a word boundary at or less
 * that the percentage of the length of the string passed.
 * Return an array containing the parts of the string with
 * the leading and trailing whitespace trimmed of each part.
 *
 * We assume that each character is of equal width such as
 * in the case of a mono font.
 *
 * param        str
 * param        perc
 * return       array of string
 * -------------------------------------------------------- */
var splitStringOnWordAtPerc = function(str, perc) {
  var splitAt = Math.floor((str.length * perc)/100)
    , words = str.split(' ')
    , result = [ '', '' ]
    , hasSplit = false
    ;

  _.each(words, function(word) {

    if (! hasSplit) {
      // Use < instead of <= to account for the space between the
      // word that will be needed.
      if (result[0].length + word.length < splitAt) {
        if (result[0].length === 0) {
          // First word added.
          result[0] = word;
        } else {
          result[0] += " " + word;
        }
      } else {
        // Flag transition to use result[1] exclusively.
        hasSplit = true;
        result[1] = word;
      }
    } else {
      // Using result[1] exclusively since we have split.
      result[1] += " " + word;
    }
  });

  return result;
};



module.exports = {
  addBlankSelectData: addBlankSelectData
  , adjustSelectData: adjustSelectData
  , calcEdd: calcEdd
  , formatDohID: formatDohID
  , getAbbr: getAbbr
  , getGA: getGA
  , getProcessId
  , isValidDate: isValidDate
  , logError: logError
  , logInfo: logInfo
  , logWarn: logWarn
  , LoginFailErrorCode
  , LoginSuccessErrorCode
  , LoginSuccessDifferentUserErrorCode
  , msg
  , NoErrorCode
  , returnLogin
  , returnStatusADD
  , returnStatusADD2
  , returnStatusCHG
  , returnStatusCHG2
  , returnStatusDEL
  , returnStatusDEL2
  , returnStatusSELECT
  , returnUserProfile
  , returnUserProfileUpdate
  , SessionExpiredErrorCode
  , splitStringOnWordAtPerc
  , SqlErrorCode
  , UnknownErrorCode
  , UnknownTableErrorCode
  , UserProfileSuccessErrorCode
  , UserProfileFailErrorCode
  , UserProfileUpdateSuccessErrorCode
  , UserProfileUpdateFailErrorCode
  , validOrVoidDate: validOrVoidDate
};


