SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/************************************************************************/
/* Store procedure: rdtfnc_UCCVerify                                    */
/* Copyright      : LFLogistics                                         */
/*                                                                      */
/* Date        Rev  Author     Purposes                                 */
/* 11-JAN-2016 1.0  Ung        SOS359990 Created                        */
/* 30-Sep-2016 1.1  Ung        Performance tuning                       */
/* 05-Oct-2018 1.2  Gan        Performance tuning                       */
/************************************************************************/

CREATE PROC [RDT].[rdtfnc_UCCVerify] (
   @nMobile    INT,
   @nErrNo     INT           OUTPUT,
   @cErrMsg    NVARCHAR( 20) OUTPUT
)
AS
   SET NOCOUNT ON   
   SET QUOTED_IDENTIFIER OFF   
   SET ANSI_NULLS OFF  
   SET CONCAT_NULL_YIELDS_NULL OFF

-- Misc variables
DECLARE
   @bSuccess    INT, 
   @cSQL        NVARCHAR( MAX),
   @cSQLParam   NVARCHAR( MAX)

-- RDT.RDTMobRec variables
DECLARE
   @nFunc       INT,
   @nScn        INT,
   @nStep       INT,
   @cLangCode   NVARCHAR( 3),
   @nInputKey   INT,
   @nMenu       INT,

   @cStorerKey  NVARCHAR( 15),
   @cUserName   NVARCHAR( 18),
   @cFacility   NVARCHAR( 5),

   @cUCC        NVARCHAR( 20),
   @cSKU        NVARCHAR( 20),
   @cSKUDescr   NVARCHAR( 60),
   @nQTY        NVARCHAR( 5), 
   @cLOC        NVARCHAR( 10),
   @cID         NVARCHAR( 18),

   @cStatus          NVARCHAR( 1), 
   @cExtendedInfo    NVARCHAR( 20), 
   @cExtendedInfoSP  NVARCHAR( 20), 
   
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

-- Getting Mobile information
SELECT
   @nFunc     = Func,
   @nScn      = Scn,
   @nStep     = Step,
   @nInputKey = InputKey,
   @nMenu     = Menu,
   @cLangCode = Lang_code,

   @cStorerKey = StorerKey,
   @cFacility  = Facility,
   @cUserName  = UserName,
   
   @cUCC      = V_UCC,
   @cSKU      = V_SKU,
   @cSKUDescr = V_SKUDescr,
   @nQTY      = V_QTY,
   @cLOC      = V_LOC,
   @cID       = V_ID,

   @cStatus          = V_String1, 
   @cExtendedInfo    = V_String2, 
   @cExtendedInfoSP  = V_String3, 
   
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

FROM rdt.rdtMobRec (NOLOCK)
WHERE Mobile = @nMobile

IF @nFunc = 539 -- UCC Verify
BEGIN
   -- Redirect to respective screen
   IF @nStep = 0  GOTO Step_0   -- Func = 539
   IF @nStep = 1  GOTO Step_1   -- Scn = 4470. UCC
   IF @nStep = 2  GOTO Step_2   -- Scn = 4471. SKU
END
RETURN -- Do nothing if incorrect step


/********************************************************************************
Step 0. Func = 539
********************************************************************************/
Step_0:
BEGIN
   -- Storer configure
   SET @cExtendedInfoSP = rdt.RDTGetConfig( @nFunc, 'ExtendedInfoSP', @cStorerKey)
   IF @cExtendedInfoSP = '0'  
      SET @cExtendedInfoSP = ''
      
   -- Init var
   SET @cExtendedInfo = ''
      
   -- Set the entry point
   SET @nScn = 4470
   SET @nStep = 1
   
   -- Init screen
   SET @cOutField01 = '' -- UCC
   SET @cOutField15 = '' --@cExtendedInfo
END
GOTO Quit


