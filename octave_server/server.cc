#define STATUS(x) do { if (debug) std::cout << x << std::endl << std::flush; } while (0)

//#define HAVE_OCTAVE_30
#include <iomanip>
#include <iostream>
#include <cstdio>
#include <cctype>
#include <cstdlib>
//#include <unistd.h>
//#include <stdint.h>
#include <cerrno>
// #include <string.h>
#include <sys/types.h>

#if (defined(_WIN32)||defined(_WIN64)) && !defined(__CYGWIN__)
# define USE_WINSOCK
# define CAN_FORK false
# include <winsock.h>
# include <io.h>
  typedef int socklen_t;
#else
# define HAVE_FORK 1
# define USE_SIGNALS
# if defined(__CYGWIN__)
#  define CAN_FORK listencanfork()
# else
#  define USE_DAEMONIZE
#  define CAN_FORK true
# endif
# include <sys/socket.h>
# include <netinet/in.h>
# include <arpa/inet.h>
# include <sys/wait.h>
# include <signal.h>
# define closesocket close
#endif


#include <octave/oct.h>
#include <octave/parse.h>
#include <octave/variables.h>
#if 0
#include <octave/unwind-prot.h>
#endif
#include <octave/oct-syscalls.h>
#include <octave/oct-time.h>
#include <octave/lo-mappers.h>
#include <octave/symtab.h>

static bool debug = false;
static char* context = NULL;

static double timestamp = 0.0;
inline void tic(void) { timestamp = octave_time().double_value(); }
inline double toc(void) {return ceil(-1e6*(timestamp-octave_time().double_value()));}

// XXX FIXME XXX --- surely this is part of the standard library?
void
lowercase (std::string& s)
{
  for (std::string::iterator i=s.begin(); i != s.end(); i++) *i = tolower(*i);
}

#if 0
octave_value
get_builtin_value (const std::string& nm)
{
  octave_value retval;

  symbol_record *sr = fbi_sym_tab->lookup (nm);

  if (sr)
    {
      octave_value sr_def = sr->def ();

      if (sr_def.is_undefined ())
        error ("get_builtin_value: undefined symbol `%s'", nm.c_str ());
      else
        retval = sr_def;
      }
  else
    error ("get_builtin_value: unknown symbol `$s'", nm.c_str ());

  return retval;
}
#endif

#ifdef USE_WINSOCK
  bool init_sockets()
  {

  WSADATA wsaData;
  WORD version;
  int error;

  version = MAKEWORD( 2, 0 );

  error = WSAStartup( version, &wsaData );

  /* check for error */
  if ( error != 0 )
  {
    /* error occured */
    return false;
  }

  /* check for correct version */
  if ( LOBYTE( wsaData.wVersion ) != 2 ||
       HIBYTE( wsaData.wVersion ) != 0 )
  {
      /* incorrect WinSock version */
      WSACleanup();
      return false;
  }
  return true;
  }

  inline void end_sockets() { WSACleanup(); }
  inline int socket_errno() { return WSAGetLastError(); }
#else // !USE_WINSOCK
# include <cerrno>
  inline bool init_sockets() { return true; }
  inline void end_sockets() { }
  inline int socket_errno() { return errno; }
#endif // !USE_WINSOCK
inline void socket_error(const char *context)
{
  int err = socket_errno();
  char errno_str[15];
  snprintf(errno_str, sizeof(errno_str), " %d: ", err);
  std::string msg = std::string(context) + std::string(errno_str) 
                  + std::string (strerror(err));
  error(msg.c_str());
}

#ifdef USE_SIGNALS
static void
sigchld_handler(int /* sig */)
{
  int status;
  /* Reap all childrens */
  STATUS("reaping all children");
  while (waitpid(-1, &status, WNOHANG) > 0)
    ;
  STATUS("done reaping children");
}

/* Posix signal handling, based on the example from the
 * Unix Programming FAQ 
 * Copyright (C) 2000 Andrew Gierth
 */
