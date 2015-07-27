isInfinity = (val) ->
  if val > myJobs.forever - 7199254740935
    "∞"
  else
    val

reactiveDate = new ReactiveVar(new Date())

Template.jobslist.helpers
  jobId: () ->
    "#{this._id.valueOf().substr(0,5)}…"

  numRepeats: () -> isInfinity this._doc.repeats

  numRetries: () -> isInfinity this._doc.retries

  runAt: () ->
    reactiveDate.get()
    moment(this._doc.after).fromNow()

  lastUpdated: () ->
    reactiveDate.get()
    moment(this._doc.updated).fromNow()

  futurePast: () ->
    reactiveDate.get()
    if this._doc.after > new Date()
      "text-danger"
    else
      "text-success"
