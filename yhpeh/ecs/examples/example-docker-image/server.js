const http = require('http');
const process = require('process');
const spawn = require('child_process').spawnSync;

const hostname = '0.0.0.0';
const port = 3000;

var cachedServerText = null;

const server = http.createServer((req, res) => {
  res.statusCode = 200;
  res.setHeader('Content-Type', 'text/plain');

  cachedServerText = cachedServerText || getServerText();
  res.end(cachedServerText + '\n');
});

function getServerText() {
  if (process.env.S3_TEST_FILE && process.env.SERVER_TEXT) {

    // Get the AWS Region
    var aws_region = process.env.AWS_REGION

    // Download the S3 File
    const output = spawn("aws", ["s3", "cp", process.env.S3_TEST_FILE, "-", "--region", aws_region]);
    if (output.status == 0) {
      return process.env.SERVER_TEXT + " " + output.stdout;
    } else {
      console.error(`ERROR: Unable to download s3 test file: ${process.env.S3_TEST_FILE}`);
      console.error("status: " + (output.status ? output.status.toString() : "(no status)"));
      console.error("stdout: " + (output.stdout ? output.stdout.toString('utf8') : "(no stdout)"));
      console.error("stderr: " + (output.stderr ? output.stderr.toString('utf8') : "(no stderr)"));
      console.error("error message:  " + (output.error ? output.error.message : "(no error message defined)"));
      throw output.error;
    }
  } else {
    return "Hello world!";
  }
}

server.listen(port, hostname, () => {
  console.log(`Server running at http://${hostname}:${port}/`);
});