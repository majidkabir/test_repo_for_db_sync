SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO



/************************************************************************/
/* Store procedure: rdtfnc_PostPackAudit_CloseTrip                      */
/* Copyright      : IDS                                                 */
/*                                                                      */
/* Purpose: SOS#68199 - To generate unique trip numberupon close trip   */
/*                                                                      */
/* Called from: 3                                                       */
/*    1. From PowerBuilder                                              */
/*    2. From scheduler                                                 */
/*    3. From others stored procedures or triggers                      */
/*    4. From interface program. DX, DTS                                */
/*                                                                      */
/* Exceed version: 5.4                                                  */
/*                                                                      */
/* Modifications log:                                                   */
/*                                                                      */
/* Date       Rev  Author   Purposes                                    */
/* 2007-03-01 1.0  Vicky    Created                                     */
/* 2007-04-09 1.1  Vicky    Add Trafficcop = NULL When Update table     */
/* 2007-04-20 1.2  James    Insert a record to transmitlog2 upon close  */
/*                          close trip                                  */
/* 2016-09-30 1.3  Ung      Performance tuning                          */
/* 2018-11-09 1.4  Gan      Performance tuning                          */
/************************************************************************/

CREATE  PROCEDURE [RDT].[rdtfnc_PostPackAudit_CloseTrip] (
   @nMobile    INT,
   @nErrNo     INT  OUTPUT,
   @cErrMsg    NVARCHAR( 20) OUTPUT -- screen limitation, 20 char max
) AS
   SET NOCOUNT ON   
   SET QUOTED_IDENTIFIER OFF   
   SET ANSI_NULLS OFF  
   SET CONCAT_NULL_YIELDS_NULL OFF

-- Misc variable
DECLARE 
   @i           INT

-- RDT.RDTMobRec variable
DECLARE 
   @nFunc      INT,
   @nScn       INT,
   @nStep      INT,
   @cLangCode  NVARCHAR(3),
   @nInputKey  INT,
   @nMenu      INT,

   @cStorerKey NVARCHAR(15),
   @cFacility  NVARCHAR(5), 

   @cVehicle   NVARCHAR(20), 
   @cRefNo1    NVARCHAR(20), 
   @cRefNo2    NVARCHAR(20), 
   @cRefNo3    NVARCHAR(20), 
   @cRefNo4    NVARCHAR(20), 
   @cRefNo5    NVARCHAR(20), 
   @cStatus    NVARCHAR(1),
   @cOption    NVARCHAR(1),

   @nRefNoCnt  INT,
   @nStatusCnt INT,
   @nMinRowRef INT,
   
   @cInField01 NVARCHAR(60),   @cOutField01 NVARCHAR(60),
   @cInField02 NVARCHAR(60),   @cOutField02 NVARCHAR(60),
   @cInField03 NVARCHAR(60),   @cOutField03 NVARCHAR(60),
   @cInField04 NVARCHAR(60),   @cOutField04 NVARCHAR(60),
   @cInField05 NVARCHAR(60),   @cOutField05 NVARCHAR(60),
   @cInField06 NVARCHAR(60),   @cOutField06 NVARCHAR(60), 
   @cInField07 NVARCHAR(60),   @cOutField07 NVARCHAR(60), 
   @cInField08 NVARCHAR(60),   @cOutField08 NVARCHAR(60), 
   @cInField09 NVARCHAR(60),   @cOutField09 NVARCHAR(60), 
   @cInField10 NVARCHAR(60),   @cOutField10 NVARCHAR(60), 
   @cInField11 NVARCHAR(60),   @cOutField11 NVARCHAR(60), 
   @cInField12 NVARCHAR(60),   @cOutField12 NVARCHAR(60), 
   @cInField13 NVARCHAR(60),   @cOutField13 NVARCHAR(60), 
   @cInField14 NVARCHAR(60),   @cOutField14 NVARCHAR(60), 
   @cInField15 NVARCHAR(60),   @cOutField15 NVARCHAR(60)

