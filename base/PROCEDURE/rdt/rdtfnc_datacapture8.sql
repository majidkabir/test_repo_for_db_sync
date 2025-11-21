SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/************************************************************************/
/* Store procedure: rdtfnc_DataCapture8                                 */
/* Copyright      : IDS                                                 */
/*                                                                      */
/* Purpose: Ad-hoc data capturing in warehouse                          */
/*                                                                      */
/* Date        Rev  Author     Purposes                                 */
/* 15-Dec-2015 1.0  James      SOS358913 Created                        */
/* 12-Jan-2016 1.1  James      Clear prev counter loc (james01)         */
/* 13-Jan-2016 1.2  James      Add EditWho & EditDate (james02)         */
/* 12-Aug-2016 1.3  SHONG      SOS# 375153 Include System Qty           */
/*                             Add confirm sp (james03)                 */
/* 30-Sep-2016 1.3  Ung        Performance tuning                       */
/* 31-Oct-2018 1.4  Gan        Performance tuning                       */
/************************************************************************/

CREATE PROC [RDT].[rdtfnc_DataCapture8] (
   @nMobile    INT,
   @nErrNo     INT  OUTPUT,
   @cErrMsg    NVARCHAR(1024) OUTPUT
)
AS
SET NOCOUNT ON
SET QUOTED_IDENTIFIER OFF
SET ANSI_NULLS OFF
SET CONCAT_NULL_YIELDS_NULL OFF  

DECLARE @b_Success   INT,
        @n_Err       INT,
        @c_ErrMsg    NVARCHAR( 20)
        
-- RDT.RDTMobRec variable
DECLARE
   @nFunc         INT,
   @nScn          INT,
   @nStep         INT,
   @cLangCode     NVARCHAR( 3),
   @nInputKey     INT,
   @nMenu         INT,

   @cStorerKey    NVARCHAR( 15),
   @cFacility     NVARCHAR( 5),

   @cStorer       NVARCHAR( 15),
   @cLoc          NVARCHAR( 10),
	@cSKU          NVARCHAR( 20),
	@cCountNo      NVARCHAR( 5),
	@cUserName     NVARCHAR( 18),
	@cPackUOM3     NVARCHAR( 10),
	@cSKUDescr     NVARCHAR( 60),
   @nCount        INT,
   @nSKUCnt       INT,
   @nSeqNo        INT,
   @nQtyOnHand    INT, 

   -- (james03)
   @cDataCaptureConfirmSP  NVARCHAR( 20), 
   @cExtendedUpdateSP      NVARCHAR( 20), 
   @cSQL                   NVARCHAR( 2000), 
   @cSQLParam              NVARCHAR( 2000), 

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

-- Load RDT.RDTMobRec
SELECT
   @nFunc      = Func,
   @nScn       = Scn,
   @nStep      = Step,
   @nInputKey  = InputKey,
   @nMenu      = Menu,
   @cLangCode  = Lang_code,
   @cUserName  = UserName,
   
   @cStorerKey = StorerKey,
   @cFacility  = Facility,
   @cLOC       = V_LOC,
   @cSKU       = V_SKU,   
   
   @nCount     = V_Integer1,

   @cCountNo   = V_String1, 
  -- @nCount     = CASE WHEN rdt.rdtIsValidQTY( LEFT( V_String2, 5), 0) = 1 THEN LEFT( V_String2, 5) ELSE 0 END, 

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
FROM rdt.RDTMOBREC (NOLOCK)
WHERE Mobile = @nMobile

IF @nFunc = 823 -- Data capture
BEGIN
   -- Redirect to respective screen
   IF @nStep = 0 GOTO Step_0   -- Func = Data capture
   IF @nStep = 1 GOTO Step_1   -- 4280 COUNT #
   IF @nStep = 2 GOTO Step_2   -- 4281 COUNT #, LOC
   IF @nStep = 3 GOTO Step_3   -- 4281 COUNT #, LOC, SKU, ITEM COUNT
END

RETURN -- Do nothing if incorrect step


/********************************************************************************
Step 0. func = 880. Menu
********************************************************************************/
Step_0:
BEGIN
   -- Set the entry point
   SET @nScn = 4460
   SET @nStep = 1

   -- Initiate var
   SET @cCountNo = ''

   -- EventLog - Sign In Function
   EXEC RDT.rdt_STD_EventLog
      @cActionType = '1', -- Sign in function
      @cUserID     = @cUserName,
      @nMobileNo   = @nMobile,
      @nFunctionID = @nFunc,
      @cFacility   = @cFacility,
      @cStorerKey  = @cStorerkey,
      @nStep       = @nStep
END
GOTO Quit


