#define serialDebugOut Serial

#include <Notecard.h>
#include <Wire.h>


#define ATTN_INPUT_PIN  5     // Any digital GPIO pin on your board

// #define serialNotecard Serial1

#define PRODUCT_ID "xx.xx.xx"
Notecard notecard;


int liveUpdateInterval = 30;  // every 30 seconds update live position
int normalUpdateInterval = 30; //every 30 mintues update current position
int liveMode = false;

#define INBOUND_QUEUE_NOTEFILE    "remote-command.qi"
#define INBOUND_QUEUE_COMMAND_FIELD "set-mode"

// Set to true whenever ATTN interrupt occurs
static bool attnInterruptOccurred;

// Forwards
void attnISR(void);
void attnArm();

void changeToLiveMode()
{
    J *req = notecard.newRequest("hub.set");
    JAddStringToObject(req, "product", PRODUCT_ID);
    JAddStringToObject(req, "mode", "periodic");
    JAddNumberToObject(req, "outbound", 10);
    JAddNumberToObject(req, "inbound", 1);
    notecard.sendRequest(req);

    
    req = notecard.newRequest("card.location.mode");
    JAddStringToObject(req, "mode", "periodic");
    JAddNumberToObject(req, "seconds", 60);
    notecard.sendRequest(req);
}

void changeToNormalMode()
{
    J *req = notecard.newRequest("hub.set");
    JAddStringToObject(req, "product", PRODUCT_ID);
    JAddStringToObject(req, "mode", "periodic");
    JAddNumberToObject(req, "outbound", 10);
    JAddNumberToObject(req, "inbound", 20);
    notecard.sendRequest(req);
    
    req = notecard.newRequest("card.location.mode");
    JAddStringToObject(req, "mode", "periodic");
    JAddNumberToObject(req, "seconds", 600);
    notecard.sendRequest(req);
}

void setup() {
  // put your setup code here, to run once:
#ifdef serialDebugOut
    delay(2500);
    serialDebugOut.begin(115200);
    notecard.setDebugOutputStream(serialDebugOut);
#endif

#ifdef serialNotecard
    notecard.begin(serialNotecard, 9600);
#else
    Wire.begin();
    notecard.begin();
#endif

    delay(10000);


    J *req = notecard.newRequest("hub.set");
    JAddStringToObject(req, "product", PRODUCT_ID);
    JAddStringToObject(req, "mode", "periodic");
    JAddNumberToObject(req, "outbound", 10);
    JAddNumberToObject(req, "inbound", 30);
    notecard.sendRequest(req);


    req = notecard.newRequest("card.attn");
    JAddStringToObject(req, "mode", "disarm,-files");
    notecard.sendRequest(req);

    req = notecard.newRequest("card.attn");
    const char *filesToWatch[] = {INBOUND_QUEUE_NOTEFILE};
    int numFilesToWatch = sizeof(filesToWatch) / sizeof(const char *);
    J *filesArray = JCreateStringArray(filesToWatch, numFilesToWatch);
    JAddItemToObject(req, "files", filesArray);
    JAddStringToObject(req, "mode", "files");
    notecard.sendRequest(req);

    pinMode(ATTN_INPUT_PIN, INPUT);
    attachInterrupt(digitalPinToInterrupt(ATTN_INPUT_PIN), attnISR, RISING);
    
    attnArm();

    changeToNormalMode();
}



void attnArm()
{

    // Make sure that we pick up the next RISING edge of the interrupt
    attnInterruptOccurred = false;

    // Set the ATTN pin low, and wait for the earlier of file modification or a timeout
    J *req = notecard.newRequest("card.attn");
    JAddStringToObject(req, "mode", "reset");
    JAddNumberToObject(req, "seconds", 120);
    notecard.sendRequest(req);

}

// Interrupt Service Routine for ATTN_INPUT_PIN transitions rising from LOW to HIGH
void attnISR()
{
    attnInterruptOccurred = true;
}

void loop() {
  // put your main code here, to run repeatedly:

      if (!attnInterruptOccurred) {
        return;
    }

    attnArm();
        // Process all pending inbound requests
    while (true) {

        // Get the next available note from our inbound queue notefile, deleting it
        J *req = notecard.newRequest("note.get");
        JAddStringToObject(req, "file", INBOUND_QUEUE_NOTEFILE);
        JAddBoolToObject(req, "delete", true);
        J *rsp = notecard.requestAndResponse(req);
        if (rsp != NULL) {

            // If an error is returned, this means that no response is pending.  Note
            // that it's expected that this might return either a "note does not exist"
            // error if there are no pending inbound notes, or a "file does not exist" error
            // if the inbound queue hasn't yet been created on the service.
            if (notecard.responseError(rsp)) {
                notecard.deleteResponse(rsp);
                break;
            }

            // Get the note's body
            J *body = JGetObject(rsp, "body");
            if (body != NULL) {

                // Simulate Processing the response here
                char *myCommandType = JGetString(body, INBOUND_QUEUE_COMMAND_FIELD);
                notecard.logDebugf("INBOUND REQUEST: %s\n\n", myCommandType);

                char cmp_val[] = "LIVE";

                if (strcmp(myCommandType,cmp_val) == 0)
                {
                    notecard.logDebugf("Change to LIVE MODE");
                    if (liveMode == false)
                    {
                      liveMode = true;
                      changeToLiveMode();
                    }
                }
                else
                {
                    notecard.logDebugf("Change to Normal MODE");
                    if (liveMode == true)
                    {
                      liveMode = false;
                      changeToNormalMode();
                    }
                    
                }
            }

        }
        notecard.deleteResponse(rsp);
    }
  
}
