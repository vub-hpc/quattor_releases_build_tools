# Quattor Build Tools

To build the container image:

```podman build -t quattorbuild -f Dockerfile .```

Create a directory that will be shared between the host and the container. In this directory, do a ```git clone``` of this project.

To launch the container:

```podman run -it --user=<youruserid>:<yourgroupid> --userns=keep-id -v <shared_directory>:/home:z localhost/quattorbuild```


Inside the container:

* create a gpg key: ```gpg --gen-key```
* launch the gpg-agent in background: ```gpg-agent --daemon```
* run the releaser script: ```./releaser.sh 22.10.1 1```

## Batch builder

With the script <b>batch_build_repos.py</b>, you can build a list of Quattor repositories that are specified in a JSON file <b>tobuild.json</b>. For each repository, the dictionary in the JSON will tell which branch to compile, as well as the list of PRs to apply before building, and the final version string to apply to the generated RPM packages. This script comes with an help (--help).

As the gpg plugin of Maven will require the passphrase to unlock the private key, it can be fixed by creating the following settings.xml in the $HOME/.m2 directory:
```<settings>
  <profiles>
    <profile>
      <id>gpg</id>
      <properties>
        <gpg.executable>gpg2</gpg.executable>
        <gpg.passphrase>your_passphrase</gpg.passphrase>
      </properties>
    </profile>
  </profiles>
  <activeProfiles>
    <activeProfile>gpg</activeProfile>
  </activeProfiles>
</settings>
```
### Edit the JSON file

* To create a default JSON file if it does not exist yet:

```./batch_build_repos.py --init```

* To display the content of the JSON:

```./batch_build_repos.py --display```

* To add a new entry in the JSON:

```./batch_build_repos.py --edit --repo <repo> --branch <branch>```

* To specify a comma-seperated list of PRs that you want to merge to the branch of the repository:

```./batch_build_repos.py --edit --repo <repo> --addprs <list_of_prs>```

The specified will be added to the previous ones.

* To remove the PRs for a repository:

```./batch_build_repos.py --edit --repo <repo> --delprs```

* To build all the repositories from the JSON:

```./batch_build_repos.py --build```

* To build everything except a comma-separated list of repositories:

```./batch_build_repos.py --build --ignore <list_of_repositories>```

* To only build a comma-separated list of repositories:

```./batch_build_repos.py --build --only <list_of_repositories>```

