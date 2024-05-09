import 'dart:convert';
import 'dart:ffi';
import 'dart:io';
import 'package:flutter/material.dart';

void main() {
  runApp(MyApp());
}

class MyApp extends StatefulWidget {
  @override
  _MyAppState createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  Widget build(BuildContext context) {
    return MaterialApp(
        title: 'O3_backend',
        theme: ThemeData(
            colorScheme: ColorScheme.fromSeed(
              seedColor: GlobalData.themeColor,
              brightness:
                  GlobalData.darkMode ? Brightness.dark : Brightness.light,
            ),
            scrollbarTheme: ScrollbarThemeData(
                thumbVisibility: MaterialStateProperty.all(true),
                thickness: MaterialStateProperty.all(10),
                thumbColor: MaterialStateProperty.all(Colors.blue),
                radius: const Radius.circular(10),
                minThumbLength: 100)),
        home: PythonProjectsPage());
  }
}

class GlobalData {
  static bool darkMode = false;
  static Color themeColor = Colors.blue;
  static List<PythonProject> projects = [
    PythonProject(
        name: 'Digital_Human',
        conda: "conda activate digitalhuman",
        pythonPath: 'python',
        projectPath: 'D:/O3BackEND_new/O3_DigitalHuman/run.py',
        cwdPath: 'D:/O3BackEND_new/O3_DigitalHuman'),
    PythonProject(
        name: 'voice_train',
        conda: "D:/O3BackEND_new/O3GPT-SoVITS/train_start.bat",
        pythonPath: 'python',
        projectPath: 'D:/O3BackEND_new/O3GPT-SoVITS/train_cli.py',
        cwdPath: 'D:/O3BackEND_new/O3GPT-SoVITS'),
    PythonProject(
        name: 'voice_inference',
        conda: "D:/O3BackEND_new/O3GPT-SoVITS/inference_start.bat",
        pythonPath: 'python',
        projectPath: 'D:/O3BackEND_new/O3GPT-SoVITS/inference_cli.py',
        cwdPath: 'D:/O3BackEND_new/O3GPT-SoVITS'),
    PythonProject(
        name: 'subtitle',
        conda: "conda activate subtitle",
        pythonPath: 'python',
        projectPath: 'D:/O3BackEND_new/O3_Subtitle/run.py',
        cwdPath: 'D:/O3BackEND_new/O3_Subtitle'),
  ];
}

class PythonProject {
  String name;
  String conda;
  String projectPath;
  String pythonPath;
  String cwdPath;
  //Process? process;
  List<String> output = [];
  Map<String, Process>? process;

  PythonProject(
      {required this.pythonPath,
      required this.projectPath,
      required this.cwdPath,
      required this.conda,
      required this.name}) {
    process = {}; // 在构造函数中初始化
  }
}

class PythonProjectsPage extends StatefulWidget {
  @override
  _PythonProjectsPageState createState() => _PythonProjectsPageState();
}

