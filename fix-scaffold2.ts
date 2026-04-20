import * as fs from 'fs';

let content = fs.readFileSync('lib/pages/map_page.dart', 'utf-8');

// The first run of fix-scaffold apparently failed.
// Let's do a reliable replacement for Scaffold

// 1. First add bottomNavigationBar to the Scaffold
const targetScaffold = `      return Scaffold(
        resizeToAvoidBottomInset: false,
        body: Stack(`;
const replacementScaffold = `      return Scaffold(
        resizeToAvoidBottomInset: false,
        extendBody: true,
        bottomNavigationBar: SafeArea(top: false, child: _buildBottomNavigationBar()),
        body: Stack(`;

if(content.includes(targetScaffold)) {
  content = content.replace(targetScaffold, replacementScaffold);
} else {
  console.log("Could not find Scaffold definition");
}

// 2. Remove the absolutely positioned bar from the Stack
const bottomBarTarget = `
            Positioned(
              left: 0,
              right: 0,
              bottom: 0,
              child: SafeArea(top: false, child: _buildBottomNavigationBar()),
            ),`;

if(content.includes(bottomBarTarget)) {
  content = content.replace(bottomBarTarget, '');
} else {
  console.log("Could not find positioned bottom bar");
}

fs.writeFileSync('lib/pages/map_page.dart', content, 'utf-8');
console.log('Fixed scaffold.');