-- Load RDT.RDTMobRec
SELECT 
   @nFunc      = Func,
   @nScn       = Scn,
   @nStep      = Step,
   @nInputKey  = InputKey,
   @nMenu      = Menu,
   @cLangCode  = Lang_code,

   @cStorerKey = StorerKey,
   @cFacility  = Facility,

   @cVehicle  = V_String1, 
   @cRefNo1   = V_String2, 
   @cRefNo2   = V_String3, 
   @cRefNo3   = V_String4, 
   @cRefNo4   = V_String5, 
   @cRefNo5   = V_String6, 
   @cStatus   = V_String7,
   @cOption   = V_String8,

   @cInField01 = I_Field01,   @cOutField01 = O_Field01,
   @cInField02 = I_Field02,   @cOutField02 = O_Field02,
   @cInField03 = I_Field03,   @cOutField03 = O_Field03, 
   @cInField04 = I_Field04,   @cOutField04 = O_Field04, 
   @cInField05 = I_Field05,   @cOutField05 = O_Field05, 
   @cInField06 = I_Field06,   @cOutField06 = O_Field06, 
   @cInField07 = I_Field07,   @cOutField07 = O_Field07, 
   @cInField08 = I_Field08,   @cOutField08 = O_Field08, 
   @cInField09 = I_Field09,   @cOutField09 = O_Field09, 
   @cInField10 = I_Field10,   @cOutField10 = O_Field10, 
   @cInField11 = I_Field11,   @cOutField11 = O_Field11, 
   @cInField12 = I_Field12,   @cOutField12 = O_Field12, 
   @cInField13 = I_Field13,   @cOutField13 = O_Field13, 
   @cInField14 = I_Field14,   @cOutField14 = O_Field14, 
   @cInField15 = I_Field15,   @cOutField15 = O_Field15

FROM RDTMOBREC (NOLOCK)
WHERE Mobile = @nMobile

IF @nFunc = 891 -- CloseTrip
BEGIN
   -- Redirect to respective screen
   IF @nStep = 0 GOTO Step_0   -- Func = CloseTrip
   IF @nStep = 1 GOTO Step_1   -- Scn = 1200. Vehicle No, Ref No
   IF @nStep = 2 GOTO Step_2   -- Scn = 1201. Option
   IF @nStep = 3 GOTO Step_3   -- Scn = 1202. Message
END

RETURN -- Do nothing if incorrect step


/********************************************************************************
Step 0. func = 891. Menu
********************************************************************************/
Step_0:
BEGIN
   -- Set the entry point
   SET @nScn = 1200
   SET @nStep = 1

   -- Initiate var
   SET @cVehicle = ''
   SET @cRefNo1 = ''
   SET @cRefNo2 = ''
   SET @cRefNo3 = ''
   SET @cRefNo4 = ''
   SET @cRefNo5 = ''
   SET @cStatus = ''

   -- Init screen
   SET @cOutField01 = ''
   SET @cOutField02 = ''
   SET @cOutField03 = ''
   SET @cOutField04 = ''
   SET @cOutField05 = ''
   SET @cOutField06 = ''
END
GOTO Quit


/********************************************************************************
Step 1. Scn = 1200. Vehicle screen
   Vehicle (field01)
   RefNo1  (field02)
   RefNo2  (field03)
   RefNo3  (field04)
   RefNo4  (field05)
   RefNo5  (field06)
********************************************************************************/
Step_1:
BEGIN
   IF @nInputKey = 1 -- Yes or Send
   BEGIN
      -- Validate if anything changed or initial blank
      IF (@cVehicle <> @cInField01 OR
         @cRefNo1 <> @cInField02 OR
         @cRefNo2 <> @cInField03 OR
         @cRefNo3 <> @cInField04 OR
         @cRefNo4 <> @cInField05 OR
         @cRefNo5 <> @cInField06) OR
         @cInField01 = ''
      -- There are changes, remain in current screen
      BEGIN
         -- Set next field focus
         SET @i = 2 -- start from 2nd field
         IF @cInField02 <> '' SET @i = @i + 1
         IF @cInField03 <> '' SET @i = @i + 1
         IF @cInField04 <> '' SET @i = @i + 1
         IF @cInField05 <> '' SET @i = @i + 1
         IF @cInField06 <> '' SET @i = @i + 1
         IF @i > 6 SET @i = 2
         EXEC rdt.rdtSetFocusField @nMobile, @i
         
         -- Screen mapping
         SET @cVehicle = @cInField01
         SET @cRefNo1 = @cInField02
         SET @cRefNo2 = @cInField03
         SET @cRefNo3 = @cInField04
         SET @cRefNo4 = @cInField05
         SET @cRefNo5 = @cInField06

         -- Validate blank
         IF @cVehicle = '' OR @cVehicle IS NULL
         BEGIN
            SET @nErrNo = 62922
            SET @cErrMsg = rdt.rdtgetmessage( 62922, @cLangCode, 'DSP') --'Vehicle No Req'
            EXEC rdt.rdtSetFocusField @nMobile, 1
            GOTO Step_1_Fail
         END

         -- Retain key-in value
         SET @cOutField01 = @cVehicle
         SET @cOutField02 = @cInField02
         SET @cOutField03 = @cInField03
         SET @cOutField04 = @cInField04
         SET @cOutField05 = @cInField05
         SET @cOutField06 = @cInField06

         

         -- Remain in current screen
