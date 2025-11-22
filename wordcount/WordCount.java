import java.util.Arrays;
import org.apache.spark.SparkConf;
import org.apache.spark.api.java.*;
import scala.Tuple2;

public class WordCount {
    public static void main(String[] args) {
        if (args.length < 2) {
            System.out.println("Usage: WordCount <inputFile> <outputDir>");
            System.exit(1);
        }
        String inputFile = args[0];
        String outputDir = args[1];

        SparkConf conf = new SparkConf().setAppName("WordCount");
        JavaSparkContext sc = new JavaSparkContext(conf);

        long t1 = System.currentTimeMillis();

        JavaRDD<String> lines = sc.textFile(inputFile);
        JavaRDD<String> words = lines.flatMap(s -> Arrays.asList(s.split("\\s+")).iterator());
        JavaPairRDD<String, Integer> counts = words
            .mapToPair(w -> new Tuple2<>(w, 1))
            .reduceByKey(Integer::sum);

        counts.saveAsTextFile(outputDir);

        long t2 = System.currentTimeMillis();

        System.out.println("Execution time (ms): " + (t2 - t1));
        sc.close();
    }
}
