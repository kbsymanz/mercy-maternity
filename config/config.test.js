/* 
 * -------------------------------------------------------------------------------
 * config.js
 *
 * Configuration for the test environment.
 *
 * Usage:
 * 
 * NODE_ENV=test node index.js
 * ------------------------------------------------------------------------------- 
 */


var cfg = require('./config.global')
    // Allows i18n-abide's extract-pot script to pick up these 
    // variables and put them into the pot file.
  , gettext = function(param) {return param;}
  ;

// --------------------------------------------------------
// Settings specific to TEST only. This assumes that the
// test database has these settings.
//
// Note: do not run these settings against the production
// or development databases.
// --------------------------------------------------------
cfg.users = {
  admin: {username: 'admin', password: 'admin'}
  , guard: {username: 'guard', password: 'guard'}
  , clerk: {username: 'clerk', password: 'clerk'}
  , student: {username: 'student', password: 'student'}
  , supervisor: {username: 'supervisor', password: 'supervisor'}
};

// --------------------------------------------------------
// Site settings.
//
// Note: any attribute that needs localization with the
// templates needs to be added to the i18nLocals() function
// in index.js.
// --------------------------------------------------------
cfg.site = {};
cfg.site.title = gettext('Mercy Maternity');

// --------------------------------------------------------
// Host settings.
// --------------------------------------------------------
cfg.host = {};
cfg.host.port = 8000

// --------------------------------------------------------
// Database settings.
// --------------------------------------------------------
cfg.database = {};
cfg.database.host = 'localhost';
cfg.database.port = 3306;
cfg.database.db = 'mercy1test';
cfg.database.dbUser = 'mercy1testuser';
cfg.database.dbPass = 'mmSsrtF7yTJoUDbx';
cfg.database.charset = 'utf8';

// --------------------------------------------------------
// Session settings.
// --------------------------------------------------------
cfg.session = {};
cfg.session.secret = 'ttq5BHqbA4Zhgk48BYL5tyjaz2XTcCAjMkmYEcmaKZd6rave2i';
cfg.session.pool = true;
cfg.session.table = 'session';
cfg.session.cleanup = true;
cfg.session.config = {
  user: cfg.database.dbUser
  , password: cfg.database.dbPass
  , database: cfg.database.db
};

// --------------------------------------------------------
// Cookie settings.
// --------------------------------------------------------
cfg.cookie = {};
cfg.cookie.secret = 'XDK8cZEAu8QEKE8Bu8abXFxaqjCkgG4HB2sJiXppfnHmnCfigf';
cfg.cookie.maxAge = 60 * 60 * 24 * 1000;    // 1 day



module.exports = cfg;

