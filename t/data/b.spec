Name:		
Version:	20150102.gitad4f7b43
Release:	1%{?dist}
Summary:	

Group:		
License:	
URL:		
Source0:	

BuildRequires:	
Requires:	

%description


%prep
%setup -q


%build
%configure
make %{?_smp_mflags}


%install
%make_install


%files
%doc



%changelog

