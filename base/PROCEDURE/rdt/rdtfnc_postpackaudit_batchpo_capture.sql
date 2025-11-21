SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO


/*****************************************************************************/
/* Store procedure: rdtfnc_PostPackAudit_BatchPO_Capture                     */
/* Copyright      : IDS                                                      */
/*                                                                           */
/* Purpose: Batch PO Capture - SOS#137535                                    */
/*                                                                           */
/* Modifications log:                                                        */
/*                                                                           */
/* Date       Rev  Author   Purposes                                         */
/* 2009-05-27 1.0  Vicky    Created                                          */
/* 2016-09-30 1.1  Ung      Performance tuning                               */
/* 2018-11-09 1.2  Gan      Performance tuning                               */
/*****************************************************************************/
CREATE PROC [RDT].[rdtfnc_PostPackAudit_BatchPO_Capture](
   @nMobile    INT,
   @nErrNo     INT  OUTPUT,
   @cErrMsg    NVARCHAR(1024) OUTPUT -- screen limitation, 20 char max
) AS
   SET NOCOUNT ON   
   SET QUOTED_IDENTIFIER OFF   
   SET ANSI_NULLS OFF  
   SET CONCAT_NULL_YIELDS_NULL OFF
-- Misc variable
DECLARE
   @b_success           INT

  
-- Define a variable
DECLARE  
   @nFunc               INT,
   @nScn                INT,
   @nStep               INT,
   @cLangCode           NVARCHAR(3),
   @nMenu               INT,
   @nInputKey           NVARCHAR(3),

   @cStorerKey          NVARCHAR(15),
   @cFacility           NVARCHAR(5),

   @cPrinter            NVARCHAR(10),
   @cUserName           NVARCHAR(18),

   @cOrderKey           NVARCHAR(10),
   @cExternPOKey        NVARCHAR(15),
   @cBatch              NVARCHAR(15),  
   @cDefaultOption      NVARCHAR(1),
   @cOption             NVARCHAR(1),

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
   @cInField15 NVARCHAR( 60),   @cOutField15 NVARCHAR( 60),

   @cFieldAttr01 NVARCHAR( 1), @cFieldAttr02 NVARCHAR( 1),
   @cFieldAttr03 NVARCHAR( 1), @cFieldAttr04 NVARCHAR( 1),
   @cFieldAttr05 NVARCHAR( 1), @cFieldAttr06 NVARCHAR( 1),
   @cFieldAttr07 NVARCHAR( 1), @cFieldAttr08 NVARCHAR( 1),
   @cFieldAttr09 NVARCHAR( 1), @cFieldAttr10 NVARCHAR( 1),
   @cFieldAttr11 NVARCHAR( 1), @cFieldAttr12 NVARCHAR( 1),
   @cFieldAttr13 NVARCHAR( 1), @cFieldAttr14 NVARCHAR( 1),
   @cFieldAttr15 NVARCHAR( 1)
            
-- Getting Mobile information
SELECT 
   @nFunc            = Func,
   @nScn             = Scn,
   @nStep            = Step,
   @nInputKey        = InputKey,
   @cLangCode        = Lang_code,
   @nMenu            = Menu,

   @cFacility        = Facility,
   @cStorerKey       = StorerKey,
   @cPrinter         = Printer, 
   @cUserName        = UserName,

   @cOrderKey        = V_OrderKey,
   @cExternPOKey     = V_String1,
   @cBatch           = V_String2,
   @cDefaultOption   = V_String3,  
   @cOption          = V_String4,  

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
   @cInField15 = I_Field15,   @cOutField15 = O_Field15,

   @cFieldAttr01  = FieldAttr01,    @cFieldAttr02   = FieldAttr02,
   @cFieldAttr03 =  FieldAttr03,    @cFieldAttr04   = FieldAttr04,
   @cFieldAttr05 =  FieldAttr05,    @cFieldAttr06   = FieldAttr06,
   @cFieldAttr07 =  FieldAttr07,    @cFieldAttr08   = FieldAttr08,
   @cFieldAttr09 =  FieldAttr09,    @cFieldAttr10   = FieldAttr10,
   @cFieldAttr11 =  FieldAttr11,    @cFieldAttr12   = FieldAttr12,
   @cFieldAttr13 =  FieldAttr13,    @cFieldAttr14   = FieldAttr14,
   @cFieldAttr15 =  FieldAttr15

