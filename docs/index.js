// Fugue Web Environment
var computer;

// Tell requirejs to load copycat/* from the website.
require.config({ paths: { copycat: "https://copy-cat.squiddev.cc/" } });
// Find our #embed-computer element and inject a computer terminal into it.
require(["copycat/embed"], setup => {
    setup(document.getElementById("embed-computer"), {
        width: 80,
        height: 30,
    }).then((res) => {
        computer = res;
    });
});

addEventListener("resize", (event) => {
    let w = window.innerWidth;
    let h = window.innerHeight;
})