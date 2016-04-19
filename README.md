# Kudu Tasks

This extension contains a tasks for integration with [Kudu](https://github.com/projectkudu/kudu). Kudu is the engine behind git/hg deployments, WebJobs, and various other features in Azure Web Sites.

Note: These tasks are neither developed nor endorsed by creators of Kudu.

This extension includes the following tasks:
* Kudu upload task

## Kudu upload task
With this task you can upload zip package into Kudu

### Get Started
* First of all you need to define Azure Classic service endpoint. [More Information](https://msdn.microsoft.com/library/vs/alm/release/author-release-definition/understanding-tasks#Serviceendpoints)
* Then you need to add task into your build or release definition.
![add upload task](https://raw.githubusercontent.com/aquiladev/vsts-kudu-tasks/master/Extension/Images/add_upload_task.png)

* And fill settings for the task
![settings](https://raw.githubusercontent.com/aquiladev/vsts-kudu-tasks/master/Extension/Images/upload_task_settings.png)
