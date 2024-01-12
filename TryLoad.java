
public class TryLoad {
    public static void main(String... args) { 
        for (String path : args) {
            try {
                System.err.printf("Trying %s ... ", path);
                System.load(path);
                System.out.println(path);
                System.err.printf("OK\n", path);
                return;
            } catch(UnsatisfiedLinkError ignore) {
                System.err.printf("FAIL\n", path);
            }
        }
    }
}