static void sigchld_setup(void)
{
  struct sigaction act;

  /* Assign sig_chld as our SIGCHLD handler */
  act.sa_handler = sigchld_handler;

  /* We don't want to block any other signals in this example */
  sigemptyset(&act.sa_mask);
  
  /*
   * We're only interested in children that have terminated, not ones
   * which have been stopped (eg user pressing control-Z at terminal)
   */
  act.sa_flags = SA_NOCLDSTOP;

  /*
   * Make these values effective. If we were writing a real 
   * application, we would probably save the old value instead of 
   * passing NULL.
   */
  if (sigaction(SIGCHLD, &act, NULL) < 0) 
     error("listen could not set SIGCHLD");
}
#else
inline void sigchld_setup(void) { }
#endif


#ifdef USE_DAEMONIZE

static RETSIGTYPE
sigterm_handler(int /* sig */)
{
  exit(0);
}

static void
daemonize(void)
{
  if (fork()) exit(0);  // Stop parent
  // Show child PID
  std::cout << "Octave pid: " << octave_syscalls::getpid() << std::endl;
  std::cout.flush();
  signal(SIGTERM,sigterm_handler);
  signal(SIGQUIT,sigterm_handler);

  // Exit silently if I/O redirect fails.
  if (freopen("/dev/null", "r", stdin) == NULL
      || freopen("/dev/null", "w", stdout) == NULL
      || freopen("/dev/null", "w", stderr)) exit(0);
}

#else
// Don't daemonize on cygwin just yet.
inline void daemonize(void) {}

#endif // !DAEMONIZE



static octave_value get_octave_value(char *name)
{
  octave_value def;

  // Copy variable from octave
#ifdef HAVE_OCTAVE_30
  symbol_record *sr = top_level_sym_tab->lookup (name);
  if (sr) def = sr->def();
#else
  def = symbol_table::varref (std::string (name), symbol_table::top_scope ());
#endif

  return def;
}


static void channel_error (const int channel, const char *str)
{
  STATUS("sending error !!!e (" << strlen(str) << ") " << str);

  uint32_t len = strlen(str);
  send(channel,"!!!e",4,0);
  uint32_t t = htonl(len); send(channel,(const char *)&t,4,0);
  send(channel,str,len,0);
}

static bool reads (const int channel, void * buf, int n)
{
  // STATUS("entering reads loop with size " << n); tic();
  while (1) {
    int chunk = recv(channel, (char *)buf, n, 0);
    if (chunk == 0) STATUS("read socket returned 0");
    if (chunk < 0) STATUS("read socket error " << socket_errno());
    if (chunk <= 0) return false;
    n -= chunk;
    // if (n == 0) STATUS("done reads loop after " << toc() << "us");
    if (n == 0) return true;
    // STATUS("reading remaining " << n << " characters");
    buf = (void *)((char *)buf + chunk);
  }
}

static bool writes (const int channel, const void * buf, int n)
{
  // STATUS("entering writes loop");
  while (1) {
    int chunk = send(channel, (const char *)buf, n, 0);
    if (chunk == 0) STATUS("write socket returned 0");
    if (chunk < 0) STATUS("write socket: " << strerror(errno));
    if (chunk <= 0) return false;
    n -= chunk;
    // if (n == 0) STATUS("done writes loop");
    if (n == 0) return true;
    buf = (void *)((char *)buf + chunk);
  }
}