/************************************************************************************
Step 1. Scn = 4470. UCC 
   UCC       (field01)
************************************************************************************/
Step_1:
BEGIN
   IF @nInputKey = 1 -- ENTER
   BEGIN
      -- Screen mapping
      SET @cUCC = @cInField01      
      
      -- Check blank
      IF @cUCC = ''
      BEGIN
         SET @nErrNo = 59601
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --'UCC needed'
         GOTO Quit
      END      

      -- Check UCC valid
      EXEC RDT.rdtIsValidUCC @cLangCode, @nErrNo OUTPUT, @cErrMsg OUTPUT,  
         @cUCC,  
         @cStorerKey,  
         '136' -- Status = 1-Received, 3=Alloc, 6=Replen
      IF @nErrNo <> 0  
         GOTO Quit
         
      -- Get UCC info
      SELECT 
         @cLOC = LOC, 
         @cID = ID, 
         @cStatus = Status, 
         @nQTY = QTY
      FROM UCC WITH (NOLOCK)
      WHERE StorerKey = @cStorerKey
         AND UCCNo = @cUCC
      
      -- Prepare next screen var
      SET @cOutField01 = @cUCC
      SET @cOutField02 = @cLOC
      SET @cOutField03 = @cID
      SET @cOutField04 = @cStatus
      SET @cOutField05 = '' --@cSKU
      SET @cOutField06 = '' --@cSKU
      SET @cOutField07 = '' --@cSKUDescr
      SET @cOutField08 = '' --@cSKUDescr
      SET @cOutField09 = '' --@nQTY

      -- Got to next screen
      SET @nScn = @nScn + 1
      SET @nStep = @nStep + 1

      -- Extended info
      IF @cExtendedInfoSP <> ''
      BEGIN
         IF EXISTS( SELECT 1 FROM dbo.sysobjects WHERE name = @cExtendedInfoSP AND type = 'P')
         BEGIN
            SET @cOutField15 = '' 
            SET @cSQL = 'EXEC rdt.' + RTRIM(@cExtendedInfoSP) +
               ' @nMobile, @nFunc, @cLangCode, @nStep, @nAfterStep, @nInputKey, @cFacility, @cStorerKey, @cUCC, @cSKU, ' + 
               ' @cExtendedInfo OUTPUT, @nErrNo OUTPUT, @cErrMsg OUTPUT '
            SET @cSQLParam =
               '@nMobile        INT, ' +
               '@nFunc          INT, ' +
               '@cLangCode      NVARCHAR( 3),  ' +
               '@nStep          INT, ' +
               '@nAfterStep     INT, ' +
               '@nInputKey      INT, ' + 
               '@cFacility      NVARCHAR( 15), ' +
               '@cStorerKey     NVARCHAR( 15), ' +
               '@cUCC           NVARCHAR( 20), ' +
               '@cSKU           NVARCHAR( 20), ' +
               '@cExtendedInfo  NVARCHAR( 20) OUTPUT, ' +
               '@nErrNo         INT           OUTPUT, ' + 
               '@cErrMsg        NVARCHAR( 20) OUTPUT'
           
            EXEC sp_ExecuteSQL @cSQL, @cSQLParam,
               @nMobile, @nFunc, @cLangCode, 1, @nStep, @nInputKey, @cFacility, @cStorerKey, @cUCC, @cSKU, 
               @cExtendedInfo OUTPUT, @nErrNo OUTPUT, @cErrMsg OUTPUT 
         
            IF @nErrNo <> 0
               GOTO Quit
            
            SET @cOutField15 = @cExtendedInfo
         END
      END
   END

   IF @nInputKey = 0 -- ESC
   BEGIN
      SET @nFunc = @nMenu
      SET @nScn  = @nMenu
      SET @nStep = 0
      SET @cOutField01 = ''
   END
END
GOTO Quit


