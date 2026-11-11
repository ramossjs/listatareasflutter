import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';

import 'firebase_options.dart';

const _ink = Color(0xFF20233A);
const _accent = Color(0xFFE86A5B);
const _mint = Color(0xFFD8F0E7);
const _background = Color(0xFFF7F4EE);

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  runApp(const TaskListApp());
}

class TaskListApp extends StatefulWidget {
  const TaskListApp({super.key});

  @override
  State<TaskListApp> createState() => _TaskListAppState();
}

class _TaskListAppState extends State<TaskListApp> {
  final _auth = FirebaseAuth.instance;
  final _firestore = FirebaseFirestore.instance;
  User? _currentUser;
  List<Task> _tasks = [];
  bool _loading = true;
  String? _loadError;

  @override
  void initState() {
    super.initState();
    _auth.authStateChanges().listen((user) async {
      if (!mounted) return;
      setState(() {
        _currentUser = user;
        _loading = true;
        _loadError = null;
      });
      try {
        _tasks = user == null ? [] : await _loadTasks(user.uid);
      } on FirebaseException catch (error) {
        _tasks = [];
        _loadError = _firestoreError(error);
      }
      if (mounted) setState(() => _loading = false);
    });
  }

  Future<String?> _signIn(String email, String password) async {
    try {
      await _auth.signInWithEmailAndPassword(
        email: email.trim(),
        password: password,
      );
      return null;
    } on FirebaseAuthException catch (error) {
      return _authError(error);
    }
  }

  Future<String?> _register(String email, String password) async {
    try {
      await _auth.createUserWithEmailAndPassword(
        email: email.trim(),
        password: password,
      );
      return null;
    } on FirebaseAuthException catch (error) {
      return _authError(error);
    }
  }

  Future<List<Task>> _loadTasks(String userId) async {
    final snapshot = await _firestore
        .collection('users')
        .doc(userId)
        .collection('tasks')
        .orderBy('createdAt')
        .get();
    return snapshot.docs.map(Task.fromDocument).toList();
  }

  Future<void> _addTask(String title) async {
    final user = _currentUser;
    if (user == null) return;
    final reference = await _firestore
        .collection('users')
        .doc(user.uid)
        .collection('tasks')
        .add({
          'title': title,
          'completed': false,
          'createdAt': FieldValue.serverTimestamp(),
        });
    if (mounted) {
      setState(() => _tasks.add(Task(title, id: reference.id)));
    }
  }

  Future<void> _toggleTask(Task task) async {
    final user = _currentUser;
    if (user == null || task.id == null) return;
    await _firestore
        .collection('users')
        .doc(user.uid)
        .collection('tasks')
        .doc(task.id)
        .update({'completed': !task.completed});
    if (mounted) setState(() => task.completed = !task.completed);
  }

  Future<void> _deleteTask(Task task) async {
    final user = _currentUser;
    if (user == null || task.id == null) return;
    await _firestore
        .collection('users')
        .doc(user.uid)
        .collection('tasks')
        .doc(task.id)
        .delete();
    if (mounted) setState(() => _tasks.remove(task));
  }

  Future<void> _signOut() => _auth.signOut();

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Lista de tareas',
      theme: ThemeData(
        useMaterial3: true,
        scaffoldBackgroundColor: _background,
        colorScheme: ColorScheme.fromSeed(
          seedColor: _accent,
          brightness: Brightness.light,
        ),
        fontFamily: 'Avenir',
        inputDecorationTheme: InputDecorationTheme(
          filled: true,
          fillColor: Colors.white,
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 18,
            vertical: 17,
          ),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: BorderSide.none,
          ),
          enabledBorder: const OutlineInputBorder(
            borderSide: BorderSide(color: Color(0xFFE4DED4)),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: const BorderSide(color: _accent, width: 2),
          ),
        ),
      ),
      home: _loading
          ? const Scaffold(body: Center(child: CircularProgressIndicator()))
          : _currentUser == null
          ? LoginPage(onSignIn: _signIn, onRegister: _register)
          : TasksPage(
              email: _currentUser!.email ?? '',
              tasks: _tasks,
              onSignOut: _signOut,
              onAdd: _addTask,
              onToggle: _toggleTask,
              onDelete: _deleteTask,
              errorMessage: _loadError,
            ),
    );
  }
}

