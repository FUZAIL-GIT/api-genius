import 'dart:developer';
import 'dart:io';
import 'package:get/get.dart';
import 'package:node_server_maker/src/common/enums/enums.dart';
import 'package:node_server_maker/src/common/extensions/extension.dart';
import 'package:node_server_maker/src/pages/home_page/controller.dart';
import '../../../../pages/home_page/model.dart';
import '../data_service/data_service.dart';
import '../models/server_auth_model.dart';
import 'code_data/middleware_template.dart';
import 'code_data/server_template.dart';
import 'code_data/swagger_documentation.dart';

class CodeScaffoldingService extends GetxController {
  HomeController homeController = Get.find();
  late final Directory projectDir;
  late final String workingDirectory;
  late final Directory? downloadDirectoryPath;
  DataService dataService = DataService();

  Future<bool> runCommand({
    required String workingDirectory,
    required String command,
    bool runInShell = true,
  }) async {
    var result = await Process.run(command, [],
        runInShell: runInShell, workingDirectory: workingDirectory);
    if (result.exitCode != 0) {
      return false;
    } else {
      return true;
    }
  }

  //create a porject
  Future<void> createProject({
    required String projectName,
    required List<Collection> collections,
    required List<Field> attributes,
    required String mongoDbUrl,
    required bool isTimestamp,
    required bool isPagination,
    required bool isOpenInVsCode,
    required bool isInstallPackages,
    required ServerAuthentication serverAuthentication,
  }) async {
    try {
      downloadDirectoryPath = await dataService.downloadDirectory();
      projectDir = Directory("${downloadDirectoryPath!.path}/$projectName/app");

      if (!projectDir.existsSync()) {
        homeController.updateCurrentStatus(Status.LOADING);
        await projectSetup(
            projectName: projectName,
            isAutomaticallyInstallPackages: isInstallPackages);
        await createFolderStructure(
          attributes: attributes,
          collections: collections,
          mongoDbUrl: mongoDbUrl,
          projectName: projectName,
          serverAuthentication: serverAuthentication,
          isTimestamp: isTimestamp,
          isPagination: isPagination,
          isOpenInVsCode: isOpenInVsCode,
        );
        log("folder Structure created");
      } else {
        log("folder with this name already exist");
      }
    } catch (e) {
      log('', error: e);
    }
  }

  Future<void> projectSetup(
      {required String projectName,
      required bool isAutomaticallyInstallPackages}) async {
    // project root directory path
    workingDirectory = '${downloadDirectoryPath!.path}\\$projectName';

    //create project dir
    projectDir.createSync(recursive: true);

    //intialize as a node project
    await runCommand(workingDirectory: workingDirectory, command: 'npm init -y')
        .then((value) {
      if (value) {
        log('npm initialized');
        homeController.updateCurrentStatus(Status.INITIALIZED);
      } else {}
    }); //installing packages
    if (isAutomaticallyInstallPackages) {
      await runCommand(
              workingDirectory: workingDirectory,
              command:
                  'npm install express mongoose body-parser swagger-ui-express yamljs --save')
          .then((value) {
        if (value) {
          log('npm packages installed');
          homeController.updateCurrentStatus(Status.INSTALLED);
        } else {}
      });
    }
  }

  Future<void> createFolderStructure({
    required String projectName,
    required String mongoDbUrl,
    required List<Collection> collections,
    required List<Field> attributes,
    required bool isTimestamp,
    required bool isPagination,
    required bool isOpenInVsCode,
    required ServerAuthentication serverAuthentication,
  }) async {
    // Create sub-folders within myFolder
    Directory controllerFolder = Directory('${projectDir.path}\\controller');
    Directory middlewareFolder = Directory('${projectDir.path}\\middleware');
    Directory modelFolder = Directory('${projectDir.path}\\model');
    Directory routesFolder = Directory('${projectDir.path}\\routes');
    Directory configFolder = Directory('${projectDir.path}\\config');

    // Create the sub-folders
    await controllerFolder.create(recursive: true);
    if (serverAuthentication.authenticationLevel != AuthenticationLevel.NONE) {
      await middlewareFolder.create(recursive: true);
    }
    await modelFolder.create(recursive: true);
    await routesFolder.create(recursive: true);
    await configFolder.create(recursive: true);

    for (var collection in collections) {
      // ############################################################################
      // model file
      File modelFile = File(
          "${modelFolder.path}/${collection.collectionName.uncapitalize()}_model.js");
      modelFile
          .writeAsStringSync(dataService.modelData(collection, attributes));

      // ############################################################################
      // controller file
      File controllerFile = File(
          "${controllerFolder.path}\\${collection.collectionName.uncapitalize()}_controller.js");
      controllerFile.writeAsStringSync(
          dataService.controllerData(collection, attributes));
    }

    // ############################################################################
    //*route file
    File routeFile = File('${projectDir.path}\\routes\\app_routes.js');
    routeFile
        .writeAsStringSync(dataService.routesData(collections, attributes));

    // ############################################################################
    // *server file
    File serverFile =
        File('${downloadDirectoryPath!.path}/$projectName/index.js');
    String server = serverTemplate(serverAuthentication: serverAuthentication);
    serverFile.writeAsStringSync(server);

    // ############################################################################
    // *swagger documentation file
    File documentatiionFile =
        File('${downloadDirectoryPath!.path}/$projectName/documentation.yaml');
    String document = swaggerDocumentation(
      collection: collections,
      attributes: attributes,
      projectName: projectName,
      serverAuthentication: serverAuthentication,
    );
    documentatiionFile.writeAsStringSync(document);

    // ############################################################################
    // *middleware file
    File middlewareFile = File('${projectDir.path}\\middleware\\middleware.js');
    String middleware =
        middlewareTemplate(serverAuthentication: serverAuthentication);
    if (serverAuthentication.authenticationLevel != AuthenticationLevel.NONE) {
      middlewareFile.writeAsStringSync(middleware);
    }
    // ############################################################################
    // * config file
    File configFile = File('${projectDir.path}\\config\\config.js');
    configFile.writeAsStringSync(
        dataService.mongoDbConfig(mongoDbUrl, serverAuthentication));
    homeController.updateCurrentStatus(Status.COMPLETED);
    if (isOpenInVsCode) {
      runCommand(workingDirectory: workingDirectory, command: 'code .')
          .then((value) {
        if (value) {
          log('Project Created Successfully');
        } else {}
      });
    }
  }
}