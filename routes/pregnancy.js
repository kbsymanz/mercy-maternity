/*
 * -------------------------------------------------------------------------------
 * pregnancy.js
 *
 * Functionality for management of pregnancies.
 * -------------------------------------------------------------------------------
 */

var _ = require('underscore')
  , Promise = require('bluebird')
  , moment = require('moment')
  , cfg = require('../config')
  , hasRole = require('../auth').hasRole
  , Patient = require('../models').Patient
  , Patients = require('../models').Patients
  , Pregnancy = require('../models').Pregnancy
  , Pregnancies = require('../models').Pregnancies
  , PregnancyHistory = require('../models').PregnancyHistory
  , PregnancyHistories = require('../models').PregnancyHistories
  , PrenatalExam = require('../models').PrenatalExam
  , PrenatalExams = require('../models').PrenatalExams
  , User = require('../models').User
  , Users = require('../models').Users
  , SelectData = require('../models').SelectData
  , logInfo = require('../util').logInfo
  , logWarn = require('../util').logWarn
  , logError = require('../util').logError
  , maritalStatus = []
  , religion = []
  , education = []
  ;

/* --------------------------------------------------------
 * init()
 *
 * Initialize the module.
 * -------------------------------------------------------- */
var init = function() {
  var refresh
    , doRefresh
    , setMS = function(list) {maritalStatus = list;}
    , setRel = function(list) {religion = list;}
    , setEdu = function(list) {education = list;}
    , maritalName = 'maritalStatus'
    , religionName = 'religion'
    , educationName = 'education'
    , interval = cfg.data.selectRefreshInterval
  ;

  // --------------------------------------------------------
  // Refresh dataset passed.
  // --------------------------------------------------------
  refresh = function(dataName) {
    return new Promise(function(resolve, reject) {
      logInfo('Refreshing ' + dataName);
      SelectData.getSelect(dataName)
        .then(function(list) {
          resolve(list);
        })
        .caught(function(err) {
          err.status = 500;
          reject(err);
        });
    });
  };

  // --------------------------------------------------------
  // Do an initial refresh and at a set interval afterward.
  // --------------------------------------------------------
  doRefresh = function(dataName, fn) {
    refresh(dataName).then(function(list) {
      fn(list);
    });
    setInterval(function() {
      refresh(dataName).then(function(list) {
        fn(list);
      });
    }, interval);
  };

  // --------------------------------------------------------
  // Keep the various select lists up to date.
  // --------------------------------------------------------
  doRefresh(maritalName, setMS);
  doRefresh(religionName, setRel);
  doRefresh(educationName, setEdu);

};

/* --------------------------------------------------------
 * getGA()
 *
 * Returns the gestational age as a string in the format
 * 'ww d/7' where ww is the week and d is the day of the
 * current week, e.g. 38 2/7 or 32 5/7.
 *
 * Calculation assumes a 40 week pregnancy and subtracts
 * today's date from the estimated due date, which is passed
 * as a parameter.
 *
 * param      edd - estimated due date as JS Date or Moment obj
 * return     GA - as a string in ww d/7 format
 * -------------------------------------------------------- */
var getGA = function(edd) {
  var estDue = moment(edd)
    , today = moment()
    , weeks = 40 - estDue.diff(today, 'weeks') - 1
    , days = Math.abs(estDue.diff(today.add('weeks', 40 - weeks), 'days'))
    ;
  return weeks + ' ' + days + '/7';
};

/* --------------------------------------------------------
 * load()
 *
 * Loads the pregnancy record from the database based upon the id
 * as specified in the path. Places the pregnancy record in the
 * request as paramPregnancy.
 *
 * param       req
 * param       res
 * param       next - callback
 * return      undefined
 * -------------------------------------------------------- */