class Task {
  Task(this.title, {this.id, this.completed = false});

  factory Task.fromDocument(
    QueryDocumentSnapshot<Map<String, dynamic>> document,
  ) {
    final data = document.data();
    return Task(
      data['title'] as String? ?? '',
      id: document.id,
      completed: data['completed'] as bool? ?? false,
    );
  }

  final String? id;
  final String title;
  bool completed;
}

String _authError(FirebaseAuthException error) {
  switch (error.code) {
    case 'invalid-credential':
    case 'user-not-found':
    case 'wrong-password':
      return 'El correo o la contraseña no son correctos.';
    case 'email-already-in-use':
      return 'Ya existe una cuenta con ese correo.';
    case 'invalid-email':
      return 'El correo electrónico no es válido.';
    case 'weak-password':
      return 'La contraseña es demasiado débil.';
    default:
      return 'No se pudo completar la operación. Inténtalo de nuevo.';
  }
}

String _firestoreError(FirebaseException error) {
  switch (error.code) {
    case 'permission-denied':
      return 'Firestore rechazó el acceso. Publica las reglas de seguridad indicadas en Firebase Console.';
    case 'failed-precondition':
      return 'Firestore necesita una configuración adicional. Revisa que la base de datos esté creada.';
    case 'unavailable':
      return 'Firestore no está disponible. Comprueba tu conexión a internet.';
    default:
      return 'No se pudieron cargar las tareas (${error.code}).';
  }
}

class LoginPage extends StatefulWidget {
  const LoginPage({
    super.key,
    required this.onSignIn,
    required this.onRegister,
  });

  final Future<String?> Function(String email, String password) onSignIn;
  final Future<String?> Function(String email, String password) onRegister;

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final _email = TextEditingController();
  final _password = TextEditingController();
  final _formKey = GlobalKey<FormState>();

  @override
  void dispose() {
    _email.dispose();
    _password.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_formKey.currentState!.validate()) {
      final error = await widget.onSignIn(_email.text, _password.text);
      if (error != null && mounted) {
        ScaffoldMessenger.of(context)
          ..hideCurrentSnackBar()
          ..showSnackBar(SnackBar(content: Text(error)));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return AuthScaffold(
      child: Form(
        key: _formKey,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _authBadge(Icons.checklist_rounded),
            const SizedBox(height: 24),
            const Text(
              'Bienvenido',
              style: TextStyle(
                fontSize: 30,
                fontWeight: FontWeight.w800,
                color: _ink,
              ),
            ),
            const SizedBox(height: 10),
            const Text(
              'Inicia sesión o crea una cuenta.',
              style: TextStyle(fontSize: 16, color: Color(0xFF6D6A75)),
            ),
            const SizedBox(height: 26),
            _emailField(_email),
            const SizedBox(height: 16),
            _passwordField(_password),
            const SizedBox(height: 24),
            FilledButton(
              onPressed: _submit,
              style: _primaryButtonStyle(),
              child: const Text('Iniciar sesión'),
            ),
            const SizedBox(height: 9),
            OutlinedButton(
              onPressed: () => Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => RegisterPage(onRegister: widget.onRegister),
                ),
              ),
              style: _secondaryButtonStyle(),
              child: const Text('Crear cuenta'),
            ),
          ],
        ),
      ),
    );
  }
}

class RegisterPage extends StatefulWidget {
  const RegisterPage({super.key, required this.onRegister});

  final Future<String?> Function(String email, String password) onRegister;

  @override
  State<RegisterPage> createState() => _RegisterPageState();
}

class _RegisterPageState extends State<RegisterPage> {
  final _email = TextEditingController();
  final _password = TextEditingController();
  final _confirmation = TextEditingController();
  final _formKey = GlobalKey<FormState>();