--           SET @nScn = @nScn + 1
--           SET @nStep = @nStep + 1
      END
      ELSE
      BEGIN
         SELECT @nRefNoCnt = COUNT(RowRef)
         FROM rdt.RDTCSAudit_Load (NOLOCK) 
         WHERE Vehicle = @cVehicle
          AND RefNo1 = @cRefNo1
          AND RefNo2 = @cRefNo2
          AND RefNo3 = @cRefNo3
          AND RefNo4 = @cRefNo4
          AND RefNo5 = @cRefNo5
          AND Storerkey = @cStorerKey

         IF @nRefNoCnt = 0
         BEGIN
            SET @nErrNo = 62923
            SET @cErrMsg = rdt.rdtgetmessage( 62923, @cLangCode, 'DSP') --'Invalid Trip'
            EXEC rdt.rdtSetFocusField @nMobile, 1
            GOTO Step_1_Fail
         END  

         SELECT @nStatusCnt = COUNT(RowRef)
         FROM rdt.RDTCSAudit_Load (NOLOCK) 
         WHERE Vehicle = @cVehicle
          AND RefNo1 = @cRefNo1
          AND RefNo2 = @cRefNo2
          AND RefNo3 = @cRefNo3
          AND RefNo4 = @cRefNo4
          AND RefNo5 = @cRefNo5
          AND Storerkey = @cStorerKey
          AND Status = '5'

         IF @nStatusCnt = 0
         BEGIN
            SET @nErrNo = 62924
            SET @cErrMsg = rdt.rdtgetmessage( 62924, @cLangCode, 'DSP') --'Trip closed'
            EXEC rdt.rdtSetFocusField @nMobile, 1
            GOTO Step_1_Fail
         END 
         -- Prep next screen var
         SET @cOutField01 = ''
         EXEC rdt.rdtSetFocusField @nMobile, 2

         -- Go to next screen
         SET @nScn = @nScn + 1
         SET @nStep = @nStep + 1
      END
   END

   IF @nInputKey = 0 -- Esc or No
   BEGIN
      -- Back to menu
      SET @nFunc = @nMenu
      SET @nScn  = @nMenu
      SET @nStep = 0
      SET @cOutField01 = ''
   END
   GOTO Quit

   Step_1_Fail:
   BEGIN
      -- Reset this screen var
      SET @cOutField01 = @cVehicle
      SET @cOutField02 = @cRefNo1
      SET @cOutField03 = @cRefNo2
      SET @cOutField04 = @cRefNo3
      SET @cOutField05 = @cRefNo4
      SET @cOutField06 = @cRefNo5
   END
END
GOTO Quit