var load = function(req, res, next) {
  var id = req.params.id
    , id2 = parseInt(req.params.id2, 10)
    , op = req.params.op
    , formatDate = function(val) {
        return val === '0000-00-00'? '': moment(val).format('YYYY-MM-DD');
      }
    ;

  Pregnancy.forge({id: id})
    .fetch({withRelated: ['patient', 'pregnancyHistory', 'prenatalExam']})
    .then(function(rec) {
      if (! rec) return next();
      rec = rec.toJSON();

      // --------------------------------------------------------
      // Fix the dates for the screen in the format that the
      // input[type='date'] expects.
      // --------------------------------------------------------
      rec.patient.dob = formatDate(rec.patient.dob);
      rec.lmp = formatDate(rec.lmp);
      rec.edd = formatDate(rec.edd);
      rec.alternateEdd = formatDate(rec.alternateEdd);
      rec.ga = getGA(rec.edd);

      if (rec) req.paramPregnancy = rec;

      // --------------------------------------------------------
      // Assign detail record in the master-detail relationship
      // to a convenient location on the request object.
      // --------------------------------------------------------
      if (! isNaN(id2)) {
        // --------------------------------------------------------
        // Historical pregnancies.
        // --------------------------------------------------------
        if (op === 'preghistoryedit' || op === 'preghistorydelete') {
          req.paramPregHist = _.find(rec.pregnancyHistory, function(r) {
            return r.id === id2;
          });
        }
        // --------------------------------------------------------
        // Prenatal exams.
        // --------------------------------------------------------
        if (op === 'prenatalexamedit' || op === 'prenatalexamdelete') {
          req.paramPrenatalExam = _.find(rec.prenatalExam, function(p) {
            return p.id === id2;
          });
        }
      }
      next();
    });
};

/* --------------------------------------------------------
 * history()
 *
 * Render the history page for the pregnancy.
 * -------------------------------------------------------- */
var history = function(req, res) {
  var data = {
        title: req.gettext('Pregnancy History')
        , user: req.session.user
        , messages: req.flash()
        , rec: req.paramPregnancy
      }
    ;
  if (req.paramPregnancy) {
    User.getUserIdMap()
      .then(function(users) {
        Pregnancy.forge({id: req.paramPregnancy.id})
          .historyData(req.paramPregnancy.id)
          .then(function(list) {
            data.history = list;
            data.users = users;
            res.render('history', data);
          });
      })
      .caught(function(err) {
        logError(err);
      });
  } else {
    // Pregnancy not found.
    res.redirect(cfg.path.search);
  }
};

/* --------------------------------------------------------
 * getQuestFormData()
 *
 * Return the data necessary to populate the questionnaire
 * form according to the database record.
 * -------------------------------------------------------- */
var getCommonFormData = function(req, addData) {
  return _.extend(addData, {
    user: req.session.user
    , messages: req.flash()
    , rec: req.paramPregnancy
    , pregHist: req.paramPregHist || void(0)
    , prenatalExam: req.paramPrenatalExam || void(0)
  });
};

/* --------------------------------------------------------
 * quesEdit()
 *
 * Display the pregnancy questionnaire form.
 * -------------------------------------------------------- */
var quesEdit = function(req, res) {
  var data = {title: req.gettext('Pregnancy Questionnaire')};
  if (req.paramPregnancy) {
    res.render('pregnancyQuestionnaire', getCommonFormData(req, data));
  } else {
    // Pregnancy not found.
    res.redirect(cfg.path.search);
  }
};

/* --------------------------------------------------------
 * quesUpdate()
 *
 * Update the pregnancy record with the questionnaire data.
 * -------------------------------------------------------- */
