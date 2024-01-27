on configure => sub {
    requires 'Module::Install';
    requires 'Module::Install::TestTarget';
    requires 'Module::Install::ReadmeFromPod';
};
on test => sub {
    requires 'Test::More' => '0.96';
};
