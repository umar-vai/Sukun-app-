import java.awt.Color;
import java.awt.Graphics2D;
import java.awt.RenderingHints;
import java.awt.image.BufferedImage;
import java.nio.file.Files;
import java.nio.file.Path;
import java.util.Map;
import javax.imageio.ImageIO;

/** Makes platform icons from the client-supplied, unmodified Sukun Life logo. */
public final class GenerateSukunIcons {
    private static final Color BACKGROUND = new Color(0x0D, 0x2B, 0x45);
    private static final Map<String, Integer> ANDROID = Map.of(
        "mdpi", 48, "hdpi", 72, "xhdpi", 96, "xxhdpi", 144, "xxxhdpi", 192);

    private GenerateSukunIcons() {}

    public static void main(String[] args) throws Exception {
        if (args.length != 2 || (!args[0].equals("--web") && !args[0].equals("--android"))) {
            throw new IllegalArgumentException(
                "Usage: java GenerateSukunIcons.java --web|--android APP_ROOT");
        }
        Path appRoot = Path.of(args[1]).toAbsolutePath().normalize();
        Path official = appRoot.resolve("assets/brand/sukunlife_logo.png");
        if (!Files.isRegularFile(official)) {
            throw new IllegalStateException("Approved Sukun logo is missing: " + official);
        }
        BufferedImage image = ImageIO.read(official.toFile());
        if (image == null || image.getWidth() < 512 || image.getHeight() < 512) {
            throw new IllegalStateException("Official logo must be a readable high-resolution PNG.");
        }
        if (args[0].equals("--web")) {
            write(image, appRoot.resolve("web/favicon.png"), 48, .94, false);
            write(image, appRoot.resolve("web/icons/Icon-192.png"), 192, .88, false);
            write(image, appRoot.resolve("web/icons/Icon-512.png"), 512, .88, false);
            write(image, appRoot.resolve("web/icons/Icon-maskable-512.png"), 512, .65, false);
            write(image, appRoot.resolve("web/icons/apple-touch-icon.png"), 180, .85, false);
        } else {
            for (var entry : ANDROID.entrySet()) {
                Path folder = appRoot.resolve("android/app/src/main/res/mipmap-" + entry.getKey());
                int size = entry.getValue();
                write(image, folder.resolve("ic_launcher.png"), size, .86, false);
                // Adaptive foreground fits the circular mask's central safe zone.
                write(image, folder.resolve("ic_launcher_foreground.png"),
                    (int) Math.round(size * 2.25), .62, true);
            }
        }
        System.out.println("Generated official Sukun Life " + args[0].substring(2)
            + " icons; original unchanged: " + official);
    }

    private static void write(BufferedImage logo, Path output, int size,
                              double contentFraction, boolean transparentBackground) throws Exception {
        Files.createDirectories(output.getParent());
        BufferedImage canvas = new BufferedImage(size, size, BufferedImage.TYPE_INT_ARGB);
        Graphics2D graphics = canvas.createGraphics();
        try {
            graphics.setRenderingHint(RenderingHints.KEY_INTERPOLATION,
                RenderingHints.VALUE_INTERPOLATION_BICUBIC);
            graphics.setRenderingHint(RenderingHints.KEY_RENDERING,
                RenderingHints.VALUE_RENDER_QUALITY);
            if (!transparentBackground) {
                graphics.setColor(BACKGROUND);
                graphics.fillRect(0, 0, size, size);
            }
            // Contain the complete supplied logo: no cropping, recoloring or stretching.
            double scale = Math.min((size * contentFraction) / logo.getWidth(),
                (size * contentFraction) / logo.getHeight());
            int width = Math.max(1, (int) Math.round(logo.getWidth() * scale));
            int height = Math.max(1, (int) Math.round(logo.getHeight() * scale));
            graphics.drawImage(logo, (size - width) / 2, (size - height) / 2,
                width, height, null);
        } finally {
            graphics.dispose();
        }
        if (!ImageIO.write(canvas, "png", output.toFile())) {
            throw new IllegalStateException("Could not write PNG " + output);
        }
    }
}
