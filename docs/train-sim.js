// train simulation for fugue website

let train_system = {
    paths: {
        'NW-SE': {
            segments: ['Track-NW-1','Track-NW-2','Track-NW-3',
                'Track-NW-4','Track-NW-5','Track-NW-6','Station',
                'Track-SE-1','Track-SE-2','Track-SE-3','Track-SE-4',
                'Track-SE-5','Track-SE-6'],
            loop_type: 'restart',
            loop_time: 5000 
        },
        'W-E/W-E': {
            segments: ['Track-W-1','Track-W-2','Track-W-3','Track-W-4',
                'Track-W-5','Station','Track-E-1','Track-E-2',
                'Track-E-3','Track-E-4','Track-E-5'],
            loop_type: 'bounce',
            loop_time: 400
        }
    },
    carriages: [
        {
            name: 'Orange Line',
            path: 'W-E/W-E',
            color: '#FF8C00',
            seg_id: -1,
            speed: 400,
            time_at_station: 1600
        },
        {
            name: 'Bay Line',
            path: 'NW-SE',
            color: '#2ECFC1',
            seg_id: -1,
            speed: 200,
            time_at_station: 1200
        }
    ]
};

function actualSegId(path,id) {
    if (path.loop_type == 'bounce' && id >= path.segments.length) {
        let calculate = path.segments.length-(id-path.segments.length)-2;
        console.log('bounceback ' + id + ' -> ' + calculate);
        return calculate;
    } else {
        return id;
    }
}

function trainDiagramUpdate(path,prev_id,next_id,color) {

    let a1 = actualSegId(path, prev_id);
    let a2 = actualSegId(path, next_id);

    if (a1 != -1) {
        document.getElementById(path.segments[a1])
            .setAttribute('fill','#ffffff');
    }
    if (a2 != -1) {
        document.getElementById(path.segments[a2])
            .setAttribute('fill',color);
    }
}

function updateTrain(index) {
    let config = train_system.carriages[index];
    let path = train_system.paths[config.path];
    let prev_seg_id = config.seg_id;
    
    /* Prevent Station Crashes */
    if (path.segments[actualSegId(path,config.seg_id+1)] == 'Station' && document.getElementById('Station').getAttribute('fill') != '#ffffff') {
        setTimeout(()=>{ updateTrain(index) }, 100);
        return;
    }
    
    /* Moving Forward */
    config.seg_id = config.seg_id + 1;
    if (path.loop_type == 'bounce' && config.seg_id >= (path.segments.length*2)-2) { // Bounce loop is double...
        config.seg_id = 0;
    } else if (path.loop_type == 'restart' && config.seg_id >= path.segments.length) { // At end of path..
        config.seg_id = -1;
    }

    trainDiagramUpdate(path,prev_seg_id,config.seg_id,config.color);

    // Send Event to Computer.
    if (path.segments[actualSegId(path,config.seg_id)] == 'Station') {
        computer.queueEvent('train_arrival',[config.name]);
    }
    
    /* Schedule Next Update */
    if (path.segments[config.seg_id] == 'Station') { // At station.
        setTimeout(()=>{ updateTrain(index) },config.time_at_station);
    } else if (config.seg_id == -1 || (config.seg_id == 0 && path.loop_type == 'bounce')) { // At loop.
        setTimeout(()=>{ updateTrain(index) },path.loop_time);
    } else { // Normal.
        setTimeout(()=>{ updateTrain(index) },config.speed);
    }
}

function startTrainTimers() {
    train_system.carriages.forEach((train_config,index)=>{
        updateTrain(index);
    });
}

/* notes */
// https://svg-tutorial.com/svg/interaction
// setTimeout(async () => (await computer).queueEvent("from_js", ["Got event from JS"]), 5000);
// or just,
// computer.queueEvent("from_js", ["Got event from JS"]);