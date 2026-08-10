# DevOpsProject-UserStory


## BACK-END
### Technical Details

- **Programming Language back-end:** Java
- **Database:** MariaDB
- **Required Tools:** Java 17, Maven 3.6.3

### Running the Project

1. **Build the Project:**

   Execute the following command:
```bash
mvn clean package
```

2. **Run the Project:**

After successful building, run the .jar file in the ./target folder:

```bash
java -jar target/[file-name.jar]
```
```text
   The application will start on 8080 port.
```

* **Database Configuration**

In the application's configuration file (application.properties), the path and connection data to the database are obtained from the following environment variables:

    DB_USERSTORYPROJ_URL
    DB_USERSTORYPROJ_USER
    DB_USERSTORYPROJ_PASSWORD

Before running, ensure that the MariaDB database contains a database named userstory and a table named projects with the fields:

```sql
CREATE TABLE projects (
id bigint not null auto_increment,
description varchar(255),
name varchar(255),
primary key (id)
);
```

## FRONT-END
### Technical Details

- **Front-end written on:** React JS
- **Required Tools:** nodejs 20.11.0 version, npm 10.2.4 version

### Running the Project

**Build the Project:**

Execute the following command:
```bash
npm install
```

**Run the Project:**

After successful building you could run the front-end in dev mode:

```bash
npm start
```
The application will start on 3000 port.**


To build the front-end to production run command:

```bash
npm run build
```

```text
    The application will appear in the ./build folder.
    Copy all files in your webserver and configure it.
```

**Back-end Configuration**

The path and connection data to the back-end are obtained from the following environment variable `BACKEND_URL`

Before running, ensure that the back-end was running.

Notes

    The project is at an early development stage, and currently, only CRUD operations for the Project entity are implemented.

---