static void
process_commands(int channel)
{
  // XXX FIXME XXX check read/write return values
  assert(sizeof(uint32_t) == 4);
  char command[5];
  char def_context[16536];
  bool ok;
  STATUS("waiting for command");

  // XXX FIXME XXX do we need to specify the context size?
  //  int bufsize=sizeof(def_context);
  //  socklen_t ol;
  //  ol=sizeof(bufsize);
  //  setsockopt(channel,SOL_SOCKET,SO_SNDBUF,&bufsize,ol);
  //  setsockopt(channel,SOL_SOCKET,SO_RCVBUF,&bufsize,ol);

  // XXX FIXME XXX prepare to capture long jumps, because if
  // we dont, then errors in octave might escape to the prompt

  command[4] = '\0';
  if (debug) tic();
  while (reads(channel, &command, 4)) {
    // XXX FIXME XXX do whatever is require to check if function files
    // have changed; do we really want to do this for _every_ command?
    // Maybe we need a 'reload' command.
    STATUS("received command " << command << " after " << toc() << "us");
    
    // Check for magic command code
    if (command[0] != '!' || command[1] != '!' || command[2] != '!') {
      STATUS("communication error: closing connection");
      break;
    }

    // Get command length
    if (debug) tic(); // time the read
    uint32_t len;
    if (!reads(channel, &len, 4)) break;
    len = ntohl(len);
    // STATUS("read 4 byte command length in " << toc() << "us"); 

    // Read the command context, allocating a new one if the default
    // is too small.
    if (len > (signed)sizeof(def_context)-1) {
      // XXX FIXME XXX use octave allocators
      // XXX FIXME XXX unwind_protect
      context= new char[len+1];
      if (context== NULL) {
	// Requested command is too large --- skip to the next command
	// XXX FIXME XXX maybe we want to kill the connection instead?
	channel_error(channel,"out of memory");
	ok = true;
	STATUS("skip big command loop");
	while (ok && len > (signed)sizeof(def_context)) {
	  ok = reads(channel, def_context, sizeof(def_context));
	  len -= sizeof(def_context);
	}
	STATUS("done skip big command loop");
	if (!ok) break;
	ok = reads(channel, def_context, sizeof(def_context));
	if (!ok) break;
	continue;
      }
    } else {
      context = def_context;
    }
    // if (debug) tic();
    ok = reads(channel, context, len);
    context[len] = '\0';
    STATUS("read " << len << " byte command in " << toc() << "us");

    // Process the command
    if (ok) switch (command[3]) {
    case 'm': // send the named matrix 
      {
	// XXX FIXME XXX this can be removed: app can do send(name,value)
	STATUS("sending " << context);
	uint32_t t;
	
	// read the matrix contents
	octave_value def = get_octave_value(context);
	if(!def.is_defined() || !def.is_real_matrix()) 
	  channel_error(channel,"not a matrix");
	Matrix m = def.matrix_value();
	
	// write the matrix transfer header
	ok = writes(channel,"!!!m",4);                // matrix message
	t = htonl(12 + sizeof(double)*m.rows()*m.columns());
	if (ok) ok = writes(channel,&t,4);            // length of message
	t = htonl(m.rows()); 
	if (ok) ok = writes(channel,&t,4);            // rows
	t = htonl(m.columns()); 
	if (ok) ok = writes(channel,&t,4);            // columns
	t = htonl(len); 
	if (ok) ok = writes(channel, &t, 4);          // name length
	if (ok) ok = writes(channel,context,len);      // name
	
	// write the matrix contents
	const double *v = m.data();                   // data
	if (ok) ok = writes(channel,v,sizeof(double)*m.rows()*m.columns());
	if (ok)
	  STATUS("sent " << m.rows()*m.columns());
	else
	  STATUS("failed " << m.rows()*m.columns());
      }
      break;
      
    case 'x': // silently execute the command
      {
	if (debug) 
	  {
	    if (len > 500) 
	      {
		// XXX FIXME XXX can we limit the maximum output width for a
		// string?  The setprecision() io manipulator doesn't do it.
		// In the meantime, a hack ...
		char t = context[400]; context[400] = '\0';
		STATUS("evaluating (" << len << ") " 
		       << context << std::endl 
		       << "..." << std::endl 
		       << context+len-100);
		context[400] = t;
	      }
	    else
	      {
		STATUS("evaluating (" << len << ") " << context);
	      }
	  }

	if (debug) tic();
#if 1
        error_state = 0;
	int parse_status = 0;
        eval_string(context, true, parse_status, 0);
        if (parse_status != 0 || error_state)
            eval_string("senderror(lasterr);", true, parse_status, 0);
#elif 0
	octave_value_list evalargs;
	evalargs(1) = "senderror(lasterr);";
	evalargs(0) = context;
	octave_value_list fret = feval("eval",evalargs,0);
#else
	evalargs(0) = octave_value(0.);
#endif
	STATUS("done command");
      }
      STATUS("free evalargs");
      break;
      
    case 'c': // execute the command and capture stdin/stdout
      STATUS("capture command not yet implemented");
      break;
      
    default:
      STATUS("ignoring command " << command);
      break;
    }

    if (context != def_context) delete[] context;
    STATUS("done " << command);
    if (!ok) break;
    if (debug) tic();
  }
}