/************************************************************************************
 Step 2. Scn = 4471. SKU
   UCC       (field01)
   LOC       (field02)
   ID        (field03)
   Status    (field04)
   SKU       (field05, input)
   SKU       (field06)
   SKUDESC1  (field07)
   SKUDESC2  (field08)
   QTY       (field09)
************************************************************************************/
Step_2:
BEGIN
   IF @nInputKey = 1
   BEGIN
      DECLARE @nSKUCnt INT

      -- Screen mapping
      SET @cSKU = @cInField05
      
      -- Check blank
      IF @cSKU = ''
      BEGIN
         SET @nErrNo = 59602
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --UCC SKU/UPC
         GOTO Quit
      END    

      -- Get SKU/UPC  
      SET @nSKUCnt = 0  
      EXEC rdt.rdt_GetSKUCNT  
          @cStorerKey  = @cStorerKey
         ,@cSKU        = @cSKU  
         ,@nSKUCnt     = @nSKUCnt  OUTPUT  
         ,@bSuccess    = @bSuccess OUTPUT  
         ,@nErr        = @nErrNo   OUTPUT  
         ,@cErrMsg     = @cErrMsg  OUTPUT  
  
      -- Validate SKU/UPC  
      IF @nSKUCnt = 0  
      BEGIN  
         SET @nErrNo = 59603
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Invalid SKU
         GOTO Quit  
      END  
  
      IF @nSKUCnt = 1  
         EXEC rdt.rdt_GetSKU
             @cStorerKey = @cStorerKey  
            ,@cSKU       = @cSKU     OUTPUT  
            ,@bSuccess   = @bSuccess OUTPUT  
            ,@nErr       = @nErrNo   OUTPUT  
            ,@cErrMsg    = @cErrMsg  OUTPUT  
    
      -- Check SKU in UCC
      IF NOT EXISTS( SELECT 1 FROM UCC WITH (NOLOCK) WHERE StorerKey = @cStorerKey AND UCCNo = @cUCC AND @cSKU = SKU)
      BEGIN
         SET @nErrNo = 59604
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --SKU not in UCC
         GOTO Quit
      END    

      -- Get SKU info
      SELECT @cSKUDescr = Descr FROM SKU WITH (NOLOCK) WHERE StorerKey = @cStorerKey AND SKU = @cSKU

      -- Prepare next screen var
      SET @cOutField01 = @cUCC
      SET @cOutField02 = @cLOC
      SET @cOutField03 = @cID
      SET @cOutField04 = @cStatus
      SET @cOutField05 = '' --@cSKU
      SET @cOutField06 = @cSKU
      SET @cOutField07 = SUBSTRING( @cSKUDescr, 1, 20)
      SET @cOutField08 = SUBSTRING( @cSKUDescr, 21, 20)
      SET @cOutField09 = CAST( @nQTY AS NVARCHAR( 5))

      -- Extended info
      IF @cExtendedInfoSP <> ''
      BEGIN
         IF EXISTS( SELECT 1 FROM dbo.sysobjects WHERE name = @cExtendedInfoSP AND type = 'P')
         BEGIN
            SET @cOutField15 = '' 
            SET @cSQL = 'EXEC rdt.' + RTRIM(@cExtendedInfoSP) +
               ' @nMobile, @nFunc, @cLangCode, @nStep, @nAfterStep, @nInputKey, @cFacility, @cStorerKey, @cUCC, @cSKU, ' + 
               ' @cExtendedInfo OUTPUT, @nErrNo OUTPUT, @cErrMsg OUTPUT '
            SET @cSQLParam =
               '@nMobile        INT, ' +
               '@nFunc          INT, ' +
               '@cLangCode      NVARCHAR( 3),  ' +
               '@nStep          INT, ' +
               '@nAfterStep     INT, ' +
               '@nInputKey      INT, ' + 
               '@cFacility      NVARCHAR( 15), ' +
               '@cStorerKey     NVARCHAR( 15), ' +
               '@cUCC           NVARCHAR( 20), ' +
               '@cSKU           NVARCHAR( 20), ' +
               '@cExtendedInfo  NVARCHAR( 20) OUTPUT, ' +
               '@nErrNo         INT           OUTPUT, ' + 
               '@cErrMsg        NVARCHAR( 20) OUTPUT'
           
            EXEC sp_ExecuteSQL @cSQL, @cSQLParam,
               @nMobile, @nFunc, @cLangCode, 2, @nStep, @nInputKey, @cFacility, @cStorerKey, @cUCC, @cSKU, 
               @cExtendedInfo OUTPUT, @nErrNo OUTPUT, @cErrMsg OUTPUT 
         
            IF @nErrNo <> 0
               GOTO Quit
            
            SET @cOutField15 = @cExtendedInfo
         END
      END
   END

   IF @nInputKey = 0 -- ESC
   BEGIN
      -- Prepare prev screen var
      SET @cOutField01 = '' --@cUCC
      
      -- Back to previous screen
      SET @nScn = @nScn - 1
      SET @nStep = @nStep - 1
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

      StorerKey  = @cStorerKey,
      Facility   = @cFacility,
      -- UserName   = @cUserName,
      
      V_UCC      = @cUCC,
      V_SKU      = @cSKU,
      V_SKUDescr = @cSKUDescr,
      V_QTY      = @nQTY,
      V_LOC      = @cLOC,
      V_ID       = @cID,
      
      V_String1  = @cStatus, 
      V_String2  = @cExtendedInfo, 
      V_String3  = @cExtendedInfoSP, 

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