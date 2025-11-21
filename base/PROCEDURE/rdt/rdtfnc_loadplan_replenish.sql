SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/************************************************************************/
/* Copyright: IDS                                                       */
/* Purpose: LoadPlan Replenishment From (Dynamic Pick)    				   */
/*                                                                      */
/* Modifications log:                                                   */
/*                                                                      */
/* Date       Rev  Author     Purposes                                  */
/* 2007-10-16 1.0  FKLIM      Created                                   */
/* 2008-08-07 1.1  James      Remove DropID                             */ 
/*                            When confirm then set DropID = 'Y'        */
/* 2016-09-30 1.2  Ung        Performance tuning                        */
/* 2018-11-01 1.3  TungGH     Performance                               */
/************************************************************************/

CREATE PROC [RDT].[rdtfnc_LoadPlan_Replenish] (
   @nMobile    int,
   @nErrNo     int  OUTPUT,
   @cErrMsg    NVARCHAR(1024) OUTPUT -- screen limitation, 20 char max
)
AS
SET NOCOUNT ON
SET QUOTED_IDENTIFIER OFF
SET ANSI_NULLS OFF
SET CONCAT_NULL_YIELDS_NULL OFF  

-- Misc variable
DECLARE 
   @cOption     NVARCHAR( 1),
   @nCount      INT,
   @nRowCount   INT

-- RDT.RDTMobRec variable
DECLARE 
   @nFunc      INT,
   @nScn       INT,
   @nStep      INT,
   @cLangCode  NVARCHAR( 3),
   @nInputKey  INT,
   @nMenu      INT,

   @cStorerKey NVARCHAR( 15),
   @cFacility  NVARCHAR( 5), 
   @cPrinter   NVARCHAR( 10),

   @b_success  INT,
   @n_err      INT,     
   @c_errmsg   NVARCHAR( 250), 

   @cReplenGroup  NVARCHAR( 10),
   @cUCC          NVARCHAR( 20),
	@cNewUCC       NVARCHAR( 20),
	@cScan         VARCHAR (5),
	@cSKU          NVARCHAR( 20),

   @cInField01 NVARCHAR( 60),   @cOutField01 NVARCHAR( 60),
   @cInField02 NVARCHAR( 60),   @cOutField02 NVARCHAR( 60),
   @cInField03 NVARCHAR( 60),   @cOutField03 NVARCHAR( 60),
   @cInField04 NVARCHAR( 60),   @cOutField04 NVARCHAR( 60),
   @cInField05 NVARCHAR( 60),   @cOutField05 NVARCHAR( 60),
   @cInField06 NVARCHAR( 60),   @cOutField06 NVARCHAR( 60), 
   @cInField07 NVARCHAR( 60),   @cOutField07 NVARCHAR( 60), 
   @cInField08 NVARCHAR( 60),   @cOutField08 NVARCHAR( 60), 
   @cInField09 NVARCHAR( 60),   @cOutField09 NVARCHAR( 60), 
   @cInField10 NVARCHAR( 60),   @cOutField10 NVARCHAR( 60), 
   @cInField11 NVARCHAR( 60),   @cOutField11 NVARCHAR( 60), 
   @cInField12 NVARCHAR( 60),   @cOutField12 NVARCHAR( 60), 
   @cInField13 NVARCHAR( 60),   @cOutField13 NVARCHAR( 60), 
   @cInField14 NVARCHAR( 60),   @cOutField14 NVARCHAR( 60), 
   @cInField15 NVARCHAR( 60),   @cOutField15 NVARCHAR( 60)

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
   @cPrinter   = Printer, 

   @cReplenGroup  = V_String1,
   @cUCC          = V_String2,
   
   @cScan         = V_Integer1,

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

IF @nFunc = 883  -- Data capture #3
BEGIN
   -- Redirect to respective screen
   IF @nStep = 0 GOTO Step_0   -- UCC Replenishment From (Dynamic Pick)
   IF @nStep = 1 GOTO Step_1   -- Scn = 1610. Replen Group
   IF @nStep = 2 GOTO Step_2   -- Scn = 1612. UCC, counter
END

--RETURN -- Do nothing if incorrect step

