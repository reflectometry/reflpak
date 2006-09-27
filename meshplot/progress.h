#ifndef _PROGRESS_H
#define _PROGRESS_H

#include <iostream>
#include <cmath>

// FIXME convert assert statements to exceptions

class ProgressMeter
{
 private:
  // Note: variables undefined unless _raised is true
  // We'll rely on good behaviour from the derived classes
  bool _raised;
  double _min,_current,_max;
  int _interruptable;
  std::string _name;

 protected:
  // The subclass needs to provide these methods:
  //   raise() displays a new progress meter
  //   lower() clears the progress meter
  //   update(from,to) moves the progress meter from the
  //      old location to the new location, from and to
  //      being values in [0,1].
  // The subclass also needs a destructor which checks 
  // if raised() and calls lower().
  virtual void raise(void) = 0;
  virtual bool update(double from, double to) = 0;
  virtual void lower(void) = 0;

  // FIXME decide what to do in case of error during raise/lower
  // These may be the result of an error in the user supplied
  // script function which renders the progress bar in the GUI.
  // (1) throw an exception in raise/lower/update
  // (2) return boolean from raise/lower if there is an error
  // (3) log the error in a journal but otherwise do nothing
  // Current implementations do #3.

  // The subclass can use these methods:
  //   raised() is needed by the virtual destructor
  //   interruptable() if the progress meter can have a cancel
  //       option (this is usually true)
  //   minimum(), maximum() in case the meter wants to show
  //       a scale; FIXME do we want an integer flag as well?
  //   name() is the string to display on the meter
  inline bool raised(void) const { return _raised; }
  inline bool interruptable(void) const { return _interruptable; }
  inline double minimum(void) const { return _min; }
  inline double maximum(void) const { return _max; }
  inline const std::string& name(void) const { return _name; }

  // The base class needs this method:
  //   progress(v) converts a value on the scale into a [0,1] portion
  inline double progress(double v) const { return (v-_min)/(_max-_min); }
  
 public:
  ProgressMeter() : _raised(false) {}
  virtual ~ProgressMeter() {}

  // The computation calls the following:
  //   start(name,min,max,interruptable=true)   
  //     Initialize the progress meter.  Name is a description
  //     of the work to be done.  [min,max] is the range of
  //     values (e.g., when processing records 1435 to 2700).
  //     Interruptable says whether the program will respond
  //     to the cancel operation or if it will continue until
  //     the work is completed.
  //   step(value)
  //     Move the progress meter to a new value.  The value
  //     must be greater than the previous value and within [min,max]
  //     Return false if the user signals abort.
  //   stop()
  //     Remove the progress meter.
  void start(std::string name, double min, double max, 
	     bool interruptable = true)
  {
    assert(!_raised);
    _name = name;
    _min = _current = min;
    _max = max;
    _interruptable = interruptable;
    this->raise();
    _raised = true;
  }
  bool step(double value) {
    assert(_raised); // Check that start() has been called
    assert(value >= _current); // Check that step is increasing
    assert(value >= _min && value <= _max); // Check it is in range

    bool status = this->update(progress(_current),progress(value));
    _current = value;
    return status;
  }
  void stop(void) {
    assert(_raised);
    this->lower();
    _raised = false;
  }

  // FIXME: may want to tie into a journalling mechanism to report
  // debugging statements, warnings and error messages.  This interface
  // should probably look like an output stream so that it is easy
  // for users to report errors.

} ;



// NoMeter is a progress meter that doesn't report progress
class NoMeter : public ProgressMeter
{
 protected:
  void raise(void) { }
  bool update(double from, double to) { return true; }
  void lower(void) { }
 public:
  ~NoMeter() {}
} ;



// TextMeter is a progress meter that reports progress to a terminal
// The output will look something like the following, with each '.' 
// representing 2% complete.
//
//    TextMeter example
//    ....1....2....3....4..
//
class TextMeter : public ProgressMeter
{
 public:
  ~TextMeter() { 
    // Need to check for 'raised' in the destructor; this can happen if
    // for example the computation throws an exception before calling
    // lower.
    if (raised()) lower(); 
  }
 protected:
  void raise(void) {
    // Raise starts the notification stream.  
    // At this point name(), minimum() and maximum() will be defined,
    // as well as whether the computation is interruptable().
    std::cout << name() << std::endl;
  }
  bool update(double from, double to) {
    // Update lets the user know that the notification should have
    // moved from 'from' to 'to'.  The values of 'from' and 'to' are
    // reported as fractions from 0 to 1.  The value of 'from' is at
    // least as large as 'to'.
    const int start = 2*int(floor(from*50));
    const int end = 2*int(floor(to*50));
    for (int i=start+2; i <= end; i+=2) {
      char ch = i%100 == 0 ? '#' : ( i%10==0 ? '0'+(i/10)%10 : '.' );
      std::cout << ch;
    }
    std::cout << std::flush;
    return true;
  }
  void lower(void) {
    // Lower ends the notification stream.  At this point it is safe to
    // clear any notification window.
    std::cout << std::endl;
  }

} ;


#endif
