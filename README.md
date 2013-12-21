### Description


This module is meant to serve as a short and easy-to-run pipes examples.

It emulates message streams communications between 0MQ sockets. It uses `inproc` (in-process) protocol to ease setup.

Currently the purpose is purely educational. Do not hesitate to comment using Github issues.

#### Echo (REP/REQ)

The "echo" executable emulates an echo server. The client first connect to the echo server and waits for console input (stdin). The client socket will send console message to the server and wait back the echo reply from the server.  It then prints back this reply to the console (stdout).

#### SUB (PUB/SUB)

Sub emulates the publication of weather data. A sub socket subscribes using zipcode as tag, then prints to stdout all data it receives. Every 10 records, it prints a summary report with the average temperature and humidity.

