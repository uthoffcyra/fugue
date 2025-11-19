// Fugue Web Environment
var computer;

let default_settings = `{
    [ "list.show_hidden" ] = false,
    [ "motd.path" ] = ".fugue.motd",
}`;

let fugue_motd = `Welcome to Fugue Lang!`;

// Tell requirejs to load copycat/* from the website.
require.config({ paths: { copycat: "https://copy-cat.squiddev.cc/" } });
// Find our #embed-computer element and inject a computer terminal into it.
require(["copycat/embed"], setup => {
    setup(document.getElementById("embed-computer"), {
        width: 80,
        height: 30,
        files: {
            ".settings": default_settings,
            ".fugue.motd": fugue_motd
        }
    }).then((res) => {
        computer = res;
    });
});

addEventListener("resize", (event) => {
    let w = window.innerWidth;
    let h = window.innerHeight;
})