---
title: "Tests avec Hadoop"
date: "2017-08-02T13:23:14-04:00"
updated: "2017-08-02T13:23:14-04:00"
author: "C. Boyer"
license: "Creative Commons BY-SA-NC 4.0"
website: "https://cboyer.github.io"
category: "Linux"
keywords: [Hadoop, Linux, Java]
abstract: "Tests avec Hadoop."
---


Lancer le DFS
```console
start-dfs.sh
```

Lancer YARN
```console
start-yarn.sh
```

Formatter le DFS
```console
hadoop namenode -format
```

Statut du cluster
```console
hadoop dfsadmin -report
```

Statut des services
```console
jps
```

URL de statut du cluster (NameNode)
```console
http://192.168.56.200:8088
```

Lister le contenu du DFS
```console
hadoop fs -ls /
```

Créer le dossier /input et /output
```console
hadoop fs -mkdir /input
hadoop fs -mkdir /output
```

Envoyer les données sur le DFS
```console
hadoop fs -put file01 /input
```

Example de WordCount.java
```Java
import java.io.IOException;
import java.util.StringTokenizer;

import org.apache.hadoop.conf.Configuration;
import org.apache.hadoop.fs.Path;
import org.apache.hadoop.io.IntWritable;
import org.apache.hadoop.io.Text;
import org.apache.hadoop.mapreduce.Job;
import org.apache.hadoop.mapreduce.Mapper;
import org.apache.hadoop.mapreduce.Reducer;
import org.apache.hadoop.mapreduce.lib.input.FileInputFormat;
import org.apache.hadoop.mapreduce.lib.output.FileOutputFormat;

public class WordCount {

  public static class TokenizerMapper
       extends Mapper<Object, Text, Text, IntWritable>{

    private final static IntWritable one = new IntWritable(1);
    private Text word = new Text();

    public void map(Object key, Text value, Context context
                    ) throws IOException, InterruptedException {
      StringTokenizer itr = new StringTokenizer(value.toString());
      while (itr.hasMoreTokens()) {
        word.set(itr.nextToken());
        context.write(word, one);
      }
    }
  }

  public static class IntSumReducer
       extends Reducer<Text,IntWritable,Text,IntWritable> {
    private IntWritable result = new IntWritable();

    public void reduce(Text key, Iterable<IntWritable> values,
                       Context context
                       ) throws IOException, InterruptedException {
      int sum = 0;
      for (IntWritable val : values) {
        sum += val.get();
      }
      result.set(sum);
      context.write(key, result);
    }
  }

  public static void main(String[] args) throws Exception {
    Configuration conf = new Configuration();
    Job job = Job.getInstance(conf, "word count");
    job.setJarByClass(WordCount.class);
    job.setMapperClass(TokenizerMapper.class);
    job.setCombinerClass(IntSumReducer.class);
    job.setReducerClass(IntSumReducer.class);
    job.setOutputKeyClass(Text.class);
    job.setOutputValueClass(IntWritable.class);
    FileInputFormat.addInputPath(job, new Path(args[0]));
    FileOutputFormat.setOutputPath(job, new Path(args[1]));
    System.exit(job.waitForCompletion(true) ? 0 : 1);
  }
}
```

Compiler le code java
```console
hadoop com.sun.tools.javac.Main WordCount.java
jar cf wc.jar WordCount*.class
```

Lancer la job
```console
hadoop jar wc.jar WordCount /input /output
```

Lister les jobs
```console
hadoop job -list
```

Récupérer le résultat
```console
hadoop fs -get /output output
```

## Liens complémentaires
 - [https://anchalkataria.wordpress.com/2016/05/01/installing-hadoop-in-fully-distributed-mode/](https://anchalkataria.wordpress.com/2016/05/01/installing-hadoop-in-fully-distributed-mode/)
 - [https://hadoop.apache.org/docs/r2.7.3/hadoop-project-dist/hadoop-hdfs/HDFSCommands.html](https://hadoop.apache.org/docs/r2.7.3/hadoop-project-dist/hadoop-hdfs/HDFSCommands.html)
 - [https://www.tutorialspoint.com/hadoop/hadoop_multi_node_cluster.htm](https://www.tutorialspoint.com/hadoop/hadoop_multi_node_cluster.htm)

