#ifndef _TKMETER_H
#define _TKMETER_H

#include "progress.h"

// Call back to Tcl to implement a progress meter.
class TkMeter : public ProgressMeter
{
  Tcl_Interp* _interp;
  std::string _fn;

 public:
  // FIXME in a 'reasonable' scripting language you may need
  // to provide a data bundle in addition to the function name.
  // We can get away without it here because the function name
  // can be something like "tofnref::progress .tofnref_loading"
  TkMeter(Tcl_Interp *interp, Tcl_Obj *fn) 
    : _interp(interp), _fn(Tcl_GetString(fn)) { }
  ~TkMeter() { if (raised()) lower(); }
 protected:
  void raise() {
    // Subst 'raise {name}' for %a in command
    std::string cmd(_fn);
    int idx = cmd.find("%a");
    if (idx >= 0) cmd.replace(idx,2,"raise {"+name()+"}");
    // FIXME need better handling of interpreter errors
    Tcl_Eval(_interp, cmd.c_str());
  }
  void lower() {
    // Subst 'lower' for %a in command
    std::string cmd(_fn);
    int idx = cmd.find("%a");
    if (idx >= 0) cmd.replace(idx,2,"lower");
    // FIXME need better handling of interpreter errors
    Tcl_Eval(_interp, cmd.c_str());
  }
  bool update(double from, double to) {
    // Subst 'update from to' for %a in command
    char args[100];
    sprintf(args," update %g %g",from,to);
    std::string cmd(_fn);
    int idx = cmd.find("%a");
    if (idx >= 0) cmd.replace(idx,2,args);

    // Call the interpreter, ignoring errors
    // FIXME need better handling of interpreter errors
    int result;
    Tcl_ResetResult(_interp);
    result = Tcl_Eval(_interp, cmd.c_str());
    if (result != TCL_OK) return true;

    // Get return flag from update
    int val;
    result = Tcl_GetBooleanFromObj(_interp, Tcl_GetObjResult(_interp), &val);
    if (result != TCL_OK) return true;

    return val == 1;
  }
} ;


#endif // _TKMETER_H