FROM   RDTMOBREC (NOLOCK)
WHERE  Mobile = @nMobile

-- Redirect to respective screen
IF @nFunc = 893 -- Batch PO Capture
BEGIN
   IF @nStep = 0 GOTO Step_0   -- Menu. Func = 893
   IF @nStep = 1 GOTO Step_1   -- Scn = 2030   Batch
   IF @nStep = 2 GOTO Step_2   -- Scn = 2031   Batch, PO#
   IF @nStep = 3 GOTO Step_3   -- Scn = 2032   Option
   IF @nStep = 4 GOTO Step_4   -- Scn = 2033   Message
END

RETURN -- Do nothing if incorrect step

/********************************************************************************
Step 0. Called from menu (func = 893)
********************************************************************************/
Step_0:
BEGIN
   -- Set the entry point
   SET @nScn  = 2030
   SET @nStep = 1

   SET @cDefaultOption = ''
   SET @cDefaultOption = rdt.RDTGetConfig( @nFunc, 'DefaultOption', @cStorerKey)

   -- Init var
   SET @cOrderkey = ''
   SET @cExternPOKey = ''
   SET @cBatch = ''

   -- Prep next screen var   
   SET @cOutField01 = ''  -- Batch

END
GOTO Quit

/********************************************************************************
Step 1. screen = 2030
   Batch (Field01, input)
********************************************************************************/
Step_1:
BEGIN
   IF @nInputKey = 1 -- ENTER
   BEGIN
      -- Screen mapping
      SET @cBatch = @cInField01

      --When Batch is blank
      IF ISNULL(RTRIM(@cBatch), '') = ''
      BEGIN
         SET @nErrNo = 66951
         SET @cErrMsg = rdt.rdtgetmessage( 66951, @cLangCode, 'DSP') --Batch needed
         GOTO Step_1_Fail  
      END 


      IF NOT EXISTS (SELECT 1 FROM rdt.rdtCSAudit_Batch (NOLOCK) 
                     WHERE StorerKey = @cStorerKey AND Batch = @cBatch)
      BEGIN
         SET @nErrNo = 66952
         SET @cErrMsg = rdt.rdtgetmessage( 66952, @cLangCode, 'DSP') --BatchNotFound
         GOTO Step_1_Fail      
      END
 

      IF NOT EXISTS (SELECT 1 FROM rdt.rdtCSAudit_Batch (NOLOCK) 
                     WHERE StorerKey = @cStorerKey AND Batch = @cBatch 
                     AND CloseWho = '')
      BEGIN
         SET @nErrNo = 66953
         SET @cErrMsg = rdt.rdtgetmessage( 66953, @cLangCode, 'DSP') --BatchAlrdyClosed
         GOTO Step_1_Fail      
      END

      
      --prepare next screen variable
      SET @cOutField01 = @cBatch
      SET @cOutField02 = ''
                  
      -- Go to next screen
      SET @nScn = @nScn + 1
      SET @nStep = @nStep + 1

   END

   IF @nInputKey = 0 -- ESC
   BEGIN
      -- Back to menu
      SET @nFunc = @nMenu
      SET @nScn  = @nMenu
      SET @nStep = 0
      SET @cOutField01 = '' -- Batch

      SET @cBatch = ''
   END
   GOTO Quit

   Step_1_Fail:
   BEGIN
      SET @cBatch = ''

      -- Reset this screen var
      SET @cOutField01 = ''  -- Batch
  END
END
GOTO Quit