int channel = -1;

DEFUN_DLD(senderror,args,,"\
Send the given error message across the socket.  The error context\n\
is taken to be the last command received from the socket.")
{
  std::string str;
  const int nargin = args.length();
  if (nargin != 1) str="senderror not called with error";
  else str = args(0).string_value();

  // provide a context for the error (but not too much!)
  str += "when evaluating:\n";
  if (strlen(context) > 100) 
    {	
      char t=context[100]; 
      context[100] = '\0'; 
      str+=context; 
      context[100]=t;
    }
  else
    str += context;
 
  STATUS("error is " << str);
  channel_error(channel,str.c_str());
  return octave_value_list();
}

DEFUN_DLD(send,args,,"\
send(str)\n\
  Send a command on the current connection\n\
send(name,value)\n\
  Send a binary value with the given name on the current connection\n\
")
{
  bool ok;
  uint32_t t;
  octave_value_list ret;
  int nargin = args.length();
  if (nargin < 1 || nargin > 2)
    {
      print_usage ();
      return ret;
    }

  if (channel < 0) {
    error("Not presently listening on a port");
    return ret;
  }

  std::string cmd(args(0).string_value());
  if (error_state) return ret;

  // XXX FIXME XXX perhaps process the panalopy of types?
  if (nargin > 1) {
    
    octave_value def = args(1);
    if (args(1).is_string()) {
      // Grab the string value from args(1).
      // Can't use args(1).string_value() because that trims trailing \0
      charMatrix m(args(1).char_matrix_value());
      std::string s(m.row_as_string(0,false,true));
      STATUS("sending string(" << cmd.c_str() << " len " << s.length() << ")");
      ok = writes(channel,"!!!s",4);               // string message
      t = htonl(8 + cmd.length() + s.length());
      if (ok) ok = writes(channel,&t,4);           // length of message
      t = htonl(s.length());
      if (ok) ok = writes(channel, &t, 4);         // string length
      t = htonl(cmd.length());
      if (ok) ok = writes(channel, &t, 4);         // name length
      if (cmd.length() && ok) 
	ok = writes(channel, cmd.c_str(), cmd.length());    // name
      if (s.length() && ok) 
	ok = writes(channel, s.c_str(), s.length());        // string
    } else if (args(1).is_real_type()) {
      Matrix m(args(1).matrix_value());
      STATUS("sending matrix(" << cmd.c_str() << " " 
             <<  m.rows() << "x" << m.columns() << ")");
      
      // write the matrix transfer header
      ok = writes(channel,"!!!m",4);               // matrix message
      t = htonl(12 + cmd.length() + sizeof(double)*m.rows()*m.columns());
      if (ok) ok = writes(channel,&t,4);           // length of message
      t = htonl(m.rows()); 
      if (ok) ok = writes(channel,&t,4);           // rows
      t = htonl(m.columns()); 
      if (ok) ok = writes(channel,&t,4);           // columns
      t = htonl(cmd.length()); 
      if (ok) ok = writes(channel, &t, 4);         // name length
      if (ok) ok = writes(channel, cmd.c_str(), cmd.length());    // name
      
      // write the matrix contents
      const double *v = m.data();                  // data
      if (m.rows()*m.columns() && ok) 
	ok = writes(channel,v,sizeof(double)*m.rows()*m.columns());
    } else {
      ok = false;
      error("send expected name and matrix or string value");
    }
    if (!ok) error("send could not write to channel");
  } else {
    STATUS("sending command(" << cmd.length() << ") " << cmd.c_str());
    // STATUS("start writing at "<<toc()<<"us");
    ok = writes(channel, "!!!x", 4);
    t = htonl(cmd.length()); writes(channel, &t, 4);
    if (ok) ok = writes(channel, cmd.c_str(), cmd.length());
    if (!ok) error("send could not write to channel");
    // STATUS("stop writing at "<<toc()<<"us");
  }

  return ret;
}

