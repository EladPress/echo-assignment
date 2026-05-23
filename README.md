# echo-assignment: Elad Press

For this assignment I have chosen to remove these two CVEs:

| CVE            | From                       | Severity | Method             | Details                                  |
| -------------- | -------------------------- | -------- | ------------------ | ---------------------------------------- |
| CVE-2025-27363 | libfreetype6@2.12.1+dfsg-5 |   HIGH   | Version bump       | New version: 2.12.1+dfsg-5+deb12u4       |
| CVE-2024-45491 | libexpat1@2.5.0-1          | CRITICAL | Patch backporting  | Patch backported from: 2.5.0-1+deb12u2   |


## Result Images

The 'build' directory contains the Dockerfile that builds that patched .debs required for the final nginx image. This 'builder image' is then used in 'Containerfile' to build the final nginx image.

This project has a CI process in GitHub Actions that creates and pushes both these images (The final image depends on the builder image). \
Here are the image names as they are in Docker Hub:
1. eladpress/echo-assignment-builder:{BRANCH_NAME (use 'master')}
2. eladpress/echo-assignment-nginx-patched:{BRANCH_NAME (use 'master')} \
    This new image's size (according to Docker CLI) is ~160MB, smaller than the original image, at 193MB

## Build Instructions

Building this project is rather simple, only requiring Docker, as the build is created within a Docker container.
GitHub Actions already creates the images automatically, and are available for access publicly:
1. eladpress/echo-assignment-builder:master
2. eladpress/echo-assignment-nginx-patched:master

A local option is of course available in the form of the 'build/build-final-image-locally.sh' file, which will create both builder and final image with the tag 'local-test'.

Run the patched nginx image by simply running: \
```
source run-patched-image.sh
```
This command runs the image from Docker Hub. If you wish to run the local-test image run:
```
source run-patched-image.sh local-test
```

## Tests

The 'test' directory includes tests and small scripts that assisted with the development of this project:

1. run_test.sh: This file runs the compatability test that is required by this assignment. \
The file runs a docker-compose file that runs both original and my patched images as containers, and a third container containing a python file with the actual tests which are HTTP requests to both containers to make sure results are identical in both containers. \
    Run this test by running:
    ```
    cd test/
    source run-test.sh
    ```

2. scan-images.sh: This file performs a Trivy scan on both original and my patched image. \
    After running this script both tests results will be in 'scan-results/'.

3. I remember there being more tests/scripts :)

## Residual Risk Assessment

Additional vulnerabilities remain in the final image, some with high severity. What i'd do next is try to remove those CVEs, and see what dependencies/binaries are unused by nginx and remove them. \
I did not remove the remaining CVEs or check if some deps/binaries are unnecessary and remove them because that was outside the scope of this assignment.

## Use of AI in this project

This type of assignment contained a lot of new things for me, and I had a lot to learn while performing it.\
I used Claude primarily and ChatGPT when I ran out of requests in Cluade in order to first understand the assignment and what was required of me, and understanding subject such as CVEs, VEX files, Trivy, etc. \
I also used these AI tools to set up my project, for example: create an initial GitHub Actions YAML file from which to build upon, create the Docker compose file, as i'm not experienced with both these tools.

These tools may often hurt me during software development when asking them for advanced solutions or architectures. I often find the solutions they give me to be convoluted or too complicated, and I prefer simpler, more readable solutions. I do not like to rely on AI for engineering large scale solutions and architectures as it may be very hard for most people to dive in and understand what the AI creates for you. \
Because of that, I find it better to ask AI for smaller scale solutions, and of course verify what it gives you.

## Reflecting on the Project

I was surprised by this assignment as it contained a lot of topics I have never touched before.

I noted that using the official nginx image as a base image for my image would have proven simpler, as I would have just installed the patched dependencies onto that image. \
But given that this was not the assignment I did not do that, and this proved to results in a better image, with a smaller size and as it turns out much less CVEs

Given more time, I could have probably reduced the size of the image further, but this was not the goal of the assignment so I did not pursue this.

Also, I think it would be better practice (outside of this assignment) to run my compatability tests as part of the CI process, before the final image is pushed to Docker Hub. \
This way an image would not have been pushed if it turned out to be flawed.

My project creates a builder image from which the final image can take the patched dependencies. If I would have to propose an larger scale solution for such things I would have considered having the patched dependencies uploaded into an artifact registry, from which final images can all pull artifacts.
