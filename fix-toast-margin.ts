import * as fs from 'fs';

let content = fs.readFileSync('lib/pages/map_page.dart', 'utf-8');

const oldShowToast = `  void _showToast(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..clearSnackBars()
      ..showSnackBar(
        SnackBar(
          content: Text(message),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          behavior: SnackBarBehavior.floating,
          margin: const EdgeInsets.only(bottom: 24.0, left: 16.0, right: 16.0),
          duration: const Duration(seconds: 2),
        ),
      );
  }`;

const newShowToast = `  void _showToast(String message) {
    if (!mounted) return;
    final bottomInset = MediaQuery.of(context).padding.bottom;
    final navBarHeight = 72.0 + bottomInset + 16.0;
    ScaffoldMessenger.of(context)
      ..clearSnackBars()
      ..showSnackBar(
        SnackBar(
          content: Text(message),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          behavior: SnackBarBehavior.floating,
          margin: EdgeInsets.only(bottom: navBarHeight, left: 16.0, right: 16.0),
          duration: const Duration(seconds: 2),
        ),
      );
  }`;

if (content.includes(oldShowToast)) {
  content = content.replace(oldShowToast, newShowToast);
} else {
  console.log('Not found');
}

fs.writeFileSync('lib/pages/map_page.dart', content, 'utf-8');
console.log('Fixed _showToast margin.');