class _PythonProjectsPageState extends State<PythonProjectsPage> {
  final projects = GlobalData.projects;
  final ScrollController _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _scrollToBottom());
  }

  void _scrollToBottom() {
    if (_scrollController.hasClients) {
      _scrollController.animateTo(
        _scrollController.position.maxScrollExtent,
        duration: Duration(milliseconds: 500),
        curve: Curves.easeOut,
      );
    }
  }

  int _currentProjectIndex = 0;

  // __future__.
  Future<void> killShellCommand(int pid) async {
    try {
      var result = await Process.run('kill', [pid.toString()]);
      print(result.stdout);

      if (result.stderr.isNotEmpty) {
        print('命令执行错误: ${result.stderr}');
      }
    } catch (e) {
      print('命令执行异常: $e');
    }
  }

  Future<void> _startProcess(PythonProject project) async {
    // 设置无缓冲的环境变量
    Map<String, String> env = {'PYTHONUNBUFFERED': '1'};

    try {
      final processInstance = await Process.start(project.conda, [],
          runInShell: false,
          environment: env,
          workingDirectory: project.cwdPath);
      //project.process?[project.name] = processInstance;
      project.process?[project.name] = processInstance;
      print("启动了进程：$processInstance");
      print("记录进程为：${project.name}, ${project.process?[project.name]}");

      processInstance.stdout
          .transform(utf8.decoder)
          .transform(LineSplitter())
          .listen((data) {
        setState(() {
          project.output.add(data);
          _scrollToBottom();
        });
      });
      processInstance.stderr
          .transform(utf8.decoder)
          .transform(LineSplitter())
          .listen((data) {
        setState(() {
          project.output.add(data);
          _scrollToBottom();
        });
      });
    } catch (e) {
      setState(() {
        project.output.add('Failed to start process: $e');
      });
    }
  }

  void _stopProcess(PythonProject project) {
    var haltingProcess = project.process?[project.name];
    var processName = project.name;

    //executeShellCommand(pid);
    bool killed = haltingProcess!.kill(ProcessSignal.sigkill);
    if (killed) {
      print("成功杀死进程：$processName");
    } else {
      print("杀死进程失败：$processName");
    }

    setState(() {
      project.process?.remove(project.name);
      project.output.add('Process stopped.');
    });
  }

  void _restartProcess(PythonProject project) {
    _stopProcess(project);
    // Using a delay to ensure the process has enough time to fully terminate before restarting
    Future.delayed(Duration(seconds: 1), () => _startProcess(project));
  }

  void _clearProcessInfo(PythonProject project) {
    setState(() {
      project.output.clear();
    });
  }

  Widget _buildProjectOutput(PythonProject project) {
    return Scrollbar(
        interactive: true,
        trackVisibility: true,
        thickness: 10,
        thumbVisibility: true,
        controller: _scrollController, // 使用同一个滚动控制器,
        child: ListView.builder(
          controller: _scrollController,
          itemCount: project.output.length,
          itemBuilder: (_, index) => SelectableText(project.output[index],
              style: TextStyle(fontSize: 16, color: Colors.white)),
        ));
  }

  @override
  Widget build(BuildContext context) {
    final currentProject = projects[_currentProjectIndex];
    final Map<String, IconData> iconMap = {
      "Digital_Human": Icons.person,
      "voice_train": Icons.keyboard_voice,
      "voice_inference": Icons.record_voice_over,
      "subtitle": Icons.subtitles
    };

    return Scaffold(
      appBar: AppBar(
        title: Text(currentProject.name),
        actions: <Widget>[
          IconButton(
            icon: Icon(Icons.play_arrow),
            tooltip: 'Start',
            onPressed: () => _startProcess(currentProject),
          ),
          SizedBox(
            width: 8,
          ),
          IconButton(
            icon: Icon(Icons.stop_rounded),
            tooltip: 'Stop',
            onPressed: () => _stopProcess(currentProject),
          ),
          SizedBox(
            width: 8,
          ),
          IconButton(
            icon: Icon(Icons.replay),
            tooltip: 'Restart',
            onPressed: () => _restartProcess(currentProject),
          ),
          SizedBox(
            width: 8,
          ),
          IconButton(
            icon: Icon(Icons.playlist_remove_rounded),
            tooltip: 'Clear',
            onPressed: () => _clearProcessInfo(currentProject),
          ),
          SizedBox(
            width: 8,
          ),
          Padding(padding: EdgeInsets.all(20))
        ],
      ),
      body: Row(
        children: [
          NavigationRail(
            selectedIndex: _currentProjectIndex,
            onDestinationSelected: (index) {
              setState(() {
                _currentProjectIndex = index;
              });
              WidgetsBinding.instance.addPostFrameCallback((_) {
                _scrollToBottom();
              });
            },
            labelType: NavigationRailLabelType.selected,
            destinations: projects.map((project) {
              IconData iconData = iconMap[project.name] ?? Icons.code;
              return NavigationRailDestination(
                icon: Padding(
                  padding: EdgeInsets.symmetric(vertical: 5),
                  child: Icon(iconData),
                ),
                selectedIcon: Icon(iconData),
                label: Padding(
                  padding: EdgeInsets.symmetric(vertical: 5),
                  child: Text(project.name),
                ),
              );
            }).toList(),
            trailing: IconButton(
              icon: Icon(Icons.settings),
              onPressed: () {
                // 点击设置图标时跳转到设置页面
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => SettingsPage()),
                );
              },
            ),
          ),
          Expanded(
            child: Column(
              children: [
                Expanded(
                  child: Padding(
                      padding: EdgeInsets.symmetric(
                          horizontal: 15.0, vertical: 10.0),
                      child: Container(
                        color: Colors.black,
                        child: _buildProjectOutput(currentProject),
                      )),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }
}

class SettingsPage extends StatefulWidget {
  @override
  _SettingsPageState createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  Color _themeColor = Colors.blue;

  void _addProject(
      String name, String pythonPath, String projectPath, String cwdPath) {
    // 使用 setState 来确保列表更新
    setState(() {
      GlobalData.projects.add(
        PythonProject(
          name: name,
          conda: "nan",
          pythonPath: pythonPath,
          projectPath: projectPath,
          cwdPath: cwdPath,
        ),
      );
    });
  }

  void _showAddProjectDialog() {
    // 表单键
    final _formKey = GlobalKey<FormState>();
    // 文本编辑控制器
    final nameController = TextEditingController();
    final pythonPathController = TextEditingController();
    final projectPathController = TextEditingController();
    final cwdPathController = TextEditingController();

    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text('添加项目'),
          content: Form(
            key: _formKey,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                  TextFormField(
                    controller: nameController,
                    decoration: InputDecoration(labelText: '项目名称'),
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return '请输入项目名称';
                      }
                      return null;
                    },
                  ),
                  TextFormField(
                    controller: pythonPathController,
                    decoration: InputDecoration(labelText: 'Python 路径'),
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return '请输入 Python 路径';
                      }
                      return null;
                    },
                  ),
                  TextFormField(
                    controller: projectPathController,
                    decoration: InputDecoration(labelText: '项目路径'),
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return '请输入项目路径';
                      }
                      return null;
                    },
                  ),
                  TextFormField(
                    controller: cwdPathController,
                    decoration: InputDecoration(labelText: '工作目录路径'),
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return '请输入工作目录路径';
                      }
                      return null;
                    },
                  ),
                ],
              ),
            ),
          ),
          actions: <Widget>[
            TextButton(
              child: Text('取消'),
              onPressed: () {
                Navigator.of(context).pop(); // 关闭对话框
              },
            ),
            TextButton(
              child: Text('添加'),
              onPressed: () {
                // 验证表单
                if (_formKey.currentState!.validate()) {
                  _addProject(
                    nameController.text,
                    pythonPathController.text.replaceAll('\\', "/"),
                    projectPathController.text.replaceAll('\\', "/"),
                    cwdPathController.text.replaceAll('\\', "/"),
                  );
                  Navigator.of(context).pop(); // 关闭对话框
                  (context.findAncestorStateOfType<_MyAppState>()
                          as _MyAppState)
                      .setState(() {});
                }
              },
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text("设置"),
      ),
      body: ListView(
        children: <Widget>[
          SwitchListTile(
            title: Text("黑夜模式"),
            value: GlobalData.darkMode,
            onChanged: (bool value) {
              setState(() {
                GlobalData.darkMode = value;
                (context.findAncestorStateOfType<_MyAppState>() as _MyAppState)
                    .setState(() {});
              });
            },
          ),
          ListTile(
            title: Text("选择主题颜色 Developing"),
            trailing: Icon(Icons.color_lens, color: _themeColor),
            onTap: () {
              // 这里可以打开颜色选择器，允许用户选择新的主题色
            },
          ),
          ListTile(
            title: Text("添加项目(临时)"),
            trailing: Icon(Icons.add),
            onTap: () {
              _showAddProjectDialog();
            },
          ),
        ],
      ),
    );
  }
}
