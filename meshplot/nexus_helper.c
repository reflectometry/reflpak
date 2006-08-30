/* This is a work of the United States Government and is not
 * subject to copyright protection in the United States.
 */

#include <inttypes.h>
#include <stdio.h>
#include <string.h>
#include <assert.h>
#include <math.h>
#include <stdlib.h>

#include "nexus_helper.h"

#if 0
#define DEBUG(a) do { printf(a); } while (0)
#else
#define DEBUG(a) do { } while (0)
#endif



void _print_status(Nexus *file, const char *where)
{
  NXname name, class;
  int n, status;

  if (file == NULL) {
    printf("File not open\n");
  } else {
    status = NXgetgroupinfo (file->fid, &n, name, class);
    if (status == NX_OK) 
      printf("%s Entry: %s Group: %s:%s\n",where,file->entry,name,class);
    else 
      printf("%s getgroupinfo failed with %d\n",where,status);
    printf("%s ->expected NXentry:%s/%s/%s\n",
	   where,file->entry,file->_group,file->_field);
  }
}


/* ================================================================== */
/* Private routines:
 * _kind_to_double
 * _double_to_kind
 * _open_key
 * _close_key
 * _read_data_str
 * _read_attr_str
 * _read_data_vector
 * _read_attr_vector
 * _write_data_str
 * _write_attr_str
 * _write_data_vector
 * _write_attr_vector
 */


/* Convert a vector of nexus numeric types into a vector of doubles
 * in place.
 */
static void
_kind_to_double(double data[], int n, int kind)
{
  int i;
  switch (kind) {
  case NX_FLOAT64: break;
  case NX_FLOAT32: for (i=n-1; i>=0; i--) data[i]=((float *)data)[i];    break;
  case NX_INT8:    for (i=n-1; i>=0; i--) data[i]=((int8_t *)data)[i];   break;
  case NX_UINT8:   for (i=n-1; i>=0; i--) data[i]=((uint8_t *)data)[i];  break;
  case NX_INT16:   for (i=n-1; i>=0; i--) data[i]=((int16_t *)data)[i];  break;
  case NX_UINT16:  for (i=n-1; i>=0; i--) data[i]=((uint16_t *)data)[i]; break;
  case NX_INT32:   for (i=n-1; i>=0; i--) data[i]=((int32_t *)data)[i];  break;
  case NX_UINT32:  for (i=n-1; i>=0; i--) data[i]=((uint32_t *)data)[i]; break;
  }
}

/* Convert a vector of doubles to a vector of NX types in place.
 */
static void
_double_to_kind(double data[], int n, int kind)
{
  int i;
  switch (kind) {
  case NX_FLOAT64: break;
  case NX_FLOAT32: for (i=0; i<n; i++) ((float *)data)[i] = data[i];    break;
  case NX_INT8:    for (i=0; i<n; i++) ((int8_t *)data)[i] = data[i];   break;
  case NX_UINT8:   for (i=0; i<n; i++) ((uint8_t *)data)[i] = data[i];  break;
  case NX_INT16:   for (i=0; i<n; i++) ((int16_t *)data)[i] = data[i];  break;
  case NX_UINT16:  for (i=0; i<n; i++) ((uint16_t *)data)[i] = data[i]; break;
  case NX_INT32:   for (i=0; i<n; i++) ((int32_t *)data)[i] = data[i];  break;
  case NX_UINT32:  for (i=0; i<n; i++) ((uint32_t *)data)[i] = data[i]; break;
  }
}


static void
_close_data(Nexus *file)
{
  if (file->_field[0] != '\0') {
    /* printf("closing field %s\n",file->_field); */
    NXclosedata(file->fid);
  }
  file->_field[0] = '\0';
}

static int
_open_data(Nexus *file, const NXname field)
{

  if (strcmp(file->_field, field) != 0) {
    _close_data(file);
    if (field[0] != '\0') {
      /* printf("opening field %s\n",field); */
      if (NXopendata(file->fid,field) != NX_OK) {
	printf("could not open field %s\n",field);
	return 0;
      }
      strcpy(file->_field, field); /* _field and field are both NXname */
    }
  }
  return 1;
}