/********************************************************************************
Step 0. func = 883. Menu
********************************************************************************/
Step_0:
BEGIN
   -- Set the entry point
   SET @nScn = 1027
   SET @nStep = 1

   -- Initiate var
   SET @cReplenGroup = ''
   SET @cScan        = '0'

   -- Init screen
   SET @cOutField01 = '' -- Replen Group
END
GOTO Quit

/********************************************************************************
Step 1. Scn = 1027. Replen Group
   Replen Group      (field01, input)
********************************************************************************/
Step_1:
BEGIN
   IF @nInputKey = 1 --ENTER
   BEGIN
         --screen mapping
	   SET @cReplenGroup = @cInField01

      -- Validate blank
      IF @cReplenGroup = '' OR @cReplenGroup IS NULL
      BEGIN
         SET @nErrNo = 64351
         SET @cErrMsg = rdt.rdtgetmessage( 64351, @cLangCode,'DSP') --Need REPLENGRP
         GOTO Step_1_Fail
      END

      --validate replenGroup
      IF NOT EXISTS (SELECT 1 
         FROM IDSCN.dbo.Replenishment WITH (NOLOCK)
	      WHERE ReplenishmentGroup = @cReplenGroup
            AND StorerKey = @cStorerKey
	         AND Confirmed = 'Y')

      BEGIN
	     SET @nErrNo = 64352
        SET @cErrMsg = rdt.rdtgetmessage( 64352, @cLangCode,'DSP') --No replen task
        GOTO Step_1_Fail
	   END 

      -- Prepare next screen var
		SET @cScan = 0

      SET @cOutField01 = @cReplenGroup 
      SET @cOutField02 = ''--UCC 
		SET @cOutField03 = @cScan

      -- Go to next screen
      SET @nScn = @nScn + 1
      SET @nStep = @nStep + 1
   END

   IF @nInputKey = 0 --ESC
   BEGIN
      --go to main menu
      SET @nFunc = @nMenu
      SET @nScn  = @nMenu
      SET @nStep = 0
      SET @cOutField01 = ''
   END
   GOTO Quit

   Step_1_Fail:
   BEGIN
      SET @cReplenGroup = ''
      SET @cOutField01 = '' -- ReplenGroup
   END

END
GOTO Quit


/********************************************************************************
Step 2. Scn = 1028. Replen group, UCC
   REPLEN GROUP (field01)
   UCC          (field02, input)
********************************************************************************/
Step_2:
BEGIN
   IF @nInputKey = 1 -- Yes or Send
   BEGIN
      --screen mapping
      SET @cUCC = @cInField02
		SET @cNewUCC = ''

      IF @cUCC = '' OR @cUCC IS NULL
      BEGIN
         SET @nErrNo = 64353
         SET @cErrMsg = rdt.rdtgetmessage( 64353, @cLangCode,'DSP') --Need UCC
         GOTO Step_2_Fail  
      END

      SET @cSKU = ''
		SELECT @cSKU = SKU 
		FROM IDSCN.dbo.UCC WITH (NOLOCK) 
		WHERE UCCNo = @cUCC
			AND STATUS IN ('1', '3')

		IF ISNULL(@cSKU, '') <> ''
		BEGIN
			IF NOT EXISTS (SELECT 1 FROM IDSCN.dbo.REPLENISHMENT WITH (NOLOCK)
			WHERE ReplenishmentGroup = @cReplenGroup
				AND StorerKey = @cStorerKey
				AND Confirmed = 'Y'
				AND SKU = @cSKU)
			BEGIN
				SET @nErrNo = 64354
				SET @cErrMsg = rdt.rdtgetmessage( 64354, @cLangCode,'DSP') --NoUCCToSwap
				GOTO Step_2_Fail  
			END
		END		
		ELSE
		BEGIN
         SET @nErrNo = 64355
         SET @cErrMsg = rdt.rdtgetmessage( 64355, @cLangCode,'DSP') --Invalid UCC
         GOTO Step_2_Fail  
		END

      -- See whether user replenished the exact UCC
      SET @nCount = 0
      SELECT @nCount = COUNT(1)
      FROM IDSCN.dbo.Replenishment WITH (NOLOCK)
      WHERE ReplenishmentGroup = @cReplenGroup
         AND RefNo = @cUCC
         AND StorerKey = @cStorerKey
         AND Confirmed = 'Y'

      -- Swap UCC
      IF @nCount = 0
      BEGIN
         --check if storerConfig 'DynamicPickSwapUCC' turn on
        IF NOT EXISTS(SELECT 1
            FROM rdt.StorerConfig WITH (NOLOCK)
            WHERE StorerKey = @cStorerKey
           AND ConfigKey = 'DynamicPickSwapUCC'
               AND SValue = '1')
         BEGIN
            SET @nErrNo = 64356
            SET @cErrMsg = rdt.rdtgetmessage( 64356, @cLangCode,'DSP') --UCCNotOnReplen
            GOTO Step_2_Fail  
         END
         ELSE --if turn on, do the following
         BEGIN
            EXEC rdt.rdt_ReplenishFromSwapUCC 
               @nFunc        = @nFunc,
               @nMobile      = @nMobile,
               @cLangCode    = @cLangCode, 
               @nErrNo       = @nErrNo OUTPUT,
               @cErrMsg      = @cErrMsg OUTPUT, -- screen limitation, 20 char max
               @cUCC         = @cUCC,
               @cStorerKey   = @cStorerKey,
               @cReplenGroup = @cReplenGroup,
               @cNewUCC      = @cNewUCC OUTPUT

            IF @nErrNo <> 0
            BEGIN
               GOTO Step_2_Fail
            END
         END
      END-- end of IF @nCount = 0
		
      -- Update Replenishment
      UPDATE IDSCN.dbo.Replenishment WITH (ROWLOCK) SET