var quesUpdate = function(req, res) {
  var supervisor = null
    , pregFlds = {}
    , defaultFlds = {
        currentlyVomiting: '0', currentlyDizzy: '0',
        currentlyFainting: '0', currentlyBleeding: '0',
        currentlyUrinationPain: '0', currentlyBlurryVision: '0',
        currentlySwelling: '0', currentlyBirthCanalPain: '0',
        currentlyNone: '0', useIodizedSalt: '0',
        canDrinkMedicine: '0', planToBreastFeed: '0',
        whereDeliver: '', birthCompanion: '',
        practiceFamilyPlanning: '0', familyPlanningDetails: '',
        familyHistoryTwins: '0', familyHistoryHighBloodPressure: '0',
        familyHistoryDiabetes: '0', familyHistoryChestPains: '0',
        familyHistoryTB: '0', familyHistorySmoking: '0',
        familyHistoryNone: '0', historyFoodAllergy: '0',
        historyMedicineAllergy: '0', historyAsthma: '0',
        historyChestPains: '0', historyKidneyProblems: '0',
        historyHepatitis: '0', historyGoiter: '0',
        historyHighBloodPressure: '0', historyHospitalOperation: '0',
        historyBloodTransfusion: '0', historySmoking: '0',
        historyDrinking: '0', historyNone: '0'
      }
    ;

  if (req.paramPregnancy &&
      req.body &&
      req.paramPregnancy.id &&
      req.body.id &&
      req.paramPregnancy.id == req.body.id) {

    if (hasRole(req, 'student')) {
      supervisor = req.session.supervisor.id;
    }

    // --------------------------------------------------------
    // Allow 'unchecking' a box by providing a default of off.
    // --------------------------------------------------------
    pregFlds = _.extend(defaultFlds, _.omit(req.body, ['_csrf']));

    // --------------------------------------------------------
    // If none field is checked as well as other fields in each
    // group, turn the none field off because it does not make
    // sense.
    // --------------------------------------------------------
    _.each(_.keys(pregFlds), function(key) {
      if (pregFlds.currentlyNone == '1') {
        if (key.indexOf('currently') == 0 && key != 'currentlyNone') {
          if (pregFlds[key] == '1') pregFlds.currentlyNone = '0';
        }
      }
      if (pregFlds.familyHistoryNone == '1') {
        if (key.indexOf('familyHistory') == 0 && key != 'familyHistoryNone') {
          if (pregFlds[key] == '1') pregFlds.familyHistoryNone = '0';
        }
      }
      if (pregFlds.historyNone == '1') {
        if (key.indexOf('history') == 0 && key != 'historyNone') {
          if (pregFlds[key] == '1') pregFlds.historyNone = '0';
        }
      }
    });

    Pregnancy.forge(pregFlds)
      .setUpdatedBy(req.session.user.id)
      .setSupervisor(supervisor)
      .save().then(function(pregnancy) {
        req.flash('info', req.gettext('Pregnancy was updated.'));
        res.redirect(cfg.path.pregnancyQuesEdit.replace(/:id/, pregnancy.id));
      })
      .caught(function(err) {
        logError(err);
        res.redirect(cfg.path.search);
      });
  } else {
    logError('Error in update of pregnancy: pregnancy not found.');
    res.redirect(cfg.path.search);
  }
};

/* --------------------------------------------------------
 * addForm()
 *
 * Display the form to create a new pregnancy record.
 *
 * param       req
 * param       res
 * param       next - callback
 * return      undefined
 * -------------------------------------------------------- */
var addForm = function(req, res) {
  var data = {title: req.gettext('New Pregnancy Record') }
    ;
  res.render('pregnancyAddForm', getEditFormData(req, data));
};

/* --------------------------------------------------------
 * getEditFormData()
 *
 * Returns an object representing the data that is rendered
 * when the edit form is displayed. Expects the caller to
 * pass the key/value pair for title in addData.
 *
 * param       req
 * param       addData  - (Object) additional data
 * return      Object
 * -------------------------------------------------------- */
var getEditFormData = function(req, addData) {
  var ms = _.map(maritalStatus, function(m) {return _.clone(m);})
    , rel = _.map(religion, function(r) {return _.clone(r);})
    , edu = _.map(education, function(e) {return _.clone(e);})
    , partEdu = _.map(education, function(e) {return _.clone(e);})
    ;
  if (req.paramPregnancy && req.paramPregnancy.maritalStatus) {
    _.each(ms, function(rec) {
      if (rec.selectKey == req.paramPregnancy.maritalStatus) {
        rec.selected = true;
      } else {
        rec.selected = false;
      }
    });
  }
  if (req.paramPregnancy && req.paramPregnancy.religion) {
    _.each(rel, function(rec) {
      if (rec.selectKey == req.paramPregnancy.religion) {
        rec.selected = true;
      } else {
        rec.selected = false;
      }
    });
  }
  if (req.paramPregnancy && req.paramPregnancy.education) {
    _.each(edu, function(rec) {
      if (rec.selectKey == req.paramPregnancy.education) {
        rec.selected = true;
      } else {
        rec.selected = false;
      }
    });
  }
  if (req.paramPregnancy && req.paramPregnancy.partnerEducation) {
    _.each(partEdu, function(rec) {
      if (rec.selectKey == req.paramPregnancy.partnerEducation) {
        rec.selected = true;
      } else {
        rec.selected = false;
      }
    });
  }
  return _.extend(addData, {
    user: req.session.user
    , messages: req.flash()
    , marital: ms
    , religion: rel
    , education: edu
    , partnerEducation: partEdu
    , rec: req.paramPregnancy
  });
};

/* --------------------------------------------------------
 * editForm()
 *
 * Displays the edit form for the pregnancy.
 *
 * param
 * return
 * -------------------------------------------------------- */
