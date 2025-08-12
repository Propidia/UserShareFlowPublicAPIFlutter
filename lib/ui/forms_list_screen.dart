import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../controllers/form_controller.dart';
import 'dynamic_form_screen.dart';

class FormsListScreen extends StatefulWidget {
  const FormsListScreen({super.key});

  @override
  State<FormsListScreen> createState() => _FormsListScreenState();
}

class _FormsListScreenState extends State<FormsListScreen> {
  final formController = Get.put(FormController());

  @override
  void initState() {
    super.initState();
    formController.loadForms();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('النماذج المدعومة'),
        actions: [
          IconButton(
            icon: const Icon(Icons.developer_mode),
            tooltip: 'لوحة المطوّر',
            onPressed: () => Get.toNamed('/dev'),
          ),
        ],
      ),
      body: Obx(() {
        if (formController.isLoadingForms.value) {
          return const Center(child: CircularProgressIndicator());
        }
        final forms = formController.forms;
        return Column(
          children: [
            Padding(
              padding: const EdgeInsets.all(12),
              child: TextField(
                decoration: const InputDecoration(
                  prefixIcon: Icon(Icons.search),
                  hintText: 'بحث بالاسم أو بالمعرّف...',
                ),
                onChanged: formController.filterForms,
              ),
            ),
            const Divider(height: 1),
            if (forms.isEmpty)
              const Expanded(child: Center(child: Text('لا توجد نتائج')))
            else
              Expanded(
                child: ListView.separated(
                  itemCount: forms.length,
                  separatorBuilder: (_, __) => const Divider(height: 1),
                  itemBuilder: (context, index) {
                    final f = forms[index];
                    return ListTile(
                      title: Text(f['name']?.toString() ?? ''),
                      subtitle: Text('ID: ${f['id']}'),
                      trailing: const Icon(Icons.arrow_back_ios_new),
                      onTap: () {
                        Get.to(() => DynamicFormScreen(formId: f['id'] as int));
                      },
                    );
                  },
                ),
              ),
          ],
        );
      }),
    );
  }
}