extern "C" int listencanfork(void);
extern "C" int StringCaseMatch(const char* s, const char* p, int nocase);

bool ishostglob(const std::string& s)
{
  for (unsigned int i=0; i < s.length(); i++) {
    if (! ( isdigit(s[i]) || s[i]=='*' || s[i]=='-' 
	   || s[i]=='.' || s[i]=='[' || s[i]==']')) return false;
  }
  return true;
}

bool anyhostglob(const string_vector& hostlist, const char* host)
{
  for (int j=0; j < hostlist.length(); j++) {
    if (StringCaseMatch(host, hostlist[j].c_str(), 0)) return true;
  }
  return false;
}

// Known bug: functions which pass or return structures use a
// different ABI for gcc and native compilers on some architectures.
// Whether this is a bug depends on the structure length.  SGI's 64-bit
// architecture makes this a problem for inet_ntoa.
#if defined(__GNUC__) && defined(_sgi)
#define BROKEN_INET_NTOA
#endif

#ifdef BROKEN_INET_NTOA

/*************************************************
*         Replacement for broken inet_ntoa()     *
*************************************************/


/* On IRIX systems, gcc uses a different structure passing convention to the
native libraries. This causes inet_ntoa() to always yield 0.0.0.0 or
255.255.255.255. To get round this, we provide a private version of the
function here. It is used only if USE_INET_NTOA_FIX is set, which should
happen
only when gcc is in use on an IRIX system. Code send to me by J.T. Breitner,
with these comments:


  code by Stuart Levy
  as seen in comp.sys.sgi.admin


Arguments:  sa  an in_addr structure
Returns:        pointer to static text string
*/


char *
inet_ntoa(struct in_addr sa)
{
static char addr[20];
sprintf(addr, "%d.%d.%d.%d",
        (US &sa.s_addr)[0],
        (US &sa.s_addr)[1],
        (US &sa.s_addr)[2],
        (US &sa.s_addr)[3]);
  return addr;
}

#endif /* BROKEN_INET_NTOA */


void _autoload(const char name[])
{
  octave_value_list evalargs, fret;
  evalargs(0) = "server";
  fret = feval("which",evalargs,1);
  evalargs(0) = name;
  evalargs(1) = fret(0);
  fret = feval("autoload",evalargs,0);
}

