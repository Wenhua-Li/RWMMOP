function Y = rwmmo_network_objectives(X,MCS)
% Exact source-compatible objective; all triples, no topology truncation.
% Legacy counts unreachable ordered pairs / 2 INCLUDING isolated diagonals.
N=MCS.N;
assert(size(X,2)==N*N && all(isfinite(X(:))),'RWMMO:InvalidDecision','Invalid graph decisions.');
Y=zeros(size(X,1),2);
for p=1:size(X,1)
    A=reshape(X(p,:)~=0,N,N);
    assert(isequal(A,A') && ~any(diag(A)),'RWMMO:GraphEncoding','Expected simple undirected graph.');
    if any(sum(A,2)==0), Y(p,:)=[Inf Inf]; continue; end
    Y(p,1)=sum(sum(A.*MCS.DIST));
    [r,c]=find(triu(A,1)); E=numel(r);
    if E<3,continue;end
    triples=nchoosek(1:E,3);
    total=0;
    for first=1:256:size(triples,1)
        q=triples(first:min(first+255,end),:); B=size(q,1);
        R=repmat(A,1,1,B);
        pages=repmat((1:B)',1,3);
        rr=reshape(r(q),size(q)); cc=reshape(c(q),size(q));
        R(sub2ind([N N B],rr,cc,pages))=false;
        R(sub2ind([N N B],cc,rr,pages))=false;
        % Boolean transitive closure is equivalent to positive matrix powers
        % 1..N for undirected graphs, without floating-point overflow.
        for k=1:N, R=R | (R(:,k,:) & R(k,:,:)); end
        total=total+sum(~R(:))/2;
    end
    Y(p,2)=total;
end
end