/* Closes the currently open key (data and group), returning to the 
 * NXentry level. */
static void 
_close_key(Nexus *file)
{
  int i;
  _close_data(file);
  for (i=0; i < file->_depth; i++) NXclosegroup(file->fid);
  file->_depth = 0;
  file->_group[0] = '\0';

  /* FIXME closing NXentry so that when we reopen it we can search
   * for the new key.  We really need a better way of doing checking
   * if a group exists...
   */
  if (file->entry[0] != '\0') {
    NXclosegroup(file->fid);
    NXopengroup(file->fid,file->entry,"NXentry");
  }
}


/* Open the key if it is not already open.
 * Caches the current open group and dataset to save on thrashing during 
 * ordered retrieval.
 */
static int 
_open_key(Nexus *file, const char key[])
{
  const char *group_end, *field_start, *field_end;
  NXname field;
  int grouplen;

  if (file == NULL) return 0;

  /* Parse the key into "group/field.attr"; yields grouplen which is the 
   * length of the group and field which contains the field */
  group_end = strrchr(key,'/');
  if (group_end == NULL) {
    group_end = field_start = key;
  } else {
    field_start=group_end+1;
  }
  grouplen = group_end-key;
  field_end = strrchr(field_start, '.');
  if (field_end == NULL) {
    assert(strlen(field_start) < sizeof(field));
    strcpy(field,field_start);
  } else {
    assert(field_end-field_start < sizeof(field));
    strncpy(field,field_start,field_end-field_start);
    field[field_end-field_start] = '\0';
  }


  /* Check if the correct group is open */
  if (strlen(file->_group) != grouplen 
      || strncmp(key, file->_group, grouplen) != 0) {
    /* Correct group is not open.  Close the current group and open the new */
    _close_key(file);

    /* Save the new group name */
    /* FIXME better failure behaviour needed */
    assert(grouplen < sizeof(file->_group));
    strncpy(file->_group, key, grouplen);
    file->_group[grouplen] = '\0';
    assert(strlen(file->_group)==grouplen);

    /* Step into the new group */
    while (key < group_end) {
      const char *class_end, *name_end;
      NXname name,class;
      int status;
      
      /* Split "class:name/" at the start of key into class and name  */
      class_end = strchr(key,':');
      name_end = strchr(key,'/');
      assert(class_end!=NULL && name_end!=NULL && class_end<name_end);
      assert(class_end-key < sizeof(class));
      assert(name_end-class_end-1 < sizeof(name));
      strncpy(class,key,class_end-key);
      class[class_end-key] = '\0';
      strncpy(name,class_end+1,name_end-class_end-1);
      name[name_end-class_end-1] = '\0';


      /* Attempt to open next level. */
      status = NXopengroup(file->fid, name, class);
      if (status != NX_OK) {
	/* FIXME better error handling */
	_close_key(file);
	return 0;
      }
      key = name_end + 1;
      file->_depth++;
    }
  }

  /* Open the field if it is not already open. */
  return _open_data(file, field);
    
}


static int
_group_exists(NXhandle fid, const char name[], const char class[]) 
{
  NXname tname, tclass;
  int kind;

  /* FIXME need a function which checks whether a group exists
   * without printing an error if it doesn't.  The strategy of
   * scanning through every entry seems wrong.
   *
   * Alternatively, load in entire structure when the file is
   * first opened so that you know the types and locations of
   * each object in the file, and query that structure.
   */
  while (NXgetnextentry(fid, tname, tclass, &kind) == NX_OK) {
    if (strcmp(name,tname) == 0) return 1;
  }
  return 0;
}

/* Open the key if it is not already open.
 * Caches the current open group and dataset to save on thrashing during 
 * ordered retrieval.
 */
