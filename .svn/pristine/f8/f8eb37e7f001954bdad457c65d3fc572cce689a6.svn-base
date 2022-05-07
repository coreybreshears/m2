var intervalId = setInterval(function(){timer()}, 30);
var elapsedTime=0;

function setProgress(percent) {
  document.getElementById("bar1").style.width = percent + '%';
}

function timer() {
  if (elapsedTime >= 99) {
    document.getElementById("bar1").style.display = 'none';
    clearInterval(intervalId);
  } else if (elapsedTime >= 85) {
    // slow down, cause it still not fully loaded
    elapsedTime++;
    setProgress(elapsedTime);
  } else {
    elapsedTime += 10;
    setProgress(elapsedTime);
  }
}