/********************************************************************************
Step 2. screen = 2031
   BATCH:        (Field01) 
   PO#:          (Field02, input) 
********************************************************************************/
Step_2:
BEGIN
   IF @nInputKey = 1 -- ENTER
   BEGIN
      -- Screen mapping
      SET @cExternPOKey = @cInField02

      --When PO is blank
      IF ISNULL(RTRIM(@cExternPOKey), '') = ''
      BEGIN
         SET @nErrNo = 66954
         SET @cErrMsg = rdt.rdtgetmessage( 66954, @cLangCode, 'DSP') --PO# needed
         GOTO Step_2_Fail  
      END 


      IF EXISTS (SELECT 1 FROM rdt.rdtCSAudit_BatchPO (NOLOCK) 
                 WHERE StorerKey = @cStorerKey AND Batch = @cBatch
                 AND PO_No = @cExternPOKey)
      BEGIN
         SET @nErrNo = 66955
         SET @cErrMsg = rdt.rdtgetmessage( 66955, @cLangCode, 'DSP') --POAlrdyExst
         GOTO Step_2_Fail      
      END
 
      IF EXISTS (SELECT 1 FROM rdt.rdtCSAudit_BatchPO (NOLOCK) 
                 WHERE StorerKey = @cStorerKey AND Batch <> @cBatch
                 AND PO_No = @cExternPOKey)
      BEGIN
         SET @nErrNo = 66959
         SET @cErrMsg = rdt.rdtgetmessage( 66959, @cLangCode, 'DSP') --POAlrdyUsed
         GOTO Step_2_Fail      
      END

      IF NOT EXISTS (SELECT TOP 1 1 FROM dbo.ORDERDETAIL WITH (NOLOCK) 
                     WHERE StorerKey = @cStorerKey AND Lottable03 = @cExternPOKey)
      BEGIN
         SET @nErrNo = 66956
         SET @cErrMsg = rdt.rdtgetmessage( 66956, @cLangCode, 'DSP') --PO# Not Exists
         GOTO Step_2_Fail      
      END

      SELECT TOP 1 @cOrderkey = Orderkey
      FROM dbo.ORDERDETAIL WITH (NOLOCK) 
      WHERE StorerKey = @cStorerKey 
        AND Lottable03 = @cExternPOKey

      
      --prepare next screen variable
      SET @cOutField01 = @cBatch
      SET @cOutField02 = @cExternPOKey
      SET @cOutField03 = CASE WHEN (@cDefaultOption <> '0' OR ISNULL(RTRIM(@cDefaultOption), '') = '') THEN @cDefaultOption ELSE '' END
                  
      -- Go to next screen
      SET @nScn = @nScn + 1
      SET @nStep = @nStep + 1

   END

   IF @nInputKey = 0 -- ESC
   BEGIN
       SET @cOutField01 = ''
       SET @cOutField02 = ''

       SET @cBatch = '' 
       SET @cExternPOKey = ''
              
       -- Go to Label Screen
       SET @nScn = @nScn - 1
       SET @nStep = @nStep - 1
   END
   GOTO Quit

   Step_2_Fail:
   BEGIN
      SET @cExternPOKey = ''

      -- Reset this screen var
      SET @cOutField02 = ''  -- PO#
  END
END
GOTO Quit