static int 
_create_key(Nexus *file, const char key[], NXname field)
{
  const char *group_end, *field_start, *field_end, *attr;
  int grouplen;

  if (file == NULL) return 0;

  /* Parse the key into "group/field.attr"; yields grouplen which is the 
   * length of the group and field which contains the field */
  group_end = strrchr(key,'/');
  if (group_end == NULL) {
    group_end = field_start = key;
  } else {
    field_start=group_end+1;
  }
  grouplen = group_end-key;
  field_end = strrchr(field_start, '.');
  if (field_end == NULL) {
    assert(strlen(field_start) < sizeof(NXname));
    strcpy(field,field_start);
    attr = NULL;
  } else {
    assert(field_end-field_start < sizeof(NXname));
    strncpy(field,field_start,field_end-field_start);
    field[field_end-field_start] = '\0';
    attr = field_end+1;
  }


  /* Check if the correct group is open */
  if (strlen(file->_group) != grouplen 
      || strncmp(key, file->_group, grouplen) != 0) {
    /* Correct group is not open.  Close the current group and open the new */
    _close_key(file);

    /* Save the new group name */
    /* FIXME better failure behaviour needed */
    assert(grouplen < sizeof(file->_group));
    strncpy(file->_group, key, grouplen);
    file->_group[grouplen] = '\0';

    /* Step into the new group */
    while (key < group_end) {
      const char *class_end, *name_end;
      NXname name,class;
      int status;
      
      /* Split "class:name/" at the start of key into class and name  */
      class_end = strchr(key,':');
      name_end = strchr(key,'/');
      assert(class_end!=NULL && name_end!=NULL && class_end<name_end);
      assert(class_end-key < sizeof(NXname));
      assert(name_end-class_end-1 < sizeof(NXname));
      strncpy(class,key,class_end-key);
      class[class_end-key] = '\0';
      strncpy(name,class_end+1,name_end-class_end-1);
      name[name_end-class_end-1] = '\0';


      /* Attempt to open next level. */
      status = NX_OK;
      if (!_group_exists(file->fid, name, class)) {
	status = NXmakegroup(file->fid, name, class);
      }
      if (status == NX_OK) status = NXopengroup(file->fid, name, class);
      if (status != NX_OK) {
	/* FIXME better error handling */
	printf("Could not open group %s:%s\n",class,name);
	_close_key(file);
	return 0;
      }
      key = name_end + 1;
      file->_depth++;
    }
  }

  if (attr != NULL) {
    /* We are writing an attribute. Data field needs to be open. */
    return _open_data(file,field);
  } else {
    /* We are writing a field. We can't open it without knowing its type */
    _close_data(file);
  }
    

  return 1;
}


/* Read a string field.
 * Sets the value to the empty string and returns false if there is an error.
 * Possible errors include:
 *    - field not a string
 *    - field too long for value
 * Assumes the field is already opened by _open_key.
 */
static int 
_read_data_str(Nexus *file, int len, char value[])
{
  int kind, rank;
  int dims[NX_MAXRANK];
  DEBUG("_read_data_str");

  if (NXgetinfo(file->fid, &rank, dims, &kind) != NX_OK) return 0;
  if (kind != NX_CHAR) return 0;
  if (rank != 1) return 0;
  if (dims[0] >= len) return 0;
  if (NXgetdata(file->fid, (void *)value) != NX_OK) return 0;
  value[dims[0]] = '\0';
  return 1;
}

/* Read a string attribute from a field.
 * Sets the value to the empty string and returns false if there is an error.
 * Possible errors include:
 *    - attribute doesn't exist
 *    - attribute is not a string
 *    - attribute is too long for value
 * Assumes the field is already opened by _open_key.
 */
static int 
_read_attr_str(Nexus *file, const char attr[], int len, char value[])
{
  int kind, slen = len;

  DEBUG("_read_attr_str");
  /* FIXME NXgetattr should accept "const char attr[]" */
  /* FIXME NXgetattr should accept "int kind" instead of "int *kind" */
  kind = NX_CHAR;
  if (NXgetattr(file->fid, (char *)attr, value, &slen, &kind) == NX_OK) {
    if (slen >= len) return 0;
    value[slen] = '\0';
  } else return 0;
  return 1;
}

/* Read a data field.
 * Possible errors include:
 *    - field is a string
 *    - field too long for value
 * Assumes the field is already opened by _open_key.
 */