var editForm = function(req, res) {
  var data = {title: req.gettext('Edit Pregnancy')};
  if (req.paramPregnancy) {
    res.render('pregnancyEditForm', getEditFormData(req, data));
  } else {
    // Pregnancy not found.
    res.redirect(cfg.path.search);
  }
};

/* --------------------------------------------------------
 * create()
 *
 * Create a new patient record and the corresponding pregnancy
 * record to go along with it. Insures that the required fields
 * are provided otherwise does not change the database.
 *
 * param       req
 * param       res
 * return      undefined
 * -------------------------------------------------------- */
var create = function(req, res) {
  var common = {
        updatedBy: req.session.user.id
        , supervisor: null
      }
    , dob = req.body.dob.length > 0? req.body.dob: null
    , doh = req.body.doh.length > 0? req.body.doh: null
    , pregFlds = _.omit(req.body, ['_csrf', 'dob'])
    , patFlds = {}
    ;

  if (hasRole(req, 'student')) {
    common.supervisor = req.session.supervisor.id;
  }
  pregFlds = _.extend(pregFlds, common);
  patFlds = _.extend(common, {dob: dob, dohID: doh});

  // --------------------------------------------------------
  // Validate the fields.
  // --------------------------------------------------------
  Promise.all([Patient.checkFields(patFlds), Pregnancy.checkFields(pregFlds)])
    .then(function(result) {
      return _.object(['patFlds', 'pregFlds'], result);
    })
    // --------------------------------------------------------
    // Save patient and pregnancy records.
    // --------------------------------------------------------
    .then(function(flds) {
      Patient
        .forge(flds.patFlds)
        .setUpdatedBy(req.session.user.id)
        .setSupervisor(common.supervisor)
        .save()
        .then(function(patient) {
          var pregFields = _.extend(flds.pregFlds, {patient_id: patient.get('id')});
          Pregnancy
            .forge(pregFields)
            .setUpdatedBy(req.session.user.id)
            .setSupervisor(common.supervisor)
            .save()
            .then(function(pregnancy) {
              req.flash('info', req.gettext('Pregnancy was created.'));
              res.redirect(cfg.path.pregnancyEditForm.replace(/:id/, pregnancy.get('id')));
            })
            .caught(function(e) {
              logError('Error saving pregnancy record. Orphan patient record id: ' + patient.get('id'));
              throw e;
            });
        })
        .caught(function(e) {
          logError('Error saving patient record: ' + e);
          throw e;
        });
    })
    .caught(function(e) {
      logError(e);
      res.status(406);
      res.end();    // TODO: need a custom 406 page.
    });
};

/* --------------------------------------------------------
 * update()
 *
 * Update the main patient record (general information).
 * -------------------------------------------------------- */
var update = function(req, res) {
  var pregFlds
    , patFlds
    , dob = req.body.dob.length > 0? req.body.dob: null
    , doh = req.body.doh.length > 0? req.body.doh: null
    , supervisor = null;
    ;
  if (req.paramPregnancy &&
      req.body &&
      req.paramPregnancy.id &&
      req.body.id &&
      req.paramPregnancy.id == req.body.id) {

    if (hasRole(req, 'student')) {
      supervisor = req.session.supervisor.id;
    }
    pregFlds = _.omit(req.body, ['_csrf', 'doh', 'dob', 'priority']);
    patFlds = {dohID: doh, dob: dob};
    patFlds = _.extend(patFlds, {id: req.paramPregnancy.patient_id});
    Pregnancy.checkFields(pregFlds).then(function(flds) {
      Pregnancy.forge(flds)
        .setUpdatedBy(req.session.user.id)
        .setSupervisor(supervisor)
        .save().then(function() {
          Patient
            .forge(patFlds)
            .setUpdatedBy(req.session.user.id)
            .setSupervisor(supervisor)
            .save()
            .then(function(patient) {
              req.flash('info', req.gettext('Pregnancy was updated.'));
              res.redirect(cfg.path.pregnancyEditForm.replace(/:id/, flds.id));
            })
            .caught(function(err) {
              logError(err);
              res.redirect(cfg.path.search);
            });
      })
      .caught(function(err) {
        logError(err);
        res.redirect(cfg.path.search);
      });
    })
    .caught(function(err) {
      logError(err);
      res.redirect(cfg.path.search);
    });

  } else {
    logError('Error in update of pregnancy: pregnancy not found.');
    res.redirect(cfg.path.search);
  }
};

