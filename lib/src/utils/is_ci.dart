import 'package:sip_cli/src/deps/platform.dart';

bool isCi() {
  if (platform.environment['BOT'] == 'true') return true;
  // https://docs.travis-ci.com/user/environment-variables/#Default-Environment-Variables
  if (platform.environment['TRAVIS'] == 'true') return true;
  if (platform.environment['CONTINUOUS_INTEGRATION'] == 'true') return true;

  // (Travis and AppVeyor)
  if (platform.environment.containsKey('CI')) return true;

  // https://www.appveyor.com/docs/environment-variables/
  if (platform.environment.containsKey('APPVEYOR')) return true;

  // https://cirrus-ci.org/guide/writing-tasks/#environment-variables
  if (platform.environment.containsKey('CIRRUS_CI')) return true;

  // https://docs.aws.amazon.com/codebuild/latest/userguide/build-env-ref-env-vars.html
  if (platform.environment.containsKey('AWS_REGION') &&
      platform.environment.containsKey('CODEBUILD_INITIATOR')) {
    return true;
  }

  // https://wiki.jenkins.io/display/JENKINS/Building+a+software+project#Buildingasoftwareproject-belowJenkinsSetEnvironmentVariables
  if (platform.environment.containsKey('JENKINS_URL')) return true;

  // https://help.github.com/en/actions/configuring-and-managing-workflows/using-environment-variables#default-environment-variables
  if (platform.environment.containsKey('GITHUB_ACTIONS')) return true;

  // https://learn.microsoft.com/en-us/azure/devops/pipelines/build/variables?view=azure-devops&tabs=yaml
  if (platform.environment.containsKey('TF_BUILD')) return true;

  return false;
}
