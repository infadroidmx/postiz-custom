const fs = require('fs');
const path = require('path');

function fixBom(dir) {
    const files = fs.readdirSync(dir);
    for (const file of files) {
        const fullPath = path.join(dir, file);
        if (fs.statSync(fullPath).isDirectory()) {
            fixBom(fullPath);
        } else if (fullPath.endsWith('translation.json')) {
            let content = fs.readFileSync(fullPath);
            if (content[0] === 0xEF && content[1] === 0xBB && content[2] === 0xBF) {
                content = content.slice(3);
                fs.writeFileSync(fullPath, content);
                console.log('Fixed BOM: ' + fullPath);
            }
        }
    }
}

fixBom('libraries/react-shared-libraries/src/translation/locales');
console.log('BOM Fix Complete');