static int 
_read_data_vector(Nexus *file, int len, double value[])
{
  int kind, rank, i, n=1;
  int dims[NX_MAXRANK];

  DEBUG("_read_data_vector...");
  if (NXgetinfo(file->fid, &rank, dims, &kind) != NX_OK) return 0;
  if (kind == NX_CHAR) return 0;
  for (i=0; i < rank; i++) n*=dims[i];
  if (n != len) return 0;
  if (NXgetdata(file->fid, (void *)value) != NX_OK) return 0;
  /* Expand the data in place. */
  _kind_to_double(value, n, kind);
  DEBUG("ok\n");
  return 1;
}


/* Write a data field.
 * Possible errors include:
 *    - field cannot be created
 *    - field cannot be written
 * Assumes the field is already opened by _create_key.
 */
static int 
_read_data_slab(Nexus *file, double value[],
		int size[], int start[])
{
  int i, n=1, status, rank, kind, dims[NX_MAXRANK];

  DEBUG("_read_data_slab");
  NXgetinfo(file->fid, &rank, dims, &kind);
  for (i=0; i < rank; i++) n*=size[i];
  /* FIXME allow const on size/start */
  status = (NXgetslab(file->fid, (void *)value, start, size) == NX_OK);
  _kind_to_double(value, n, kind); /* Convert back to double for caller. */

  return status;
}
/* Read a vector attribute from a field.
 * Sets the value to the empty string and returns false if there is an error.
 * Possible errors include:
 *    - attribute doesn't exist
 *    - attribute is not a string
 *    - attribute is too long for value
 * Assumes the field is already opened by _open_key.
 */
static int 
_read_attr_vector(Nexus *file, const char attr[], int len, double value[])
{
  int kind, slen = len;

  DEBUG("_read_attr_vector");
  /* FIXME NXgetattr should accept const attr */
  /* FIXME napi5 does not allow vector valued attributes */
  assert(len == 1);
  if (NXgetattr(file->fid, (char *)attr, value, &slen, &kind) == NX_OK) {
    if (slen != len || kind == NX_CHAR) return 0;
    _kind_to_double(value, slen, kind);
  } else return 0;
  return 1;
}


/* Write a string field.
 * Sets the value to the empty string and returns false if there is an error.
 * Possible errors include:
 *    - field not a string
 *    - field too long for value
 * Assumes the field is already opened by _open_key.
 */
static int 
_write_data_str(Nexus *file, const NXname field, const char value[])
{
  int dim = strlen(value);

  if (NXmakedata(file->fid, field, NX_CHAR, 1, &dim) != NX_OK) return 0;
  if (NXopendata(file->fid, field) != NX_OK) return 0;
  strcpy(file->_field, field); /* Already checked for length */
  if (NXputdata(file->fid, (void *)value) != NX_OK) return 0;
  return 1;
}

/* Write a string attribute to a field.
 * Possible errors include:
 *    - attribute already exists
 * Assumes the field is already opened by _open_key.
 */
static int 
_write_attr_str(Nexus *file, const char attr[], const char value[])
{
  /* Make sure the field is open. */
  if (file->_field[0] == '\0') return 0;

  /* FIXME allow const attr in NXputattr */
  return (NXputattr(file->fid, (char *)attr, (char *)value, 
		    strlen(value), NX_CHAR) == NX_OK);
}

/* Write a data field.
 * Possible errors include:
 *    - field cannot be created
 *    - field cannot be written
 * Assumes the field is already opened by _create_key.
 */
static int
_write_data_array(Nexus *file, const NXname field, double value[],
		  int rank, int dims[], int kind)
{
  int i, n=1, status;

  /* Create data */
  if (NXmakedata(file->fid, field, kind, rank, dims) != NX_OK) return 0;
  if (NXopendata(file->fid, field) != NX_OK) return 0;
  strcpy(file->_field, field); /* Already checked for length */

  /* If no data stop after creating. */
  if (value==NULL) return 1;

  /* Write data */
  for (i=0; i < rank; i++) n*=dims[i];
  _double_to_kind(value, n, kind); /* Convert to type for writing */
  status = (NXputdata(file->fid, (void *)value) == NX_OK);
  _kind_to_double(value, n, kind); /* Convert back to double for caller. */

  /* FIXME converting back to double costs a little more but it makes
   * the code easier to use; it may however result in a loss of precision
   * when writing.  Same applies to writeslab and writeattr.
   */

  return status;
}

