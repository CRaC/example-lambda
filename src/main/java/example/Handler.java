package example;

import com.amazonaws.services.lambda.runtime.Context;
import com.amazonaws.services.lambda.runtime.RequestHandler;
import com.amazonaws.services.lambda.runtime.events.SQSEvent;
import com.amazonaws.services.lambda.runtime.events.SQSEvent.SQSMessage;
import org.crac.CheckpointException;
import org.crac.RestoreException;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;

// Handler value: io.github.crac.example.lambda.Handler
public class Handler implements RequestHandler<SQSEvent, String>{
  private static final Logger logger = LoggerFactory.getLogger(Handler.class);

  public Handler(){
  }

  @Override
  public String handleRequest(SQSEvent event, Context context)
  {
    logger.info("handleRequest start");

    // process event
    String response = "";

    for (SQSMessage msg : event.getRecords()) {
      logger.info(msg.getBody());
      response = msg.getBody();

      switch (msg.getBody()) {
        case "checkpoint":
          (new Thread(() -> {
            try {
              Thread.sleep(1_000);
              org.crac.Core.checkpointRestore();
            } catch (CheckpointException | RestoreException | InterruptedException e) {
              e.printStackTrace();
            }
          })).start();
          break;
        default:
          // Just echo. Will also be used to break out of curl waiting for connection.
          break;
      }
    }

    return response;
  }
}
