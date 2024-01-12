
public class TryLoad {
    public static void main(String... args) { 
        for (String path : args) {
            System.err.printf("Trying %s ... ", path);
            try {
                System.load(path);
                System.err.println("OK");
                System.out.println(path);
                break;
            } catch (UnsatisfiedLinkError ignore) {
                System.err.println("FAIL");
            }
        }
    }
}