/* Write a data field.
 * Possible errors include:
 *    - field cannot be created
 *    - field cannot be written
 * Assumes the field is already opened by _create_key.
 */
static int 
_write_data_slab(Nexus *file, double value[],
		 int size[], int start[])
{
  int i, n=1, status, rank, kind, dims[NX_MAXRANK];

  NXgetinfo(file->fid, &rank, dims, &kind);
  for (i=0; i < rank; i++) n*=size[i];
  _double_to_kind(value, n, kind); /* Convert to type for writing */
  /* FIXME allow const on size/start */
  status = (NXputslab(file->fid, (void *)value, start, size) == NX_OK);
  _kind_to_double(value, n, kind); /* Convert back to double for caller. */

  return status;
}

/* Write a vector attribute from a field.
 * Sets the value to the empty string and returns false if there is an error.
 * Possible errors include:
 *    - attribute doesn't exist
 *    - attribute is not a string
 *    - attribute is too long for value
 * Assumes the field is already opened by _open_key.
 */
static int 
_write_attr_vector(Nexus *file, const char attr[], 
		   double value[], int len, int kind)
{
  int status;

  /* Make sure the field is open. */
  if (file->_field[0] == '\0') return 0;

  assert(len == 1); /* napi5 doesn't yet handle vector attributes. */
  _double_to_kind(value, len, kind); /* Convert to type for writing */
  status = (NXputattr(file->fid, (char *)attr, value, len, kind) == NX_OK);
  _kind_to_double(value, len, kind);
  return status;
}


/* ============================================================== */

Nexus *
nexus_open(const char name[], const char modestr[])
{
  NXhandle fid;
  int mode, status, len, type;
  Nexus *file;
  
  /* Note: Don't create hdf5 since napi5 restricts attributes to
   * strings or scalars.
   */
  if (strcmp(modestr,"r")==0) mode=NXACC_READ;
  else if (strcmp(modestr,"rw")==0) mode=NXACC_RDWR;
  else if (strcmp(modestr,"w")==0) mode=NXACC_CREATE5;
  else return NULL;
  
  status = NXopen(name, mode, &fid);
  
  if (status != NX_OK) return NULL;
  file = (Nexus*)malloc(sizeof(Nexus));
  if (file == NULL) { NXclose(file->fid); return NULL; }
  file->fid = fid;
  file->entry[0] = '\0';
  file->_group[0] = '\0';
  file->_field[0] = '\0';
  file->_depth = 0;
  
  if (mode == NXACC_READ || mode == NXACC_RDWR) {
    /* Grab original file name */
    len = sizeof(file->name);
    type = NX_CHAR;
    file->name[0] = '\0';
    status = NXgetattr(file->fid, "file_name", file->name, &len, &type);
    if (status != NX_OK) file->name[0] = '\0';
    else file->name[len] = '\0';
    printf("file_name is %s\n",file->name);
  } else {
    len = sizeof(file->name);
    status = NXputattr(file->fid, "file_name", file->name, len, NX_CHAR);
    if (status != NX_OK) printf("could not write file_name attribute\n");
    assert(sizeof(file->name) > strlen(name));
    strcpy(file->name, name);
  }
  
  /* Maybe grab other fields... see header */
  return file;
}

void nexus_close(Nexus *file)
{
  if (file == NULL) return;
  NXclose(&file->fid);
  free(file);
}

void nexus_flush(Nexus *file)
{
  if (file == NULL) return;
  NXflush(&file->fid);
}

int nexus_openset(Nexus *file, const char name[])
{
  if (file == NULL) return 0;
  assert(1==0); /* Not implemented yet */
}

