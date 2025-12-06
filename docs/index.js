// Fugue Web Environment
var computer;
var files = {};

var load_these_files = [
    {source_folder:'src', target_folder: 'fugue/',
    files:['fugue_fe.lua','fugue_interp.lua','fugue_lexer.lua',
        'fugue_lib.lua','fugue_state.lua','fugue_walk.lua',
        'fugue_builtin.lua', 'fugue_symtab.lua']},
    {source_folder:'docs/site-res', target_folder: '',
    files:['.fugue.motd','.settings','startup.lua']}
];

function load_interpreter() {
    load_these_files.forEach((folder_object) => {

        folder_object.files.forEach((file_name) => {

            let base = 'https://raw.githubusercontent.com/uthoffcyra/fugue/';
            let source_folder = folder_object.source_folder;
            let target_folder = folder_object.target_folder;

            fetch(base+ 'refs/heads/main/'+source_folder+'/'+file_name)
            .then((response) => response.text().then((body)=>{
                files[target_folder+file_name] = body;
            }));

        });

    });

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

// another option is to make a custom terminal that takes events
function run_file() {
    computer.reboot()

    // set startup file to 1) open desired file... 2) perform desired command
    // reboot
}

// setTimeout(async () => (await computer).queueEvent("from_js", ["Got event from JS"]), 5000);

window.addEventListener('load', (event) => {
    load_interpreter();
});