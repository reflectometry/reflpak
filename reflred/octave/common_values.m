## [Q,idxA,idxB] = common_values(A,B [,tol])
## Returns a list of values, Q, in common between A and B within
## tolerance, and the A and B indices they correspond to.  Note
## that this may not work correctly if any two A or B values are
## within 2*tol of each other. Tolerance defaults to 0.  The values
## are returned are the average of A and B at each point.
function [q,idxA,idxB] = common_values(a,b,tol)
  if nargin < 3, tol = 0; end

  ## Check if we have a complete set
  if length(a) == length(b)
    if all ( abs(a(:)-b(:)) <= tol )
      q = a;
      idxA = idxB = 1:length(a);
      return
    end
  end

  ## Sort a and b together into v, remembering which came from a and
  ## which from b.
  [v,idx] = sort([a(:);b(:)]);

  ## Locate all pairs within tol of each other.  This might break if
  ## any two a or b are within 2*tol of each other.
  c = find(diff(v)<=tol);

  ## Find the indices of each half of the pair.  The low index will
  ## be from a and the high index from b.
  idxA = min(idx(c),idx(c+1));
  idxB = max(idx(c),idx(c+1))-length(a(:));

  ## Average the a and b returned values.
  q = (a(idxA)+b(idxB))/2;
end
%!test
%! [q,iA,iB] = common_values([1,2,3,4,5],[1,3,4,6]);
%! assert(q,[1,3,4])
%! assert(iA,[1;3;4])
%! assert(iB,[1;2;3])
%!test
%! [q,iA,iB] = common_values([1,2,3,4,5],[1,3,4.01,6]);
%! assert(q,[1,3])
%! assert(iA,[1;3])
%! assert(iB,[1;2])
%!test
%! [q,iA,iB] = common_values([1,2,3,4,5],[1,3,4.01,6],0.1);
%! assert(q,[1,3,4.005],eps)
%! assert(iA,[1;3;4])
%! assert(iB,[1;2;3])
