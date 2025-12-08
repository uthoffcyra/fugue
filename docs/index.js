// Fugue Web Environment
var computer;
var files = {};

var load_these_files = [
    // Interpreter Source Code
    {source_folder:'src', target_folder: 'fugue/',
    files:['fugue_fe.lua','fugue_interp.lua','fugue_lexer.lua',
        'fugue_lib.lua','fugue_state.lua','fugue_walk.lua',
        'fugue_builtin.lua', 'fugue_symtab.lua']},
    // Basic Configuration
    {source_folder:'docs/site-res', target_folder: '',
    files:['.fugue.motd','.settings','startup.lua']},
    // Example Files
    {source_folder:'docs/site-res', target_folder: 'example/',
    files:['1-arithmetic.fe','2-keywatcher.fe','3-train-station.fe']}
];

async function load_interpreter() {

    const allPromises = [];

    load_these_files.forEach((folder_object) => {
        folder_object.files.forEach((file_name) => {

            let base = 'https://raw.githubusercontent.com/uthoffcyra/fugue/';
            let source_folder = folder_object.source_folder;
            let target_folder = folder_object.target_folder;

            const promise = fetch(base+ 'refs/heads/main/'+source_folder+'/'+file_name)
            .then(response => response.text())
            .then(body=>{
                files[target_folder+file_name] = body;
                console.log('['+file_name+']');
            });

            allPromises.push(promise);
        });
    });

    await Promise.all(allPromises);

    console.log('load emulator');
    load_emulator();

}

function load_emulator() {
    // Remove Loader
    document.getElementById('loading-emulator').style.setProperty('display', 'none');
    document.getElementById('emu-display').style.setProperty('display', 'block');
    // Tell requirejs to load copycat/* from the website.
    require.config({ paths: { copycat: "https://copy-cat.squiddev.cc/" } });
    // Find our #embed-computer element and inject a computer terminal into it.
    require(["copycat/embed"], setup => {
        setup(document.getElementById("embed-computer"), {
            width: 80,
            height: 30,
            files: files
        }).then((res) => {
            computer = res;
        });
    });
}

var examples = [
    {
        title: 'Arithmetic',
        file: 'example/1-arithmetic.fe',
        sub_emulators: ['fileview']
    },
    {
        title: 'Keywatcher',
        file: 'example/2-keywatcher.fe',
        sub_emulators: ['fileview']
    },
    {
        title: 'Train Station',
        file: 'example/3-train-station.fe',
        sub_emulators: ['fileview', 'train-sim']
    }
]

// another option is to make a custom terminal that takes events
function run_example(n) {

    let filename = examples[n-1].file;
    let temp_addin = `
    -- remove anything past this
    local file = fs.open('startup.lua', 'r')
    local full = ''
    for i=1,7 do full = full..file.readLine()..'\\n' end
    file.close()
    file = fs.open('startup.lua', 'w')
    file.write(full)
    file.close()

    term.setTextColor(colors.yellow) write('> ')
    term.setTextColor(colors.white) write('fe ${filename}\\n')
    shell.run('fe ${filename}')
    `;
    let final_addin = new TextEncoder().encode(files['startup.lua'] + temp_addin);
    computer.getEntry('startup.lua').setContents(final_addin);

    window.scrollTo(0, 0);
    computer.reboot();

    // Fileview
    if (examples[n-1].sub_emulators.includes('fileview')) {
        document.getElementById('fileview').style.display = 'block';
        document.getElementById('fileview-path').textContent = filename;
        if (files[filename]) {
            highlight(files[filename]);
        };
    } else { closeWindow('fileview') };
    
    // Train Simualtor
    if (examples[n-1].sub_emulators.includes('train-sim')) {
        document.getElementById('train-sim').style.display = 'block';
    } else { closeWindow('train-sim') };
}

function closeWindow(id) {
    document.getElementById(id).style.display = 'none';
}

window.addEventListener('load', (event) => {
    load_interpreter();
    startTrainTimers();
});