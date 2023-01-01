下载编译
```ssh
git clone git@github.com:rudolphbrowne/dolphinscheduler.git

<!-- 切换一个可以下载到 jar 的 VPN -->
./mvnw clean install -Prelease -DskipTests
<!-- 打包位置：dolphinscheduler-dist/target/apache-dolphinscheduler-dev-SNAPSHOT-bin.tar.gz -->
```