--         DropID = SUBSTRING(@cUCC, 3, LEN(@cUCC) - 2)
         DropID = 'Y'
      WHERE ReplenishmentGroup = @cReplenGroup
         AND RefNo = @cUCC
         AND StorerKey = @cStorerKey
         AND Confirmed = 'Y'

      IF @@ERROR <> 0 
      BEGIN
         SET @nErrNo = 64357
         SET @cErrMsg = rdt.rdtgetmessage( 64357, @cLangCode,'DSP') --Upd RPL fail
         ROLLBACK TRAN
         GOTO Step_2_Fail
      END

		-- Update UCC
		UPDATE IDSCN.dbo.UCC WITH (ROWLOCK) SET 
			Status = '6',
      EditDate = GETDATE(),
      EditWho = sUSER_sNAME()
		WHERE UCCNo = @cUCC
         AND StorerKey = @cStorerKey
-- 			AND Status = '3'

      IF @@ERROR <> 0 
      BEGIN
         SET @nErrNo = 64358
         SET @cErrMsg = rdt.rdtgetmessage( 64358, @cLangCode,'DSP') --Upd UCC fail
         ROLLBACK TRAN
         GOTO Step_2_Fail
      END

      -- Add one to counter
      SET @cScan = @cScan + 1
   
      -- Prepare next screen var
      SET @cUCC = ''
      SET @cOutField01 = @cReplenGroup 
      SET @cOutField02 = ''
      SET @cOutField03 = @cScan
   END

   IF @nInputKey = 0 -- ESC
   BEGIN
      -- Prepare prev screen var
      SET @cReplenGroup = ''
      SET @cOutField01 = '' -- Replen group

      -- Go to prev screen
      SET @nScn = @nScn - 1
      SET @nStep = @nStep - 1
   END
   GOTO Quit

   Step_2_Fail:
   BEGIN
      SET @cUCC = ''
      SET @cOutField02 = '' --UCC
   END

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
      Printer   = @cPrinter,    

      V_String1 = @cReplenGroup,
      V_String2 = @cUCC,
      
      V_Integer1 = @cScan, 

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
      I_Field11 = @cInField11, O_Field11 = @cOutField11, 
      I_Field12 = @cInField12,  O_Field12 = @cOutField12, 
      I_Field13 = @cInField13,  O_Field13 = @cOutField13, 
      I_Field14 = @cInField14,  O_Field14 = @cOutField14, 
      I_Field15 = @cInField15,  O_Field15 = @cOutField15

   WHERE Mobile = @nMobile
END

GO