/* --------------------------------------------------------
 * midwifeEdit()
 *
 * Display the midwife interview screen.
 * -------------------------------------------------------- */
var midwifeEdit = function(req, res) {
  var data = getCommonFormData(req, {title: req.gettext('Midwife Interview')})
    ;
  // --------------------------------------------------------
  // Properly set the noneOfAbove field which does not have
  // representation in the database.
  // --------------------------------------------------------
  if (data.rec.invertedNipples == 0 && data.rec.hasUS == 0 && data.rec.wantsUS == 0) {
    data.rec.noneOfAbove = 1;
  }
  if (req.paramPregnancy) {
    res.render('midwifeInterview', data);
  } else {
    // Pregnancy not found.
    res.redirect(cfg.path.search);
  }
};

/* --------------------------------------------------------
 * midwifeUpdate()
 *
 * Update the patient, pregnancy and pregnancyHistory records
 * with changes from the midwife interview screen.
 * -------------------------------------------------------- */
var midwifeUpdate = function(req, res) {
  var supervisor = null
    , pregFlds = {}
    , defaultFlds = {
        invertedNipples: '0'
        , hasUS: '0'
        , wantsUS: '0'
        , noneOfAbove: '0'        // Field does not exist in database.
        , ageOfMenarche: null     // Patient field, not pregnancy.
        , note: ''
      }
    ;

  if (req.paramPregnancy &&
      req.body &&
      req.paramPregnancy.id &&
      req.body.id &&
      req.paramPregnancy.id == req.body.id) {

    if (hasRole(req, 'student')) {
      supervisor = req.session.supervisor.id;
    }

    // --------------------------------------------------------
    // Allow 'unchecking' a box by providing a default of off.
    // --------------------------------------------------------
    pregFlds = _.extend(defaultFlds, _.omit(req.body, ['_csrf']));

    Pregnancy.checkMidwifeInterviewFields(pregFlds).then(function(flds) {
      Pregnancy.forge({id: pregFlds.id})
        .fetch().then(function(pregnancy) {
          pregnancy
            .setUpdatedBy(req.session.user.id)
            .setSupervisor(supervisor)
            .save(pregFlds).then(function(pregnancy) {
              Patient.forge({id: pregnancy.get('patient_id')})
                .fetch().then(function(patient) {
                  patient
                    .setUpdatedBy(req.session.user.id)
                    .setSupervisor(supervisor)
                    .save({ageOfMenarche: pregFlds.ageOfMenarche}).then(function(patient) {
                      req.flash('info', req.gettext('Pregnancy was updated.'));
                      res.redirect(cfg.path.pregnancyMidwifeEdit.replace(/:id/, pregnancy.id));
                    })
                    .caught(function(err) {
                      logError(err);
                      res.redirect(cfg.path.search);
                    });
                })
            })
            .caught(function(err) {
              logError(err);
              res.redirect(cfg.path.search);
            });
      });
    })
    .caught(function(err) {
      logError(err);
      req.flash('warning', req.gettext(err));
      res.redirect(cfg.path.pregnancyMidwifeEdit.replace(/:id/, pregFlds.id));
    });
  } else {
    logError('Error in update of pregnancy: pregnancy not found.');
    res.redirect(cfg.path.search);
  }

};

/* --------------------------------------------------------
 * pregnancyHistoryAddForm()
 *
 * Displays the historical pregnancy form for adding.
 * -------------------------------------------------------- */
var pregnancyHistoryAddForm = function(req, res) {
  var data = {title: req.gettext('Add Historical Pregnancy')};
  if (req.paramPregnancy) {
    res.render('midwifeInterviewAddPreg', getCommonFormData(req, data));
  } else {
    // Pregnancy not found.
    res.redirect(cfg.path.search);
  }
};

/* --------------------------------------------------------
 * pregnancyHistoryEditForm()
 *
 * Displays the historical pregnancy form for editing.
 * -------------------------------------------------------- */
var pregnancyHistoryEditForm = function(req, res) {
  var data = {title: req.gettext('Edit Historical Pregnancy')};
  if (req.paramPregnancy) {
    res.render('midwifeInterviewEditPreg', getCommonFormData(req, data));
  } else {
    // Pregnancy not found.
    res.redirect(cfg.path.search);
  }
};

/* --------------------------------------------------------
 * pregnancyHistoryEdit()
 *
 * Updates the historical pregnancy record.
 * -------------------------------------------------------- */
