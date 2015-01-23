// Generated by CoffeeScript 1.8.0
var Contact, americano, async, log, stream_to_buffer_array,
  __indexOf = [].indexOf || function(item) { for (var i = 0, l = this.length; i < l; i++) { if (i in this && this[i] === item) return i; } return -1; };

americano = require(MODEL_MODULE);

async = require('async');

stream_to_buffer_array = require('../utils/stream_to_array');

log = require('../utils/logging')({
  prefix: 'models:contact'
});

module.exports = Contact = americano.getModel('Contact', {
  id: String,
  fn: String,
  n: String,
  datapoints: function(x) {
    return x;
  },
  note: String,
  tags: function(x) {
    return x;
  },
  _attachments: Object
});

Contact.prototype.includePicture = function(callback) {
  var stream, _ref;
  if ((_ref = this._attachments) != null ? _ref.picture : void 0) {
    stream = this.getFile('picture', (function(_this) {
      return function(err) {
        if (err != null) {
          return log.error("Contact " + _this.id + " getting picture", err);
        }
      };
    })(this));
    return stream_to_buffer_array(stream, (function(_this) {
      return function(err, parts) {
        var avatar, base64;
        if (err) {
          return callback(err);
        }
        base64 = Buffer.concat(parts).toString('base64');
        avatar = "data:image/jpeg;base64," + base64;
        if (_this.datapoints == null) {
          _this.datapoints = [];
        }
        _this.datapoints.push({
          name: 'avatar',
          value: avatar
        });
        return callback(null, _this);
      };
    })(this));
  } else {
    return callback(null, this);
  }
};

Contact.requestWithPictures = function(name, options, callback) {
  log.info("requestWithPictures");
  return Contact.request(name, options, function(err, contacts) {
    var out, outids;
    outids = [];
    out = [];
    if (contacts != null) {
      return async.eachSeries(contacts, function(contact, cb) {
        var _ref;
        if (_ref = contact.id, __indexOf.call(outids, _ref) >= 0) {
          return cb(null);
        }
        return contact.includePicture(function(err, contactWIthPicture) {
          if (err) {
            return cb(err);
          }
          outids.push(contact.id);
          out.push(contactWIthPicture);
          return cb(null);
        });
      }, function(err) {
        return callback(err, out);
      });
    } else {
      return callback(null, []);
    }
  });
};

Contact.createNoDuplicate = function(data, callback) {
  var key;
  log.info("createNoDuplicate");
  key = data.address;
  return Contact.request('byEmail', {
    key: data.address
  }, function(err, existings) {
    var contact;
    if (err) {
      return callback(err);
    }
    if ((existings != null ? existings.length : void 0) > 0) {
      return callback(null, existings);
    }
    contact = {
      fn: data.name,
      datapoints: [
        {
          name: "email",
          value: data.address
        }
      ]
    };
    return Contact.create(contact, function(err, created) {
      if (err) {
        return callback(err);
      }
      return Contact.request('byEmail', {
        key: key
      }, callback);
    });
  });
};