DEFUN_DLD(server,args,,"\
server(port,host,host,...)\n\
   Listen for connections on the given port.  Normally only accepts\n\
   connections from localhost (127.0.0.1), but you can specify any\n\
   dot-separated host name globs.  E.g., '128.2.20.*' or '128.2.2[012].*'\n\
   Use '?' for '[0123456789]'. Use '*.*.*.*' for any host.\n\
server(...,'debug'|'nodebug')\n\
   If debug, echo all commands sent across the connection.  If nodebug,\n\
   detach the process and don't echo anything.  You will need to use\n\
   kill directly to end the process. Nodebug is the default.\n\
server(...,'fork'|'nofork')\n\
   If fork, start new server for each connection.  If nofork, only allow\n\
   one connection at a time. Fork is the default (depending on system).\n\
server(...,'loopback')\n\
   Use loopback address 127.0.0.1 rather than 0.0.0.0.\n\
")
{
  bool canfork = CAN_FORK;

  _autoload("send");
  _autoload("senderror");
  octave_value_list ret;
  int nargin = args.length();
  if (nargin < 1)
    {
      print_usage ();
      return ret;
    }
  int port = args(0).int_value();
  if (error_state) return ret;

  // Winsock requires initialization
  if (!init_sockets())
	{
	  socket_error("init");
	  return ret;
    }


  debug = false;
  uint32_t inaddr = INADDR_ANY;

  string_vector hostlist;
  hostlist.append(std::string("127.0.0.1"));
  for (int k = 1; k < nargin; k++) {
    std::string lastarg(args(k).string_value());
    if (error_state) return ret;
    lowercase(lastarg);
    if (lastarg == "debug") {
      debug = true;
    } else if (lastarg == "nodebug") {
      debug = false;
    } else if (lastarg == "fork") {
      canfork = true;
    } else if (lastarg == "nofork") {
      canfork = false;
    } else if (lastarg == "loopback") {
      inaddr = INADDR_LOOPBACK;
    } else if (ishostglob(lastarg)) {
      hostlist.append(lastarg);
    } else {
      print_usage ();
    }
  }

  int sockfd;                    // listen on sockfd, new connection channel
  struct sockaddr_in my_addr;    // my address information
  struct sockaddr_in their_addr; // connector's address information
  socklen_t sin_size;
  int yes=1;

  sockfd = socket(AF_INET, SOCK_STREAM, 0);
  if (sockfd == -1) {
	socket_error("socket");
    return ret;
  }

  if (setsockopt(sockfd,SOL_SOCKET,SO_REUSEADDR,(const char *)(&yes),sizeof(yes)) == -1) {
    socket_error("setsockopt");
    return ret;
  }

  my_addr.sin_family = AF_INET;         // host byte order
  my_addr.sin_port = htons(port);       // short, network byte order
  my_addr.sin_addr.s_addr = htonl(inaddr); // automatically fill with my IP
  memset(&(my_addr.sin_zero), '\0', 8); // zero the rest of the struct
  
  if (bind(sockfd, (struct sockaddr *)&my_addr, sizeof(struct sockaddr))
      == -1) {
    socket_error("bind");
    closesocket(sockfd);
    return ret;
  }
  
  /* listen for connections (allowing one pending connection) */
  if (listen(sockfd, canfork?1:0) == -1) { 
    socket_error("listen");
    closesocket(sockfd);
    return ret;
  }

#if 0
  unwind_protect::begin_frame("Fserver");
  unwind_protect_bool (buffer_error_messages);
  buffer_error_messages = true;
#endif

  sigchld_setup();
  if (!debug && canfork) daemonize();
      
  // XXX FIXME XXX want a 'sandbox' option which disables fopen, cd, pwd,
  // system, popen ...  Or maybe just an initial script to run for each
  // connection, plus a separate command to disable specific functions.
  STATUS("listening on port " << port);
  while(1) {  // main accept() loop
    sin_size = sizeof(struct sockaddr_in);
    STATUS("trying to accept");
    if ((channel = accept(sockfd, (struct sockaddr *)&their_addr,
			 &sin_size)) == -1) {
      // XXX FIXME XXX
      // Linux is returning "Interrupted system call" when the
      // child terminates.  Until I figure out why, I can't use
      // accept errors as a basis for breaking out of the listen
      // loop, so instead print the octave PID so that I can kill
      // it from another terminal.
      STATUS("failed to accept"  << std::endl 
	     << "Octave pid: " << octave_syscalls::getpid() );
      perror("accept");
#if defined(_sgi)
      break;
#else
      continue;
#endif
    }
    STATUS("connected");

    /* Simulate inet_ntoa */
    const char *them = inet_ntoa(their_addr.sin_addr);
    STATUS("server: got connection from " << them);

    if (anyhostglob(hostlist,them)) {
#ifdef HAVE_FORK
      if (canfork) {
        int pid = fork();
        if (pid == -1) {
          socket_error("fork");
          break;
        } else if (pid == 0) {
          closesocket(sockfd);      // child doesn't need listener
          signal(SIGCHLD,SIG_DFL);  // child doesn't need SIGCHLD signal
          process_commands(channel);
          STATUS("child is exitting");
          exit(0);
        }
      } else {
		process_commands(channel);
        STATUS("server: connection closed");
      }
#else // !HAVE_FORK
      process_commands(channel);
      STATUS("server: connection closed");
#endif // !HAVE_FORK
    } else {
      STATUS("server: connection refused.");
    }

    closesocket(channel);
    channel = -1;
  }

  STATUS("could not read commands; returning");
  closesocket(sockfd);
  end_sockets();
#if 0
  unwind_protect::run_frame("Fserver");
#endif
  return ret;
}