var pregnancyHistoryEdit = function(req, res) {
  var supervisor = null
    , flds = req.body
    , pregHistRec
    ;

  if (req.paramPregnancy &&
      req.body &&
      req.paramPregnancy.id &&
      req.body.pregnancy_id &&
      req.paramPregnancy.id == req.body.pregnancy_id) {

    if (hasRole(req, 'student')) {
      supervisor = req.session.supervisor.id;
    }

    // --------------------------------------------------------
    // Convert values from Y/N to boolean for the database.
    // --------------------------------------------------------
    if (flds.episTear === 'Y') {
      flds.episTear = 1;
    } else {
      flds.episTear = 0;
    }
    if (flds.repaired === 'Y') {
      flds.repaired = 1;
    } else {
      flds.repaired = 0;
    }

    pregHistRec = new PregnancyHistory(flds);
    pregHistRec
      .setUpdatedBy(req.session.user.id)
      .setSupervisor(supervisor)
      .save(flds, {method: 'update'}).then(function(model) {
        var path = cfg.path.pregnancyHistoryEditForm
          ;
        path = path.replace(/:id/, flds.pregnancy_id);
        path = path.replace(/:hid/, flds.id);
        res.redirect(path);
      })
      .caught(function(err) {
        logError(err);
        // TODO: handle this better.
        res.redirect(cfg.path.search);
      });
  } else {
    logError('Error in update of pregnancyHistory: pregnancy not found.');
    // TODO: handle this better.
    res.redirect(cfg.path.search);
  }
};

/* --------------------------------------------------------
 * pregnancyHistoryAdd()
 *
 * Adds a new historical pregnancy record. Called from the
 * midwife interview screen.
 * -------------------------------------------------------- */
var pregnancyHistoryAdd = function(req, res) {
  var supervisor = null
    , flds = req.body
    , pregHistRec
    ;

  if (req.paramPregnancy &&
      req.body &&
      req.paramPregnancy.id &&
      req.body.pregnancy_id &&
      req.paramPregnancy.id == req.body.pregnancy_id) {

    if (hasRole(req, 'student')) {
      supervisor = req.session.supervisor.id;
    }
    pregHistRec = new PregnancyHistory(flds);
    pregHistRec
      .setUpdatedBy(req.session.user.id)
      .setSupervisor(supervisor)
      .save().then(function(model) {
        res.redirect(cfg.path.pregnancyHistoryAddForm.replace(/:id/, model.get('pregnancy_id')));
      })
      .caught(function(err) {
        logError(err);
        // TODO: handle this better.
        res.redirect(cfg.path.search);
      });

  } else {
    logError('Error in update of pregnancyHistory: pregnancy not found.');
    // TODO: handle this better.
    res.redirect(cfg.path.search);
  }
};

/* --------------------------------------------------------
 * pregnancyHistoryDelete()
 *
 * Deletes a new historical pregnancy record. Called from the
 * midwife interview screen.
 * -------------------------------------------------------- */
var pregnancyHistoryDelete = function(req, res) {
  var supervisor = null
    , flds = req.body
    , pregHistRec
    ;

  if (req.paramPregnancy &&
      req.body &&
      req.paramPregnancy.id &&
      req.body.pregnancy_id &&
      req.paramPregnancy.id == req.body.pregnancy_id) {

    if (hasRole(req, 'student')) {
      supervisor = req.session.supervisor.id;
    }
    flds.id = parseInt(flds.id, 10);
    flds.pregnancy_id = parseInt(flds.pregnancy_id, 10);

    pregHistRec = new PregnancyHistory({id: flds.id, pregnancy_id: flds.pregnancy_id});
    pregHistRec
      .setUpdatedBy(req.session.user.id)
      .setSupervisor(supervisor)
      .destroy().then(function() {
        var path = cfg.path.pregnancyMidwifeEdit
          ;
        path = path.replace(/:id/, flds.pregnancy_id);
        res.redirect(path);
      })
      .caught(function(err) {
        logError(err);
        // TODO: handle this better.
        res.redirect(cfg.path.search);
      });
  } else {
    logError('Error in update of pregnancyHistory: pregnancy not found.');
    // TODO: handle this better.
    res.redirect(cfg.path.search);
  }
};

/* --------------------------------------------------------
 * prenatalEdit()
 *
 * Display the edit form for the prenatal information.
 * -------------------------------------------------------- */