int nexus_nextset(Nexus *file)
{
  if (file == NULL) return 0;

  /* Return to NXentry level */
  DEBUG("nextset\n");
  _close_key(file);
  if (file->entry[0] != '\0') NXclosegroup(file->fid);
  file->entry[0] = '\0';

  /* Cycle to the next NXentry. */
  while (1) {
    NXname class, entry;
    char version[20];
    int kind;

    if (NXgetnextentry (file->fid, entry, class, &kind) != NX_OK) break;
    if (strcmp(class, "NXentry") != 0) continue;

    NXopengroup(file->fid, entry, "NXentry");
    strcpy(file->entry, entry); /* Safe length */
    if (nexus_readstr(file, "definition",
		      file->definition, sizeof(file->definition))
	&& nexus_readstr(file, "definition.version",
			 version, sizeof(version))) {
      sscanf(version,"%d.%d",&(file->major),&(file->minor));
      return 1;
    }
    NXclosegroup(file->fid);
    /* Skipping bad entries --- every NXentry should have a definition */
  }

  return 0;
}

int nexus_dims(Nexus *file, const char key[], NexusDim *dims)
{
  if (!_open_key(file, key)) return 0;

  return NXgetinfo(file->fid, &dims->rank, dims->size, &dims->kind) == NX_OK;
}
	       

int nexus_readstr(Nexus *file, const char key[], char data[], int n)
{
  const char *attrsep;

  /* Open the correct group. */
  if (!_open_key(file, key)) return 0;

  /* Read data or attribute */ 
  attrsep = strrchr(key, '.');
  if (attrsep != NULL) {
    return _read_attr_str(file, attrsep+1, n, data);
  } else {
    return _read_data_str(file, n, data);
  }
}


int nexus_read(Nexus *file, const char key[], double data[], int n)
{
  const char *attrsep;

  /* Open the correct group. */
  DEBUG(key); DEBUG(": opening key\n");
  if (!_open_key(file, key)) return 0;

  /* Read data or attribute */ 
  attrsep = strrchr(key, '.');
  if (attrsep != NULL) {
    return _read_attr_vector(file, attrsep+1, n, data);
  } else {
    return _read_data_vector(file, n, data);
  }
}

int nexus_readslab(Nexus *file, const char key[], double data[],
		   int start[], int size[])
{
  if (!_open_key(file, key)) return 0;
  return _read_data_slab(file, data, size, start);
}

int nexus_addset(Nexus *file, const NXname name,
		 const char definition[], int major, int minor,
		 const char URL[])
{
  int success = 1;
  _close_key(file);
  assert(strlen(definition) < sizeof(file->definition));
  assert(strlen(name) < sizeof(file->entry));
  if (NXmakegroup(file->fid, name, "NXentry") == NX_OK) {
    char version[20];
    NXopengroup(file->fid, name, "NXentry");
    strcpy(file->definition, definition);
    strcpy(file->entry, name);
    file->major = major;
    file->minor = minor;
    sprintf(version,"%d.%d",major,minor);
    if (nexus_writestr(file,"definition",definition)) success = 0;
    if (nexus_writestr(file,"definition.version",version)) success = 0;
    if (nexus_writestr(file,"definition.URL",URL)) success = 0;
  }
  return success;
}

int nexus_write(Nexus *file, const char key[], double data[],
		int rank, int size[], int kind)
{
  const char* attrsep;

  attrsep = strrchr(key, '.');
  if (attrsep != NULL) {
    if (rank != 1) return 0;
    if (!_open_key(file,key)) return 0;
    return _write_attr_vector(file, attrsep+1, data, size[0], kind);
  } else {
    NXname field;

    if (!_create_key(file,key,field)) return 0;
    return _write_data_array(file, field, data, rank, size, kind);
  }
  
}

/* Field must first be created by writing the with data==NULL. */
int nexus_writeslab(Nexus *file, const char key[], double data[],
		    int size[], int start[])
{
  if (!_open_key(file,key)) return 0;
  return _write_data_slab(file, data, size, start);
}

int nexus_writestr(Nexus *file, const char key[], const char value[])
{
  const char* attrsep;

  attrsep = strrchr(key, '.');
  if (attrsep != NULL) {
    if (!_open_key(file,key)) return 0;
    return _write_attr_str(file, attrsep+1, value);
  } else {
    NXname field;
    if (!_create_key(file,key,field)) return 0;
    return _write_data_str(file, field, value);
  }
}

