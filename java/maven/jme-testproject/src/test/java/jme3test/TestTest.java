package jme3test;

import com.jme3.app.SimpleApplication;
import jme3test.bullet.TestLocalPhysics;
import jme3test.terrain.TerrainTest;
import org.junit.Test;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;

import java.util.Timer;
import java.util.TimerTask;

public class TestTest {

    private static final Logger LOG = LoggerFactory.getLogger(TestTest.class);

    @Test
    public void testTestLocalPhysics() {
        runApp(new TestLocalPhysics(),4 );
    }
    
    @Test
    public void testTerrainTest() {
        runApp(new TerrainTest(), 4);
    }

    public void runApp(final SimpleApplication app, int secs) {
        app.setShowSettings(false);

        Timer timer = new Timer();
        timer.schedule(new TimerTask() {
            @Override
            public void run() {
                app.stop(true);
            }
        }, 5 * 1000);

        app.start(false);
    }
}