var prenatalEdit = function(req, res) {
  var data = getCommonFormData(req, {title: req.gettext('Prenatal')})
    ;
  if (req.paramPregnancy) {
    res.render('prenatal', data);
  } else {
    // Pregnancy not found.
    res.redirect(cfg.path.search);
  }
};

/* --------------------------------------------------------
 * prenatalUpdate()
 *
 * Update the high-level prenatal information about the
 * pregnancy.
 * -------------------------------------------------------- */
var prenatalUpdate = function(req, res) {
  var supervisor = null
    , pnFlds = {}
    , defaultFlds = {
        philHealthMCP: '0'
        , philHealthNCP: '0'
        , philHealthApproved: '0'
        , useAlternateEdd: '0'
        , riskPresent: '0'
        , riskObHx: '0'
        , riskMedHx: '0'
        , sureLMP: '0'
      }
    ;

  if (req.paramPregnancy &&
      req.body &&
      req.paramPregnancy.id &&
      req.body.id &&
      req.paramPregnancy.id == req.body.id) {

    if (hasRole(req, 'student')) {
      supervisor = req.session.supervisor.id;
    }

    // --------------------------------------------------------
    // Allow 'unchecking' a box by providing a default of off.
    // --------------------------------------------------------
    pnFlds = _.defaults(_.omit(req.body, ['_csrf']), defaultFlds);

    Pregnancy.forge({id: pnFlds.id})
      .fetch().then(function(pregnancy) {
        pregnancy
          .setUpdatedBy(req.session.user.id)
          .setSupervisor(supervisor)
          .save(pnFlds).then(function(pregnancy) {
            req.flash('info', req.gettext('Pregnancy was updated.'));
            res.redirect(cfg.path.pregnancyPrenatalEdit.replace(/:id/, pregnancy.id));
          })
          .caught(function(err) {
            logError(err);
            res.redirect(cfg.path.search);
          });

      })
      .caught(function(err) {
        logError(err);
        res.redirect(cfg.path.search);
      });
  } else {
    logError('Error in update of prenatal information: pregnancy not found.');
    res.redirect(cfg.path.search);
  }
};

var prenatalExamAddForm = function(req, res) {
  var data = {title: req.gettext('Add Prenatal Exam')};
  if (req.paramPregnancy) {
    res.render('prenatalAddEditExam', getCommonFormData(req, data));
  } else {
    // Pregnancy not found.
    res.redirect(cfg.path.search);
  }
};

/* --------------------------------------------------------
 * clerkPermittedFields()()
 *
 * Clerks have restrictions on which fields they can change
 * on prenatal exams. Clerks can only change these fields:
 *    weight, systolic, diastolic, date
 *
 * These fields necessarily need to have values:
 *    id, pregnancy_id, _csrf
 *
 * Therefore, only the allowed fields are returned.
 *
 * param    flds - the flds fron req.body
 * return   flds - the flds that are allowed
 * -------------------------------------------------------- */
var clerkPermittedFields = function(flds) {
  return _.pick(flds,
      'weight','systolic','diastolic','date','_csrf','pregnancy_id', 'id');
};

var prenatalExamAdd = function(req, res, next) {
  var supervisor = null
    , flds = req.body
    , disAllowed
    , pass
    , preRec
    , unauth
    ;

  if (req.paramPregnancy &&
      req.body &&
      req.paramPregnancy.id &&
      req.body.pregnancy_id &&
      req.paramPregnancy.id == req.body.pregnancy_id) {

    if (hasRole(req, 'student')) {
      supervisor = req.session.supervisor.id;
    }

    // --------------------------------------------------------
    // The form should disable the fields that clerks should
    // not change but should that fail, this check will
    // eliminate any fields that are disallowed.
    // --------------------------------------------------------
    if (hasRole(req, 'clerk')) {
      flds = clerkPermittedFields(flds);
    }

    preRec = new PrenatalExam(flds);
    preRec
      .setUpdatedBy(req.session.user.id)
      .setSupervisor(supervisor)
      .save(flds, {method: 'insert'}).then(function(model) {
        var pregId = model.get('pregnancy_id');
        req.flash('info', req.gettext('Prenatal Exam was saved.'));
        res.redirect(cfg.path.pregnancyPrenatalEdit.replace(/:id/, pregId));
      })
      .caught(function(err) {
        logError(err);
        // TODO: handle this better.
        res.redirect(cfg.path.search);
      });

  } else {
    logError('Error in add of prenatal exam: pregnancy not found.');
    // TODO: handle this better.
    res.redirect(cfg.path.search);
  }
};

