// Fugue Web Environment
var computer;

var files = {
    '.settings': `{
        [ "list.show_hidden" ] = false,
        [ "motd.path" ] = ".fugue.motd",
    }`,
    '.fugue.motd': 'Welcome to Fugue Lang!',
    'startup.lua': `shell.setPath( shell.path()..":/fugue" )`,
    'examples/test.fe': `~ web test! ~
    let x = 10;
    `
}

var load_these_files = ['fugue_fe.lua','fugue_interp.lua','fugue_lexer.lua',
    'fugue_lib.lua','fugue_state.lua'];
let loadreq = load_these_files.length;
let loaded = 0;

function load_interpreter() {
    load_these_files.forEach((fname) => {
        fetch('https://raw.githubusercontent.com/uthoffcyra/fugue/refs/heads/main/src/'+fname)
        .then((response) => response.text().then((body)=>{
            file_callback(fname, body)
        }));
    });
}
function file_callback(fname,body) {
    files['fugue/'+fname] = body;
    loaded+=1;
    if (loaded == loadreq) load_emulator();
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
function execute_code() {
    computer.reboot()

    // set startup file to 1) open desired file... 2) perform desired command
    // reboot
}

// setTimeout(async () => (await computer).queueEvent("from_js", ["Got event from JS"]), 5000);

window.addEventListener('load', (event) => {
    load_interpreter();
});