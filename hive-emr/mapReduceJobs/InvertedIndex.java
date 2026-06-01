import java.io.IOException;
import java.util.HashSet;
import java.util.TreeSet;

import org.apache.hadoop.conf.Configuration;
import org.apache.hadoop.fs.Path;
import org.apache.hadoop.io.LongWritable;
import org.apache.hadoop.io.Text;
import org.apache.hadoop.mapreduce.Job;
import org.apache.hadoop.mapreduce.Mapper;
import org.apache.hadoop.mapreduce.Reducer;
import org.apache.hadoop.mapreduce.lib.input.FileInputFormat;
import org.apache.hadoop.mapreduce.lib.input.FileSplit;
import org.apache.hadoop.mapreduce.lib.output.FileOutputFormat;
import org.apache.hadoop.util.GenericOptionsParser;

public class InvertedIndex {

    public static class IndexMapper extends Mapper<LongWritable, Text, Text, Text> {
        private String filename;
        private HashSet<String> localWords;

        @Override
        protected void setup(Context context) {
            // extract the filename for the current split assigned to this mapper
            FileSplit split = (FileSplit) context.getInputSplit();
            filename = split.getPath().getName();
            
            localWords = new HashSet<>();
        }

        @Override
        public void map(LongWritable key, Text value, Context context) {
            String line = value.toString().toLowerCase();
            String[] words = line.split("[^a-z0-9]+");
            
            for (String word : words) {
                if (word.length() > 0) {
                    localWords.add(word);
                }
            }
        }

        @Override
        protected void cleanup(Context context) throws IOException, InterruptedException {
            Text fileText = new Text(filename);
            Text wordText = new Text();
            
            for (String word : localWords) {
                wordText.set(word);
                context.write(wordText, fileText);
            }
        }
    }

    public static class IndexReducer extends Reducer<Text, Text, Text, Text> {
        @Override
        public void reduce(Text key, Iterable<Text> values, Context context) 
                throws IOException, InterruptedException {
            
            // handles uniqueness and alphabetical sorting
            TreeSet<String> uniqueFiles = new TreeSet<>();
            
            for (Text val : values) {
                uniqueFiles.add(val.toString());
            }

            // join the sorted filenames into a string separated by commas
            String joinedFiles = String.join(",", uniqueFiles);
            context.write(key, new Text(joinedFiles));
        }
    }

    public static void main(String[] args) throws Exception {
        Configuration conf = new Configuration();
        // parse custom flags passed via command line
        String[] otherArgs = new GenericOptionsParser(conf, args).getRemainingArgs();
        
        if (otherArgs.length != 2) {
            System.err.println("Usage: InvertedIndex <in> <out>");
            System.exit(2);
        }

        Job job = Job.getInstance(conf, "Native Java Inverted Index");
        job.setJarByClass(InvertedIndex.class);
        
        job.setMapperClass(IndexMapper.class);
        job.setReducerClass(IndexReducer.class);
        
        job.setOutputKeyClass(Text.class);
        job.setOutputValueClass(Text.class);
        
        FileInputFormat.addInputPath(job, new Path(otherArgs[0]));
        FileOutputFormat.setOutputPath(job, new Path(otherArgs[1]));
        
        System.exit(job.waitForCompletion(true) ? 0 : 1);
    }
}