var prenatalExamEditForm = function(req, res) {
  var data = {title: req.gettext('Edit Prenatal Exam')};
  if (req.paramPregnancy) {
    res.render('prenatalAddEditExam', getCommonFormData(req, data));
  } else {
    // Pregnancy not found.
    res.redirect(cfg.path.search);
  }
};

var prenatalExamEdit = function(req, res) {
  var supervisor = null
    , flds = _.omit(req.body, ['_csrf'])
    , preRec
    , defaultFlds = {
        mvmt: '0'
        , edma: '0'
        , risk: '0'
        , vitamin: '0'
        , pray: '0'
      }
    ;

  if (req.paramPregnancy &&
      req.body &&
      req.paramPregnancy.id &&
      req.body.pregnancy_id &&
      req.paramPregnancy.id == req.body.pregnancy_id) {

    if (hasRole(req, 'student')) {
      supervisor = req.session.supervisor.id;
    }

    // --------------------------------------------------------
    // The form should disable the fields that clerks should
    // not change but should that fail, this check will
    // eliminate any fields that are disallowed.
    // --------------------------------------------------------
    if (hasRole(req, 'clerk')) {
      flds = clerkPermittedFields(flds);
    }

    // --------------------------------------------------------
    // Allow 'unchecking' a box by providing a default of off.
    // --------------------------------------------------------
    flds = _.defaults(flds, defaultFlds);

    preRec = new PrenatalExam(flds);
    preRec
      .setUpdatedBy(req.session.user.id)
      .setSupervisor(supervisor)
      .save(flds, {patch: true, method: 'update'}).then(function(model) {
        var path = cfg.path.pregnancyPrenatalEdit
          ;
        path = path.replace(/:id/, flds.pregnancy_id);
        res.redirect(path);
      })
      .caught(function(err) {
        logError(err);
        // TODO: handle this better.
        res.redirect(cfg.path.search);
      });

  } else {
    logError('Error in update of pregnancyHistory: pregnancy not found.');
    // TODO: handle this better.
    res.redirect(cfg.path.search);
  }
};

var prenatalExamDelete = function(req, res) {
  var supervisor = null
    , flds = req.body
    , peRec
    ;

  if (req.paramPregnancy &&
      req.body &&
      req.paramPregnancy.id &&
      req.body.pregnancy_id &&
      req.paramPregnancy.id == req.body.pregnancy_id) {

    if (hasRole(req, 'student')) {
      supervisor = req.session.supervisor.id;
    }
    flds.id = parseInt(flds.id, 10);
    flds.pregnancy_id = parseInt(flds.pregnancy_id, 10);

    peRec = new PrenatalExam({id: flds.id, pregnancy_id: flds.pregnancy_id});
    peRec
      .setUpdatedBy(req.session.user.id)
      .setSupervisor(supervisor)
      .destroy().then(function() {
        var path = cfg.path.pregnancyPrenatalEdit
          ;
        path = path.replace(/:id/, flds.pregnancy_id);
        res.redirect(path);
      })
      .caught(function(err) {
        logError(err);
        // TODO: handle this better.
        res.redirect(cfg.path.search);
      });
  } else {
    logError('Error in update of pregnancyHistory: pregnancy not found.');
    // TODO: handle this better.
    res.redirect(cfg.path.search);
  }
};

// --------------------------------------------------------
// Initialize the module.
// --------------------------------------------------------
init();

module.exports = {
  addForm: addForm
  , create: create
  , load: load
  , editForm: editForm
  , update: update
  , history: history
  , quesEdit: quesEdit
  , quesUpdate: quesUpdate
  , midwifeEdit: midwifeEdit
  , midwifeUpdate: midwifeUpdate
  , pregnancyHistoryAddForm: pregnancyHistoryAddForm
  , pregnancyHistoryAdd: pregnancyHistoryAdd
  , pregnancyHistoryEditForm: pregnancyHistoryEditForm
  , pregnancyHistoryEdit: pregnancyHistoryEdit
  , pregnancyHistoryDelete: pregnancyHistoryDelete
  , prenatalEdit: prenatalEdit
  , prenatalUpdate: prenatalUpdate
  , prenatalExamAddForm: prenatalExamAddForm
  , prenatalExamAdd: prenatalExamAdd
  , prenatalExamEditForm: prenatalExamEditForm
  , prenatalExamEdit: prenatalExamEdit
  , prenatalExamDelete: prenatalExamDelete
};