/********************************************************************************
Step 2. scn = 1201. Option screen
   Option   (field01)
********************************************************************************/
Step_2:
BEGIN
   IF @nInputKey = 1 -- Yes or Send
   BEGIN
	   SET @cOption = ''
	   SET @cOption = @cInField01

      IF @cOption <> '1' AND @cOption <> '2'
      BEGIN
         SET @nErrNo = 62925
	      SET @cErrMsg = rdt.rdtgetmessage( 62925, @cLangCode, 'DSP') --'Invalid Option'
	      GOTO Step_2_Fail
      END
     
      IF @cOption = '1' -- Update
      BEGIN

        SELECT @nMinRowRef = MIN(RowRef)
	     FROM rdt.RDTCSAudit_Load (NOLOCK) 
	     WHERE Vehicle = @cVehicle
	       AND RefNo1 = @cRefNo1
	       AND RefNo2 = @cRefNo2
	       AND RefNo3 = @cRefNo3
	       AND RefNo4 = @cRefNo4
	       AND RefNo5 = @cRefNo5
          AND Storerkey = @cStorerKey
	       AND Status = '5'

        IF @nMinRowRef > 0 
        BEGIN
           UPDATE rdt.RDTCSAudit_Load WITH (ROWLOCK)
              SET Status = '9',
                  TripID = @nMinRowRef,
                  CloseWho = user_name(),
                  CloseDate = Getdate(),
                  Trafficcop = NULL -- 2007-04-10
		     WHERE Vehicle = @cVehicle
		       AND RefNo1 = @cRefNo1
		       AND RefNo2 = @cRefNo2
		       AND RefNo3 = @cRefNo3
		       AND RefNo4 = @cRefNo4
		       AND RefNo5 = @cRefNo5
             AND Storerkey = @cStorerKey
		       AND Status = '5'

			 IF @@ERROR <> 0
	       BEGIN
		         SET @nErrNo = 62926
		         SET @cErrMsg = rdt.rdtgetmessage( 62926, @cLangCode, 'DSP') --'Fail to UPD'
		         GOTO Step_2_Fail
	       END
	       
	       --sos72938 insert a record into transmitlog2 upon successfully close trip -start
			DECLARE @c_WTSITF NVARCHAR( 1)
			DECLARE @n_err INT, @b_success INT
			
         SELECT @b_success = 0
         Execute dbo.nspGetRight 
         	null,	
            @cStorerKey, 	
            null,				
            'WTS-ITF',	
            @b_success		output,
            @c_WTSITF 	   output,
            @n_err			output,
            @cErrMsg		output

	      IF @b_success <> 1
	      BEGIN
	         SET @nErrNo = 63001
	         SET @cErrMsg = rdt.rdtgetmessage( 63001, @cLangCode, 'DSP') --'nspGetRight'
	         GOTO Step_2_Fail
	      END

         IF (@c_WTSITF = '1' AND @b_success = 1 )
         BEGIN
            EXEC dbo.ispGenTransmitLog2 
              'WTS-TO' 
            , @nMinRowRef 
            , '' 
            , @cStorerKey 
            , ''
            , @b_success OUTPUT
            , @n_err OUTPUT
            , @cErrMsg OUTPUT
            
            IF @b_success <> 1
            BEGIN
	         SET @nErrNo = 63002
	         SET @cErrMsg = rdt.rdtgetmessage( 63002, @cLangCode, 'DSP') --'GenTransL2Err'
	         GOTO Step_2_Fail
            END				
			END   
	       --sos72938 insert a record into transmitlog2 upon successfully close trip -end
       END
      END -- Option = 1

      IF @cOption = '2' -- Back
      BEGIN
	      SET @cInField01 = ''
         SET @cOutField01 = @cVehicle
         SET @cOutField02 = @cRefNo1
         SET @cOutField03 = @cRefNo2
         SET @cOutField04 = @cRefNo3
         SET @cOutField05 = @cRefNo4
         SET @cOutField06 = @cRefNo5
         EXEC rdt.rdtSetFocusField @nMobile, 1

         SET @nScn = @nScn - 1
         SET @nStep = @nStep - 1
         GOTO Quit
      END

      -- Prepare next screen var
      SET @cOutField01 = ''
      SET @cOutField02 = ''
      SET @cOutField03 = '' 
      SET @cOutField04 = ''
      SET @cOutField05 = ''
      SET @cOutField06 = ''

      -- Go to next screen
      SET @nScn = @nScn + 1
      SET @nStep = @nStep + 1
   END

   IF @nInputKey = 0 -- Esc or No
   BEGIN
      -- Prepare prev screen var
--       SET @cVehicle = ''
--       SET @cRefNo1  = ''
--       SET @cRefNo2  = ''
--       SET @cRefNo3  = ''
--       SET @cRefNo4  = ''
--       SET @cRefNo5  = ''
-- 
--       SET @cOutField01 = ''
--       SET @cOutField02 = ''
--       SET @cOutField03 = ''
--       SET @cOutField04 = ''
--       SET @cOutField05 = ''
--       SET @cOutField06 = ''
--       SET @cOutField07 = ''
--       SET @cOutField08 = ''
--       SET @cOutField09 = ''
-- 
--       SET @cInField01 = ''
--       SET @cInField02 = ''
--       SET @cInField03 = ''
--       SET @cInField04 = ''
--       SET @cInField05 = ''
--       SET @cInField06 = ''
--       SET @cInField07 = ''
--       SET @cInField08 = ''
--       SET @cInField09 = ''

      SET @cInField01 = ''
      SET @cOutField01 = @cVehicle
      SET @cOutField02 = @cRefNo1
      SET @cOutField03 = @cRefNo2
      SET @cOutField04 = @cRefNo3
      SET @cOutField05 = @cRefNo4
      SET @cOutField06 = @cRefNo5
      
      SET @cOption = ''


      EXEC rdt.rdtSetFocusField @nMobile, 1

      -- Go to prev screen
      SET @nScn = @nScn - 1
      SET @nStep = @nStep - 1
   END
   GOTO Quit

   Step_2_Fail:
END
GOTO Quit


/********************************************************************************
Step 3. scn = 1202. Message screen
********************************************************************************/
Step_3:
BEGIN
   IF @nInputKey = 1 
   BEGIN
	      SET @cOutField01 = ''
	      SET @cOutField02 = ''
	      SET @cOutField03 = ''
	      SET @cOutField04 = ''
	      SET @cOutField05 = ''
	      SET @cOutField06 = ''
	      SET @cOutField07 = ''
	      SET @cOutField08 = ''
	      SET @cOutField09 = ''

         SET @cInField01 = ''
         SET @cInField02 = ''
         SET @cInField03 = ''
         SET @cInField04 = ''
         SET @cInField05 = ''
         SET @cInField06 = ''
         SET @cInField07 = ''
         SET @cInField08 = ''
         SET @cInField09 = ''
         
	      SET @cOption = ''

         EXEC rdt.rdtSetFocusField @nMobile, 1

	      SET @nScn  = @nScn - 2
	      SET @nStep = @nStep - 2
    END

   IF @nInputKey = 0 -- Esc or No
   BEGIN
	      SET @cOutField01 = ''
	      SET @cOutField02 = ''
	      SET @cOutField03 = ''
	      SET @cOutField04 = ''
	      SET @cOutField05 = ''
	      SET @cOutField06 = ''
	      SET @cOutField07 = ''
	      SET @cOutField08 = ''
	      SET @cOutField09 = ''

         SET @cInField01 = ''
         SET @cInField02 = ''
         SET @cInField03 = ''
         SET @cInField04 = ''
         SET @cInField05 = ''
         SET @cInField06 = ''
         SET @cInField07 = ''
         SET @cInField08 = ''
         SET @cInField09 = ''
         
	      SET @cOption = ''
         EXEC rdt.rdtSetFocusField @nMobile, 1

	      SET @nScn  = @nScn - 2
	      SET @nStep = @nStep - 2
   END
   GOTO Quit

   Step_3_Fail:
END
GOTO Quit


/********************************************************************************
Quit. Update back to I/O table, ready to be pick up by JBOSS
********************************************************************************/
Quit:
BEGIN
   UPDATE RDTMOBREC WITH (ROWLOCK) SET 
      EditDate = GETDATE(), 
      ErrMsg = @cErrMsg, 
      Func   = @nFunc,
      Step   = @nStep,
      Scn    = @nScn,

      StorerKey = @cStorerKey,
      Facility  = @cFacility, 

      V_String1 = @cVehicle, 
      V_String2 = @cRefNo1, 
      V_String3 = @cRefNo2, 
      V_String4 = @cRefNo3, 
      V_String5 = @cRefNo4, 
      V_String6 = @cRefNo5, 
      V_String7 = @cStatus, 
      V_String8 = @cOption,

      I_Field01 = @cInField01,  O_Field01 = @cOutField01, 
      I_Field02 = @cInField02,  O_Field02 = @cOutField02, 
      I_Field03 = @cInField03,  O_Field03 = @cOutField03, 
      I_Field04 = @cInField04,  O_Field04 = @cOutField04, 
      I_Field05 = @cInField05,  O_Field05 = @cOutField05, 
      I_Field06 = @cInField06,  O_Field06 = @cOutField06, 
      I_Field07 = @cInField07,  O_Field07 = @cOutField07, 
      I_Field08 = @cInField08,  O_Field08 = @cOutField08, 
      I_Field09 = @cInField09,  O_Field09 = @cOutField09, 
      I_Field10 = @cInField10,  O_Field10 = @cOutField10, 
      I_Field11 = @cInField11,  O_Field11 = @cOutField11, 
      I_Field12 = @cInField12,  O_Field12 = @cOutField12, 
      I_Field13 = @cInField13,  O_Field13 = @cOutField13, 
      I_Field14 = @cInField14,  O_Field14 = @cOutField14, 
      I_Field15 = @cInField15,  O_Field15 = @cOutField15

   WHERE Mobile = @nMobile
END


GO