  @override
  void dispose() {
    _email.dispose();
    _password.dispose();
    _confirmation.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_formKey.currentState!.validate()) {
      final error = await widget.onRegister(_email.text, _password.text);
      if (error != null && mounted) {
        ScaffoldMessenger.of(context)
          ..hideCurrentSnackBar()
          ..showSnackBar(SnackBar(content: Text(error)));
      } else if (mounted) {
        Navigator.of(context).pop();
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return AuthScaffold(
      child: Form(
        key: _formKey,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _authBadge(Icons.auto_awesome),
            const SizedBox(height: 22),
            const Text(
              'Crear cuenta',
              style: TextStyle(
                fontSize: 30,
                fontWeight: FontWeight.w800,
                color: _ink,
              ),
            ),
            const SizedBox(height: 10),
            const Text(
              'Regístrate para administrar tus tareas.',
              style: TextStyle(fontSize: 16, color: Color(0xFF6D6A75)),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 26),
            _emailField(_email),
            const SizedBox(height: 16),
            _passwordField(_password),
            const SizedBox(height: 16),
            TextFormField(
              controller: _confirmation,
              obscureText: true,
              decoration: const InputDecoration(
                prefixIcon: Icon(Icons.lock_outline),
                hintText: 'Confirmar contraseña',
              ),
              validator: (value) => value != _password.text
                  ? 'Las contraseñas no coinciden'
                  : null,
            ),
            const SizedBox(height: 24),
            FilledButton(
              onPressed: _submit,
              style: _primaryButtonStyle(),
              child: const Text('Crear cuenta'),
            ),
            const SizedBox(height: 9),
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Volver a iniciar sesión'),
            ),
          ],
        ),
      ),
    );
  }
}