/********************************************************************************
Step 1. Screen = 4460
   COUNT NO       (Field01, input)
********************************************************************************/
Step_1:
BEGIN
   IF @nInputKey = 1 -- ENTER
   BEGIN
      IF ISNULL( @cInField01, '')  = ''
      BEGIN
         SET @nErrNo = 59151
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --'Count # req'
         GOTO Step_1_Fail
      END

      -- Validate count no
      IF rdt.rdtIsValidQTY( @cInField01, 1) = 0
      BEGIN
         SET @nErrNo = 59152
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --'Invalid count #'
         GOTO Step_1_Fail
      END

      IF CAST( @cInField01 AS INT) NOT BETWEEN 1 AND 9
      BEGIN
         SET @nErrNo = 59153
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --'Invalid count #'
         GOTO Step_1_Fail
      END

      SET @cCountNo = @cInField01
      SET @cLOC = ''      

      SET @cOutField01 = @cCountNo 
      SET @cOutField02 = '' 

      SET @nScn = @nScn + 1                
      SET @nStep = @nStep + 1                
   END

   IF @nInputKey = 0 -- ESC
   BEGIN
     -- EventLog - Sign Out Function
     EXEC RDT.rdt_STD_EventLog
       @cActionType = '9', -- Sign Out function
       @cUserID     = @cUserName,
       @nMobileNo   = @nMobile,
       @nFunctionID = @nFunc,
       @cFacility   = @cFacility,
       @cStorerKey  = @cStorerkey,
       @nStep       = @nStep

      -- Back to menu
      SET @nFunc = @nMenu
      SET @nScn  = @nMenu
      SET @nStep = 0
      SET @cOutField01 = '' -- Clean up for menu option
   END
   GOTO Quit

   Step_1_Fail:
   BEGIN
      SET @cCountNo = ''
      SET @cInfield01 = ''
   END
END
GOTO Quit

/********************************************************************************
Step 2. Screen = 4461
   COUNT NO       (Field01)
   LOC            (Field03, input)
********************************************************************************/
Step_2:
BEGIN
   IF @nInputKey = 1 -- ENTER
   BEGIN
      -- Screen mapping
      SET @cLOC = @cInField02

       -- Validate location
      IF ISNULL( @cLOC, '') = '' 
      BEGIN
         SET @nErrNo = 59154
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --'Loc req'
         GOTO Step_2_Fail
      END

      IF NOT EXISTS ( SELECT 1 FROM dbo.LOC WITH (NOLOCK) 
                      WHERE Facility = @cFacility 
                      AND   LOC = @cLOC)
      BEGIN
         SET @nErrNo = 59155
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --'Invalid loc'
         GOTO Step_2_Fail
      END

      -- (james01)
      IF EXISTS ( SELECT 1 FROM dbo.SKUxLOCIntegrity WITH (NOLOCK)
                  WHERE ID = @cCountNo
                  AND   LOC = @cLOC
                  AND   QtyCount > 0)
      BEGIN
         DECLARE CUR_LOOP CURSOR LOCAL READ_ONLY FAST_FORWARD FOR 
         SELECT SeqNo FROM dbo.SKUxLOCIntegrity WITH (NOLOCK)
         WHERE ID = @cCountNo
         AND   LOC = @cLOC
         AND   QtyCount > 0
         OPEN CUR_LOOP 
         FETCH NEXT FROM CUR_LOOP INTO @nSeqNo
         WHILE @@FETCH_STATUS <> -1
         BEGIN
            UPDATE dbo.SKUxLOCIntegrity WITH (ROWLOCK) SET 
               QtyCount = 0,
               EditWho = @cUserName,
               EditDate = GETDATE()
            WHERE SeqNo = @nSeqNo
            
            IF @@ERROR <> 0
            BEGIN
               SET @nErrNo = 59155
               SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --'Invalid loc'
               GOTO Step_2_Fail
            END
            
            FETCH NEXT FROM CUR_LOOP INTO @nSeqNo                  
         END
         CLOSE CUR_LOOP
         DEALLOCATE CUR_LOOP
      END

      -- (james03)
      SET @cExtendedUpdateSP = ''
      SET @cExtendedUpdateSP = rdt.RDTGetConfig( @nFunc, 'ExtendedUpdateSP', @cStorerKey)

      IF @cExtendedUpdateSP NOT IN ('', '0')
      BEGIN
         IF EXISTS( SELECT 1 FROM dbo.sysobjects WHERE name = @cExtendedUpdateSP AND type = 'P')
         BEGIN
            SET @nErrNo = 0
            SET @cSQL = 'EXEC rdt.' + RTRIM( @cExtendedUpdateSP) +
               ' @nMobile, @nFunc, @cLangCode, @nStep, @nInputKey, @cStorerKey, ' + 
               ' @cCountNo, @cLOC, @cSKU, @nErrNo OUTPUT, @cErrMsg OUTPUT  ' 

            SET @cSQLParam =
               '@nMobile         INT,           ' +
               '@nFunc           INT,           ' +
               '@cLangCode       NVARCHAR( 3),  ' +
               '@nInputKey       INT,           ' +
               '@nStep           INT,           ' +
               '@cStorerKey      NVARCHAR( 15), ' +
               '@cCountNo        NVARCHAR( 5),  ' +
               '@cLOC            NVARCHAR( 10), ' +
               '@cSKU            NVARCHAR( 20), ' +
               '@nErrNo          INT            OUTPUT, ' +
               '@cErrMsg         NVARCHAR( 20)  OUTPUT  ' 

            EXEC sp_ExecuteSQL @cSQL, @cSQLParam,
               @nMobile, @nFunc, @cLangCode, @nStep, @nInputKey, @cStorerKey, 
               @cCountNo, @cLOC, @cSKU, @nErrNo OUTPUT, @cErrMsg OUTPUT  

            IF @nErrNo <> 0
               GOTO Step_2_Fail
         END
      END
      
      SET @cOutField01 = @cCountNo 
      SET @cOutField02 = @cLOC 
      SET @cOutField03 = ''
      SET @cOutField04 = ''
      SET @cOutField05 = ''
      SET @cOutField06 = '0'

      SET @nScn = @nScn + 1                
      SET @nStep = @nStep + 1                
   END

   IF @nInputKey = 0 -- ESC
   BEGIN
      SET @cCountNo = ''
      SET @cOutField01 = '' 

      -- Go back screen 1
      SET @nScn  = @nScn - 1
      SET @nStep = @nStep - 1
   END
   GOTO Quit

   Step_2_Fail:
   BEGIN
      SET @cLOC = ''
      SET @cOutField02 = ''
   END
