# Terraform Training Workspace

This is a workspace for the Infrastructure as Code with Terraform Workshop. Students will have write access to this
repo so they can collaborate on code here.




## File layout

Please make sure to use the following file layout:

```
├── README.md
└── <username>
    └── exercise-<number>
        ├── main.tf
        ├── outputs.tf
        └── vars.tf
```

That is, each student gets a top-level folder named after their username, and within that folder, you put the solutions
for each exercise in a folder named `exercse-<number>`. For example:

```
├── README.md
├── brikis98
│   ├── exercise-01
│   │   ├── main.tf
│   │   ├── outputs.tf
│   │   └── vars.tf
│   └── exercise-02
│       ├── main.tf
│       ├── outputs.tf
│       └── vars.tf
└── josh-padnick
    ├── exercise-01
    │   ├── main.tf
    │   ├── outputs.tf
    │   └── vars.tf
    └── exercise-02
        ├── main.tf
        ├── outputs.tf
        └── vars.tf
```


 
 
## Making changes

To make changes, you must open a [pull request](https://help.github.com/articles/about-pull-requests/). Here's the
typical process for doing that:

1. Clone this repo: `git clone git@github.com:gruntwork-io/terraform-training-workspace.git`
1. Create a branch: `git checkout -b <USERNAME>/exercise-<number>` (e.g., `git checkout -b brikis98/exercise-01`)
1. Make your changes.
1. Commit: `commit -m "<COMMIT_MESSAGE>"`
1. Push: `git push origin <USERNAME>/exercise-<number>` (e.g., `git push origin brikis98/exercise-01`)
1. Go to https://github.com/gruntwork-io/terraform-training-workspace in your browser, switch to your branch, and 
   click the "Create a pull" request button, [as documented here](https://github.com/gruntwork-io/terraform-training-workspace).
    
Alternatively, you could use [GitHub Desktop](https://desktop.github.com/) or [hub](https://hub.github.com/).