class AuthScaffold extends StatelessWidget {
  const AuthScaffold({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Stack(
          children: [
            Positioned(
              top: 0,
              right: 0,
              child: Container(
                width: 150,
                height: 150,
                decoration: const BoxDecoration(
                  color: _mint,
                  borderRadius: BorderRadius.only(
                    bottomLeft: Radius.circular(150),
                  ),
                ),
              ),
            ),
            Center(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(24),
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 420),
                  child: child,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

Widget _authBadge(IconData icon) {
  return Container(
    width: 78,
    height: 78,
    decoration: BoxDecoration(
      color: _ink,
      borderRadius: BorderRadius.circular(24),
      boxShadow: const [
        BoxShadow(
          color: Color(0x22302E43),
          blurRadius: 0,
          offset: Offset(5, 5),
        ),
      ],
    ),
    child: Icon(icon, color: _mint, size: 38),
  );
}

class TasksPage extends StatefulWidget {
  const TasksPage({
    super.key,
    required this.email,
    required this.tasks,
    required this.onSignOut,
    required this.onAdd,
    required this.onToggle,
    required this.onDelete,
    this.errorMessage,
  });

  final String email;
  final List<Task> tasks;
  final VoidCallback onSignOut;
  final Future<void> Function(String title) onAdd;
  final Future<void> Function(Task task) onToggle;
  final Future<void> Function(Task task) onDelete;
  final String? errorMessage;

  @override
  State<TasksPage> createState() => _TasksPageState();
}

class _TasksPageState extends State<TasksPage> {
  final _newTask = TextEditingController();

  @override
  void dispose() {
    _newTask.dispose();
    super.dispose();
  }

  Future<void> _addTask() async {
    final title = _newTask.text.trim();
    if (title.isEmpty) return;
    await widget.onAdd(title);
    if (!mounted) return;
    _newTask.clear();
    FocusScope.of(context).unfocus();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(24, 22, 24, 40),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 584),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    children: [
                      const Expanded(
                        child: Text(
                          'MI ESPACIO',
                          style: TextStyle(
                            color: _accent,
                            fontSize: 13,
                            fontWeight: FontWeight.w800,
                            letterSpacing: 2,
                          ),
                        ),
                      ),
                      IconButton(
                        onPressed: widget.onSignOut,
                        tooltip: 'Cerrar sesión',
                        icon: const Icon(Icons.arrow_outward_rounded),
                      ),
                    ],
                  ),
                  const SizedBox(height: 18),
                  Text(
                    'Hola, ${widget.email.split('@').first}',
                    style: const TextStyle(
                      color: _ink,
                      fontSize: 28,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 6),
                  const Text(
                    '¿Qué quieres organizar hoy?',
                    style: TextStyle(color: Color(0xFF77737A), fontSize: 16),
                  ),
                  const SizedBox(height: 26),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: TextField(
                          controller: _newTask,
                          textInputAction: TextInputAction.done,
                          onSubmitted: (_) => _addTask(),
                          decoration: InputDecoration(
                            hintText: 'Escribe una nueva tarea',
                            prefixIcon: const Icon(Icons.edit_note_rounded),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(14),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      SizedBox(
                        height: 56,
                        child: FilledButton(
                          onPressed: _addTask,
                          style: FilledButton.styleFrom(
                            backgroundColor: _ink,
                            padding: const EdgeInsets.symmetric(horizontal: 22),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(14),
                            ),
                          ),
                          child: const Text('Agregar'),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 26),
                  if (widget.errorMessage != null)
                    Container(
                      margin: const EdgeInsets.only(bottom: 18),
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: const Color(0xFFFFE7E3),
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: Text(
                        widget.errorMessage!,
                        style: const TextStyle(color: Color(0xFF8A2E25)),
                      ),
                    ),
                  const Text(
                    'Mis tareas',
                    style: TextStyle(
                      color: _ink,
                      fontSize: 24,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 14),
                  if (widget.tasks.isEmpty)
                    const Padding(
                      padding: EdgeInsets.symmetric(vertical: 28),
                      child: Text(
                        'No hay tareas todavía.',
                        textAlign: TextAlign.center,
                        style: TextStyle(color: Colors.grey),
                      ),
                    )
                  else
                    ...widget.tasks.map(
                      (task) => Padding(
                        padding: const EdgeInsets.only(bottom: 10),
                        child: _TaskTile(
                          task: task,
                          onToggle: () => widget.onToggle(task),
                          onDelete: () => widget.onDelete(task),
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _TaskTile extends StatelessWidget {
  const _TaskTile({
    required this.task,
    required this.onToggle,
    required this.onDelete,
  });

  final Task task;
  final VoidCallback onToggle;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    return Card(
      color: task.completed ? const Color(0xFFE9E6DF) : Colors.white,
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: const BorderSide(color: Color(0xFFE7E0D6)),
      ),
      margin: EdgeInsets.zero,
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
        onTap: onToggle,
        leading: Checkbox(
          value: task.completed,
          activeColor: _accent,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
          onChanged: (_) => onToggle(),
        ),
        title: Text(
          task.title,
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w600,
            decoration: task.completed ? TextDecoration.lineThrough : null,
            color: task.completed ? Colors.grey : null,
          ),
        ),
        trailing: IconButton(
          onPressed: onDelete,
          tooltip: 'Eliminar tarea',
          icon: const Icon(Icons.close_rounded),
        ),
      ),
    );
  }
}

TextFormField _emailField(TextEditingController controller) {
  return TextFormField(
    controller: controller,
    keyboardType: TextInputType.emailAddress,
    decoration: const InputDecoration(
      prefixIcon: Icon(Icons.mail_outline),
      hintText: 'Correo electrónico',
    ),
    validator: (value) => value == null || !value.contains('@')
        ? 'Escribe un correo válido'
        : null,
  );
}

TextFormField _passwordField(TextEditingController controller) {
  return TextFormField(
    controller: controller,
    obscureText: true,
    decoration: const InputDecoration(
      prefixIcon: Icon(Icons.lock_outline),
      hintText: 'Contraseña',
    ),
    validator: (value) =>
        value == null || value.length < 6 ? 'Usa al menos 6 caracteres' : null,
  );
}

ButtonStyle _primaryButtonStyle() {
  return FilledButton.styleFrom(
    backgroundColor: _accent,
    minimumSize: const Size.fromHeight(48),
    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
  );
}

ButtonStyle _secondaryButtonStyle() {
  return OutlinedButton.styleFrom(
    foregroundColor: _ink,
    minimumSize: const Size.fromHeight(42),
    side: const BorderSide(color: Color(0xFFD8D0C5)),
    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
  );
}