END
GOTO Quit

/********************************************************************************
Step 3. Screen = 4462
   COUNT NO       (Field01)
   LOC            (Field03)
   SKU            (Field03, input)
   ITEM COUNT     (Field04)
********************************************************************************/
Step_3:
BEGIN
   IF @nInputKey = 1 -- ENTER
   BEGIN
      -- Screen mapping
      SET @cSKU = @cInField03

       -- Validate location
      IF ISNULL( @cSKU, '') = '' 
      BEGIN
         SET @nErrNo = 59156
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --'SKU req'
         GOTO Step_3_Fail
      END

      EXEC [RDT].[rdt_GETSKUCNT]
       @cStorerKey  = @cStorerKey
      ,@cSKU        = @cSKU
      ,@nSKUCnt     = @nSKUCnt       OUTPUT
      ,@bSuccess    = @b_Success     OUTPUT
      ,@nErr        = @n_Err         OUTPUT
      ,@cErrMsg     = @c_ErrMsg      OUTPUT

      IF @nSKUCnt = 0
      BEGIN
         SET @nErrNo = 59157
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --'Invalid SKU'
         GOTO Step_3_Fail
      END

      IF @nSKUCnt > 1
      BEGIN
         SET @nErrNo = 59158
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --'Samebarcodesku'
         GOTO Step_3_Fail
      END

      EXEC [RDT].[rdt_GETSKU]
       @cStorerKey  = @cStorerKey
      ,@cSKU        = @cSKU        OUTPUT
      ,@bSuccess    = @b_Success     OUTPUT
      ,@nErr        = @n_Err         OUTPUT
      ,@cErrMsg     = @c_ErrMsg      OUTPUT

      SELECT @cSKUDescr = Descr,
             @cPackUOM3 = PackUOM3
      FROM dbo.SKU S WITH (NOLOCK) 
      JOIN dbo.Pack P WITH (NOLOCK) ON S.PackKey = P.PackKey
      WHERE StorerKey = @cStorerKey
      AND   SKU = @cSKU

      -- (james03)
      SET @cDataCaptureConfirmSP = ''
      SET @cDataCaptureConfirmSP = rdt.RDTGetConfig( @nFunc, 'DataCaptureConfirmSP', @cStorerKey)

      IF @cDataCaptureConfirmSP NOT IN ('', '0')
      BEGIN
         IF EXISTS( SELECT 1 FROM dbo.sysobjects WHERE name = @cDataCaptureConfirmSP AND type = 'P')
         BEGIN
            SET @nErrNo = 0
            SET @cSQL = 'EXEC rdt.' + RTRIM( @cDataCaptureConfirmSP) +
               ' @nMobile, @nFunc, @cLangCode, @nStep, @nInputKey, @cStorerKey, ' + 
               ' @cCountNo, @cLOC, @cSKU, @nErrNo OUTPUT, @cErrMsg OUTPUT  ' 

            SET @cSQLParam =
               '@nMobile         INT,           ' +
               '@nFunc           INT,           ' +
               '@cLangCode       NVARCHAR( 3),  ' +
               '@nInputKey       INT,           ' +
               '@nStep           INT,           ' +
               '@cStorerKey      NVARCHAR( 15), ' +
               '@cCountNo        NVARCHAR( 5),  ' +
               '@cLOC            NVARCHAR( 10), ' +
               '@cSKU            NVARCHAR( 20), ' +
               '@nErrNo          INT            OUTPUT, ' +
               '@cErrMsg         NVARCHAR( 20)  OUTPUT  ' 

            EXEC sp_ExecuteSQL @cSQL, @cSQLParam,
               @nMobile, @nFunc, @cLangCode, @nStep, @nInputKey, @cStorerKey, 
               @cCountNo, @cLOC, @cSKU, @nErrNo OUTPUT, @cErrMsg OUTPUT  

            IF @nErrNo <> 0
               GOTO Step_3_Fail
         END
      END
      ELSE
      BEGIN
         IF EXISTS ( SELECT 1 FROM dbo.SKUxLOCIntegrity WITH (NOLOCK) 
                     WHERE ID = @cCountNo
                     AND   LOC = @cLOC
                     AND   EntryValue = @cSKU)
         BEGIN
            UPDATE dbo.SKUxLOCIntegrity WITH (ROWLOCK) SET 
               QtyCount = QtyCount + 1, 
               EditWho = @cUserName,
               EditDate = GETDATE()            
            WHERE ID = @cCountNo
            AND   LOC = @cLOC
            AND   EntryValue = @cSKU

            IF @@ERROR <> 0
            BEGIN
               SET @nErrNo = 59159
               SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --'Upd err'
               GOTO Step_3_Fail
            END
                  
         END
         ELSE
         BEGIN                
      	   SET @nQtyOnHand=0  
      	   SELECT @nQtyOnHand = ISNULL(sl.Qty - sl.QtyPicked, 0)  
      	   FROM   SKUxLOC AS sl WITH (NOLOCK)
      	   WHERE sl.StorerKey = @cStorerKey 
      	   AND   sl.Sku = @cSKU
      	   AND   sl.Loc = @cLOC 
         	
            INSERT INTO dbo.SKUxLOCIntegrity (Facility, LOC, StorerKey, EntryValue, ID, QtyCount, EditWho, EditDate, Qty)
            VALUES(@cFacility, @cLOC, @cStorerKey, @cSKU, @cCountNo, 1, @cUserName, GETDATE(), @nQtyOnHand)
            
            IF @@ERROR <> 0
            BEGIN
               SET @nErrNo = 59160
               SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --'Ins err'
               GOTO Step_3_Fail
            END
         END
      END

      SELECT @nCount = ISNULL( SUM( QtyCount), 0)
      FROM dbo.SKUxLOCIntegrity WITH (NOLOCK) 
      WHERE ID = @cCountNo
      AND   LOC = @cLOC
      AND   EntryValue = @cSKU

      SET @cOutField01 = @cCountNo 
      SET @cOutField02 = @cLOC 
      SET @cOutField03 = '' 
      SET @cOutField04 = SUBSTRING( @cSKUDescr, 1, 20) 
      SET @cOutField05 = SUBSTRING( @cSKUDescr, 21, 20) 
      SET @cOutField06 = CAST( @nCount AS NVARCHAR( 5)) + ' ' + @cPackUOM3
   END

   IF @nInputKey = 0 -- ESC
   BEGIN
      SET @cLOC = ''
      SET @cOutField01 = @cCountNo
      SET @cOutField02 = ''

      -- Go back screen 1
      SET @nScn  = @nScn - 1
      SET @nStep = @nStep - 1
   END
   GOTO Quit

   Step_3_Fail:
   BEGIN
      SET @cSKU = ''
      SET @cOutField03 = ''
   END
END
GOTO Quit

/********************************************************************************
Quit. Update back to I/O table, ready to be pick up by JBOSS
********************************************************************************/
Quit:
BEGIN
   UPDATE rdt.RDTMOBREC WITH (ROWLOCK) SET
   		EditDate = GETDATE(),
      ErrMsg = @cErrMsg,
      Func   = @nFunc,
      Step   = @nStep,
      Scn    = @nScn,

      StorerKey = @cStorerKey,
      Facility  = @cFacility,
      V_LOC     = @cLOC,
      V_SKU     = @cSKU,
      
      V_Integer1 = @nCount,
            
      V_String1 = @cCountNo, 
      --V_String2 = @nCount, 

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