int nexus_writevector(Nexus *file, const char key[], double data[], 
		      int n, int kind)
{
  return nexus_write(file,key,data,1,&n,kind);
}

int nexus_writescalar(Nexus *file, const char key[], double data, int kind)
{
  return nexus_writevector(file,key,&data,1,kind);
}


/* ================================================================== */
/* Read/write slits. */

/* Read slit info from the geometry.
 * Returns distance from sample, width of slit opening and height of
 * slit opening.  Width and height are stored relative to the surface
 * of the sample so will be swapped relative to normal for vertical
 * geometry reflectometers.
 * Units are assumed to be millimeters.
 */
int nexus_readslit(Nexus* file, const char key[],
		   double *distance, double *width, double *height)
{
  int success = 1;
  if (!_open_key(file, key)) return 0;
  

  if (NXopengroup(file->fid,"geometry","NXgeometry") == NX_OK) {
    if (NXopengroup(file->fid,"translation","NXtranslation") == NX_OK) {
      if (NXopendata(file->fid,"distances") == NX_OK) {
        double d[3];
        if (_read_data_vector(file, 3, d)) *distance = fabs(d[2]);
        else success = 0;
        NXclosedata(file->fid); /* geometry/translation/distances */
      }
      NXclosegroup(file->fid); /* geometry/translation */
    } else success = 0;
    if (NXopengroup(file->fid, "shape", "NXshape") == NX_OK) {
      char shape[20];
      shape[0] = '\0';
      if (NXopendata(file->fid, "shape") == NX_OK) {
        if (!_read_data_str(file, sizeof(shape), shape)) success = 0;
        NXclosedata(file->fid); /* geometry/shape/shape */
      } else success = 0;
      if (NXopendata(file->fid, "size") == NX_OK) {
        if (strcmp(shape, "nxsquare")) {
	  double size[2];
	  if (_read_data_vector(file, 2, size) == NX_OK) {
	    *width = size[0];
	    *height = size[1];
	  } else success = 0;
	} else if (strcmp(shape, "nxslit")) {
	  double size[1];
	  if (_read_data_vector(file, 1, size) == NX_OK) {
	    *width = size[0];
	    *height = -1.;
	  } else success = 0;
	} else success = 0;
	NXclosedata(file->fid); /* geometry/shape/size */
      } else success = 0;
      NXclosegroup(file->fid); /* geometry/shape */
    } else success = 0;
    NXclosegroup(file->fid); /* geometry */
  } else success = 0;


  return success;
}


int nexus_writeslit(Nexus *file, const char key[],
		    double distance, double width, double height)
{
  int dim;
  int rank;
  double data[5];
  NXname field;

  if (file == NULL) return 0;
  if (!_create_key(file, key, field)) return 0;

  /* FIXME no error handling? */
  NXmakegroup(file->fid,"geometry","NXgeometry");
  NXopengroup(file->fid,"geometry","NXgeometry");
  
  NXmakegroup(file->fid,"translation","NXtranslation");
  NXopengroup(file->fid,"translation","NXtranslation");
  
  rank = 1; dim = 3;
  data[0] = data[1] = 0.; data[2] = distance;
  _write_data_array(file,"distances", data, 1, &dim, NX_FLOAT32);
  _write_attr_str(file,"units","mm");
  _close_data(file);
  NXclosegroup(file->fid); /* geometry/translation */

  NXmakegroup(file->fid, "shape", "NXshape");
  NXopengroup(file->fid, "shape", "NXshape");

  data[0] = width;
  if (height > 0.) {
    int len = 2;
    data[1] = height;
    _write_data_str(file,"shape", "nxsquare");
    _close_data(file);
    _write_data_array(file,"size", data, 1, &len, NX_FLOAT32);
    _write_attr_str(file,"units","mm");
    _close_data(file);
  } else {
    int len = 1;
    _write_data_str(file,"shape", "nxslit");
    _close_data(file);
    _write_data_array(file,"size", data, 1, &len, NX_FLOAT32);
    _write_attr_str(file,"units","mm");
    _close_data(file);
  }
  NXclosegroup(file->fid); /* geometry/shape */
  NXclosegroup(file->fid); /* geometry */

  return 1;
}