/********************************************************************************
Step 3. screen = 2032
   BATCH:        (Field01) 
   PO#:          (Field02) 
   OPTION:       (Field03, input) 
********************************************************************************/
Step_3:
BEGIN
   IF @nInputKey = 1 -- ENTER
   BEGIN

      -- Screen mapping
      SET @cOption = @cInField03
      
      -- Validate blank
      IF @cOption = '' OR @cOption IS NULL
      BEGIN
         SET @nErrNo = 66957
         SET @cErrMsg = rdt.rdtgetmessage( 66957, @cLangCode, 'DSP') --Option needed
         GOTO Step_3_Fail
      END

      -- Validate option
      IF (@cOption <> '1' AND @cOption <> '2')
      BEGIN
         SET @nErrNo = 66958
         SET @cErrMsg = rdt.rdtgetmessage( 66958, @cLangCode, 'DSP') --Invalid option
         GOTO Step_3_Fail
      END

      -- Confirm PO = Yes
      IF @cOption = '1'
      BEGIN
         -- Insert RDT.RDTCSAudit_BatchPO table
         INSERT INTO RDT.RDTCSAudit_BatchPO (StorerKey, Batch, PO_No, Orderkey, AddWho, AddDate)
         --VALUES (@cStorerKey, @cBatch, @cExternPOKey, @cOrderkey, @cUserName, GETDATE())
         SELECT DISTINCT @cStorerKey, @cBatch, @cExternPOKey, OrderKey, @cUserName, GETDATE()
         FROM dbo.ORDERDETAIL WITH (NOLOCK) 
         WHERE StorerKey = @cStorerKey 
         AND   Lottable03 = @cExternPOKey
                

         -- Go to next screen
         SET @cOutField01 = ''
         SET @cOutField02 = ''
         SET @cOutField03 = ''

         SET @nScn = @nScn + 1
         SET @nStep = @nStep + 1
      END
      ELSE
      BEGIN
         -- Go to prev screen
         SET @cOutField01 = @cBatch
         SET @cOutField02 = ''
         SET @cOutField03 = ''

         SET @nScn = @nScn - 1
         SET @nStep = @nStep - 1
      END
   END
   GOTO QUIT

--   IF @nInputKey = 0 -- ESC
--    BEGIN
--       -- Go to prev screen
--       SET @cOutField01 = @cBatch
--       SET @cOutField02 = ''
--       SET @cOutField03 = ''
-- 
--       SET @nScn = @nScn - 1
--       SET @nStep = @nStep - 1
--    END
--    GOTO Quit

   Step_3_Fail:
   BEGIN
      SET @cOutField01 = @cBatch
      SET @cOutField02 = @cExternPOKey
      SET @cOutField03 = CASE WHEN (@cDefaultOption <> '0' OR ISNULL(RTRIM(@cDefaultOption), '') = '') THEN @cDefaultOption ELSE '' END
   END   
END
GOTO Quit

/********************************************************************************
Step 4. screen = 2033 PO Successfully Saved
********************************************************************************/
Step_4:
BEGIN
   IF  @nInputKey = 1 OR @nInputKey = 0 -- ENTER/ESC
   BEGIN
          SET @cOutField01 = @cBatch
          SET @cOutField02 = '' 
          SET @cOutField03 = '' 

          SET @cExternPOKey = ''
          SET @cOption = ''

          -- go to previous screen
          SET @nScn = @nScn - 2
          SET @nStep = @nStep - 2
   END
   GOTO Quit
END
GOTO Quit

/********************************************************************************
Quit. Update back to I/O table, ready to be pick up by JBOSS
********************************************************************************/
Quit:
BEGIN
   UPDATE RDTMOBREC WITH (ROWLOCK) SET
       EditDate      = GETDATE(), 
       ErrMsg        = @cErrMsg, 
       Func          = @nFunc,
       Step          = @nStep,            
       Scn           = @nScn,

       StorerKey     = @cStorerKey,
       Facility      = @cFacility, 
       Printer       = @cPrinter,    
       -- UserName      = @cUserName,

       V_OrderKey    = @cOrderkey,
       V_String1     = @cExternPOKey,
       V_String2     = @cBatch,
       V_String3     = @cDefaultOption,   
       V_String4     = @cOption,

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
      I_Field15 = @cInField15,  O_Field15 = @cOutField15,

      FieldAttr01  = @cFieldAttr01,   FieldAttr02  = @cFieldAttr02,
      FieldAttr03  = @cFieldAttr03,   FieldAttr04  = @cFieldAttr04,
      FieldAttr05  = @cFieldAttr05,   FieldAttr06  = @cFieldAttr06,
      FieldAttr07  = @cFieldAttr07,   FieldAttr08  = @cFieldAttr08,
      FieldAttr09  = @cFieldAttr09,   FieldAttr10  = @cFieldAttr10,
      FieldAttr11  = @cFieldAttr11,   FieldAttr12  = @cFieldAttr12,
      FieldAttr13  = @cFieldAttr13,   FieldAttr14  = @cFieldAttr14,
      FieldAttr15  = @cFieldAttr15

   WHERE Mobile = @nMobile

END


GO