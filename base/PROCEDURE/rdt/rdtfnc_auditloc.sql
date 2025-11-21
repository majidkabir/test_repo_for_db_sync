SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/************************************************************************/
/* Store procedure: rdtfnc_AuditLOC                                     */
/* Copyright      : IDS                                                 */
/*                                                                      */
/* Purpose: Ad-hoc check LOC integrity                                  */
/*                                                                      */
/* Date        Rev  Author     Purposes                                 */
/* 03-Aug-2022 1.0  Ung        WMS-20334 Created                        */
/* 03-Oct-2022 1.1  Ung        WMS-20844 Add ExtendedValidateSP         */
/************************************************************************/

CREATE   PROC [RDT].[rdtfnc_AuditLOC] (
   @nMobile    INT,
   @nErrNo     INT  OUTPUT,
   @cErrMsg    NVARCHAR(1024) OUTPUT
)
AS
SET NOCOUNT ON
SET QUOTED_IDENTIFIER OFF
SET ANSI_NULLS OFF
SET CONCAT_NULL_YIELDS_NULL OFF

DECLARE 
   @b_Success  INT,
   @n_Err      INT,
   @c_ErrMsg   NVARCHAR( 20), 
   @cSQL       NVARCHAR( MAX), 
   @cSQLParam  NVARCHAR( MAX), 
   @cDescr     NVARCHAR( 60), 
   @nQTYSKU    INT, 
   @nQTYAvail  INT, 
   @tVar       VariableTable

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

   @cLOC       NVARCHAR( 10),
   @cSKU       NVARCHAR( 20),

   @cExtendedValidateSP NVARCHAR( 20),

   @nQTYScan   INT,
   @nTotalRec  INT,
   @nCurrRec   INT,

   @cInField01 NVARCHAR( 60),   @cOutField01 NVARCHAR( 60),    @cFieldAttr01 NVARCHAR( 1),
   @cInField02 NVARCHAR( 60),   @cOutField02 NVARCHAR( 60),    @cFieldAttr02 NVARCHAR( 1),
   @cInField03 NVARCHAR( 60),   @cOutField03 NVARCHAR( 60),    @cFieldAttr03 NVARCHAR( 1),
   @cInField04 NVARCHAR( 60),   @cOutField04 NVARCHAR( 60),    @cFieldAttr04 NVARCHAR( 1),
   @cInField05 NVARCHAR( 60),   @cOutField05 NVARCHAR( 60),    @cFieldAttr05 NVARCHAR( 1),
   @cInField06 NVARCHAR( 60),   @cOutField06 NVARCHAR( 60),    @cFieldAttr06 NVARCHAR( 1),
   @cInField07 NVARCHAR( 60),   @cOutField07 NVARCHAR( 60),    @cFieldAttr07 NVARCHAR( 1),
   @cInField08 NVARCHAR( 60),   @cOutField08 NVARCHAR( 60),    @cFieldAttr08 NVARCHAR( 1),
   @cInField09 NVARCHAR( 60),   @cOutField09 NVARCHAR( 60),    @cFieldAttr09 NVARCHAR( 1),
   @cInField10 NVARCHAR( 60),   @cOutField10 NVARCHAR( 60),    @cFieldAttr10 NVARCHAR( 1),
   @cInField11 NVARCHAR( 60),   @cOutField11 NVARCHAR( 60),    @cFieldAttr11 NVARCHAR( 1),
   @cInField12 NVARCHAR( 60),   @cOutField12 NVARCHAR( 60),    @cFieldAttr12 NVARCHAR( 1),
   @cInField13 NVARCHAR( 60),   @cOutField13 NVARCHAR( 60),    @cFieldAttr13 NVARCHAR( 1),
   @cInField14 NVARCHAR( 60),   @cOutField14 NVARCHAR( 60),    @cFieldAttr14 NVARCHAR( 1),
   @cInField15 NVARCHAR( 60),   @cOutField15 NVARCHAR( 60),    @cFieldAttr15 NVARCHAR( 1)

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
   @cLOC       = V_LOC,
   @cSKU       = V_SKU,

   @cExtendedValidateSP = V_String21,

   @nQTYScan   = V_Integer1,
   @nTotalRec  = V_Integer2,
   @nCurrRec   = V_Integer3,

   @cInField01 = I_Field01,   @cOutField01 = O_Field01,  @cFieldAttr01 = FieldAttr01,
   @cInField02 = I_Field02,   @cOutField02 = O_Field02,  @cFieldAttr02 = FieldAttr02,
   @cInField03 = I_Field03,   @cOutField03 = O_Field03,  @cFieldAttr03 = FieldAttr03,
   @cInField04 = I_Field04,   @cOutField04 = O_Field04,  @cFieldAttr04 = FieldAttr04,
   @cInField05 = I_Field05,   @cOutField05 = O_Field05,  @cFieldAttr05 = FieldAttr05,
   @cInField06 = I_Field06,   @cOutField06 = O_Field06,  @cFieldAttr06 = FieldAttr06,
   @cInField07 = I_Field07,   @cOutField07 = O_Field07,  @cFieldAttr07 = FieldAttr07,
   @cInField08 = I_Field08,   @cOutField08 = O_Field08,  @cFieldAttr08 = FieldAttr08,
   @cInField09 = I_Field09,   @cOutField09 = O_Field09,  @cFieldAttr09 = FieldAttr09,
   @cInField10 = I_Field10,   @cOutField10 = O_Field10,  @cFieldAttr10 = FieldAttr10,
   @cInField11 = I_Field11,   @cOutField11 = O_Field11,  @cFieldAttr11 = FieldAttr11,
   @cInField12 = I_Field12,   @cOutField12 = O_Field12,  @cFieldAttr12 = FieldAttr12,
   @cInField13 = I_Field13,   @cOutField13 = O_Field13,  @cFieldAttr13 = FieldAttr13,
   @cInField14 = I_Field14,   @cOutField14 = O_Field14,  @cFieldAttr14 = FieldAttr14,
   @cInField15 = I_Field15,   @cOutField15 = O_Field15,  @cFieldAttr15 = FieldAttr15

FROM rdt.RDTMOBREC (NOLOCK)
WHERE Mobile = @nMobile

IF @nFunc = 653 -- Data capture
BEGIN
   -- Redirect to respective screen
   IF @nStep = 0 GOTO Step_0   -- Func = Data capture
   IF @nStep = 1 GOTO Step_1   -- 6090 LOC
   IF @nStep = 2 GOTO Step_2   -- 6091 SKU
   IF @nStep = 3 GOTO Step_3   -- 6092 Varinace
END
RETURN -- Do nothing if incorrect step


/********************************************************************************
Step 0. func = 653. Menu
********************************************************************************/
Step_0:
BEGIN
   -- Storer configure
   SET @cExtendedValidateSP = rdt.rdtGetConfig( @nFunc, 'ExtendedValidateSP', @cStorerKey)
   IF @cExtendedValidateSP = '0'
      SET @cExtendedValidateSP = ''
   
   -- Set the entry point
   SET @nScn = 6090
   SET @nStep = 1

   -- EventLog
   EXEC RDT.rdt_STD_EventLog
      @cActionType = '1', -- Sign in
      @nMobileNo   = @nMobile,
      @nFunctionID = @nFunc,
      @cFacility   = @cFacility,
      @cStorerKey  = @cStorerkey
END
GOTO Quit


/********************************************************************************
Step 1. Screen = 6090
   LOC   (Field01, input)
********************************************************************************/
Step_1:
BEGIN
   IF @nInputKey = 1 -- ENTER
   BEGIN
      -- Screen mapping
      SET @cLOC = @cInField01

       -- Check blank
      IF @cLOC = ''
      BEGIN
         SET @nErrNo = 189201
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Need LOC
         SET @cOutField01 = ''
         GOTO Quit
      END

      -- Check LOC valid
      IF NOT EXISTS( SELECT 1 
         FROM dbo.LOC WITH (NOLOCK)
         WHERE Facility = @cFacility
            AND LOC = @cLOC)
      BEGIN
         SET @nErrNo = 189202
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Invalid LOC
         SET @cOutField01 = ''
         GOTO Quit
      END

      -- Extended validate
      IF @cExtendedValidateSP <> ''
      BEGIN
         IF EXISTS( SELECT 1 FROM sys.objects WHERE name = @cExtendedValidateSP AND type = 'P')
         BEGIN
            SET @cSQL = 'EXEC rdt.' + RTRIM( @cExtendedValidateSP) +
               ' @nMobile, @nFunc, @cLangCode, @nStep, @nInputKey, @cFacility, @cStorerKey, ' +
               ' @cLOC, @cSKU, @nQTYScan, @tVar, ' +
               ' @nErrNo OUTPUT, @cErrMsg OUTPUT '
            SET @cSQLParam =
               '@nMobile         INT,           ' +
               '@nFunc           INT,           ' +
               '@cLangCode       NVARCHAR( 3),  ' +
               '@nStep           INT,           ' +
               '@nInputKey       INT,           ' +
               '@cFacility       NVARCHAR( 5),  ' +
               '@cStorerKey      NVARCHAR( 15), ' +
               '@cLOC            NVARCHAR( 10), ' +
               '@cSKU            NVARCHAR( 20), ' +
               '@nQTYScan        INT,           ' +
               '@tVar            VariableTable  READONLY, ' +
               '@nErrNo          INT            OUTPUT,   ' +
               '@cErrMsg         NVARCHAR( 20)  OUTPUT    '
            EXEC sp_ExecuteSQL @cSQL, @cSQLParam,  
               @nMobile, @nFunc, @cLangCode, @nStep, @nInputKey, @cFacility, @cStorerKey, 
               @cLOC, @cSKU, @nQTYScan, @tVar, 
               @nErrNo OUTPUT, @cErrMsg OUTPUT 
            IF @nErrNo <> 0
               GOTO Quit
         END
      END

      SET @cOutField01 = @cLOC
      SET @cOutField02 = '' -- SKU
      SET @cOutField03 = '' -- QTYScan

      SET @nScn = @nScn + 1
      SET @nStep = @nStep + 1
   END

   IF @nInputKey = 0 -- ESC
   BEGIN
      -- EventLog
      EXEC RDT.rdt_STD_EventLog
         @cActionType = '9', -- Sign Out
         @nMobileNo   = @nMobile,
         @nFunctionID = @nFunc,
         @cFacility   = @cFacility,
         @cStorerKey  = @cStorerKey

      -- Back to menu
      SET @nFunc = @nMenu
      SET @nScn  = @nMenu
      SET @nStep = 0
      SET @cOutField01 = '' -- Option
   END
END
GOTO Quit


/********************************************************************************
Step 2. Screen = 6091
   LOC         (Field01)
   SKU         (Field02, input)
   QTY SCAN    (Field03)
********************************************************************************/
Step_2:
BEGIN
   IF @nInputKey = 1 -- ENTER
   BEGIN
      DECLARE @cBarcode NVARCHAR( 30)
      
      -- Screen mapping
      SET @cBarcode = @cInField02

       -- Check blank
      IF @cBarcode IN ('', '99')
      BEGIN
         IF @nQTYScan > 0 OR @cBarcode = '99'
         BEGIN
            -- Get variance
            SELECT 
               @cSKU = CASE WHEN A.SKU IS NULL THEN B.SKU ELSE A.SKU END, 
               @nQTYSKU = ISNULL( B.QTY, 0), 
               @nQTYAvail = ISNULL( A.QTY, 0)
            FROM 
            (
               SELECT SKU, QTY - QTYPicked AS QTY
               FROM dbo.SKUxLOC WITH (NOLOCK)
               WHERE LOC = @cLOC
                  AND QTY > 0
            ) A FULL OUTER JOIN
            (
               SELECT SKU, QTY
               FROM rdt.rdtAuditLOCLog WITH (NOLOCK)
               WHERE LOC = @cLOC
            ) B ON (A.SKU = B.SKU)
            WHERE A.QTY <> B.QTY
               OR A.SKU IS NULL
               OR B.SKU IS NULL
            ORDER BY 1 DESC
            
            SET @nTotalRec = @@ROWCOUNT
            
            IF @nTotalRec > 0
            BEGIN
               -- Get SKU info
               SELECT @cDescr = Descr FROM dbo.SKU WITH (NOLOCK) WHERE StorerKey = @cStorerKey AND SKU = @cSKU

               SET @nCurrRec = 1
               
               -- Prepare next screen var
               SET @cOutField01 = @cSKU
               SET @cOutField02 = SUBSTRING( @cDescr, 1, 20)
               SET @cOutField03 = SUBSTRING( @cDescr, 21, 20)
               SET @cOutField04 = CAST( @nQTYSKU AS NVARCHAR( 5))
               SET @cOutField05 = CAST( @nQTYAvail AS NVARCHAR( 5))
               SET @cOutField06 = CAST( @nQTYSKU - @nQTYAvail AS NVARCHAR( 5))
               SET @cOutField07 = CAST( @nCurrRec AS NVARCHAR( 5)) + '/' + CAST( @nTotalRec AS NVARCHAR( 5))
            END
            ELSE
            BEGIN
               SET @cOutField01 = ''
               SET @cOutField02 = '*** NO VARIANCE ***'
               SET @cOutField03 = ''
               SET @cOutField04 = ''
               SET @cOutField05 = ''
               SET @cOutField06 = ''
               SET @cOutField07 = ''
            END
            
            -- Go to next screen
            SET @nScn = @nScn + 1
            SET @nStep = @nStep + 1
            
            GOTO Quit
         END
         ELSE
         BEGIN
            SET @nErrNo = 189203
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Need SKU/UPC
            SET @cOutField02 = ''
            GOTO Quit
         END
      END

      -- Get SKU count
      DECLARE @nSKUCnt INT
      EXEC [RDT].[rdt_GETSKUCNT]
          @cStorerKey  = @cStorerKey
         ,@cSKU        = @cBarcode
         ,@nSKUCnt     = @nSKUCnt   OUTPUT
         ,@bSuccess    = @b_Success OUTPUT
         ,@nErr        = @n_Err     OUTPUT
         ,@cErrMsg     = @c_ErrMsg  OUTPUT

      -- Check SKU valid
      IF @nSKUCnt = 0
      BEGIN
         SET @nErrNo = 189204
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Invalid SKU
         SET @cOutField02 = ''
         GOTO Quit
      END

      -- Check multi SKU barcode
      IF @nSKUCnt > 1
      BEGIN
         SET @nErrNo = 189205
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --MultiSKUBarcod
         SET @cOutField02 = ''
         GOTO Quit
      END

      -- Get SKU info
      EXEC [RDT].[rdt_GETSKU]
          @cStorerKey  = @cStorerKey
         ,@cSKU        = @cBarcode  OUTPUT
         ,@bSuccess    = @b_Success OUTPUT
         ,@nErr        = @n_Err     OUTPUT
         ,@cErrMsg     = @c_ErrMsg  OUTPUT

      SET @cSKU = @cBarcode

      -- Extended validate
      IF @cExtendedValidateSP <> ''
      BEGIN
         IF EXISTS( SELECT 1 FROM sys.objects WHERE name = @cExtendedValidateSP AND type = 'P')
         BEGIN
            SET @cSQL = 'EXEC rdt.' + RTRIM( @cExtendedValidateSP) +
               ' @nMobile, @nFunc, @cLangCode, @nStep, @nInputKey, @cFacility, @cStorerKey, ' +
               ' @cLOC, @cSKU, @nQTYScan, @tVar, ' +
               ' @nErrNo OUTPUT, @cErrMsg OUTPUT '
            SET @cSQLParam =
               '@nMobile         INT,           ' +
               '@nFunc           INT,           ' +
               '@cLangCode       NVARCHAR( 3),  ' +
               '@nStep           INT,           ' +
               '@nInputKey       INT,           ' +
               '@cFacility       NVARCHAR( 5),  ' +
               '@cStorerKey      NVARCHAR( 15), ' +
               '@cLOC            NVARCHAR( 10), ' +
               '@cSKU            NVARCHAR( 20), ' +
               '@nQTYScan        INT,           ' +
               '@tVar            VariableTable  READONLY, ' +
               '@nErrNo          INT            OUTPUT,   ' +
               '@cErrMsg         NVARCHAR( 20)  OUTPUT    '
            EXEC sp_ExecuteSQL @cSQL, @cSQLParam,  
               @nMobile, @nFunc, @cLangCode, @nStep, @nInputKey, @cFacility, @cStorerKey, 
               @cLOC, @cSKU, @nQTYScan, @tVar, 
               @nErrNo OUTPUT, @cErrMsg OUTPUT 
            IF @nErrNo <> 0
               GOTO Quit
         END
      END

      -- Confirm
      IF EXISTS( SELECT TOP 1 1 
         FROM rdt.rdtAuditLOCLog WITH (NOLOCK)
         WHERE StorerKey = @cStorerKey
            AND LOC = @cLOC
            AND SKU = @cSKU)
      BEGIN
         UPDATE rdt.rdtAuditLOCLog SET
            QTY = QTY + 1
         WHERE StorerKey = @cStorerKey
            AND LOC = @cLOC
            AND SKU = @cSKU
         IF @@ERROR <> 0
         BEGIN
            SET @nErrNo = 189206
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --UPD LOG FAIL
            SET @cOutField02 = ''
            GOTO Quit
         END
      END
      ELSE
      BEGIN
         INSERT INTO rdt.rdtAuditLOCLog (StorerKey, LOC, SKU, QTY)
         VALUES (@cStorerKey, @cLOC, @cSKU, 1)
         IF @@ERROR <> 0
         BEGIN
            SET @nErrNo = 189207
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --INS LOG FAIL
            SET @cOutField02 = ''
            GOTO Quit
         END
      END
      
      -- Increase counter
      SET @nQTYScan += 1

      -- Prepare current screen var
      SET @cOutField01 = @cLOC
      SET @cOutField02 = '' -- SKU
      SET @cOutField03 = CAST( @nQTYScan AS NVARCHAR( 5))
      
      -- Remain in current screen
   END

   IF @nInputKey = 0 -- ESC
   BEGIN
      -- Clear log
      DECLARE @nRowRef INT
      DECLARE @curLog CURSOR
      SET @curLog = CURSOR LOCAL READ_ONLY FAST_FORWARD FOR
         SELECT RowRef
         FROM rdt.rdtAuditLOCLog WITH (NOLOCK)
         WHERE StorerKey = @cStorerKey
            AND LOC = @cLOC
      OPEN @curLog 
      FETCH NEXT FROM @curLog INTO @nRowRef
      WHILE @@FETCH_STATUS = 0
      BEGIN
         DELETE rdt.rdtAuditLOCLog
         WHERE RowRef = @nRowRef
         IF @@ERROR <> 0
         BEGIN
            SET @nErrNo = 189208
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --INS LOG FAIL
            SET @cOutField02 = ''
            GOTO Quit
         END
         FETCH NEXT FROM @curLog INTO @nRowRef
      END
      
      SET @nQTYScan = 0
      
      -- Prepare prev screen var
      SET @cOutField01 = '' -- LOC

      -- Go to prev screen
      SET @nScn  = @nScn - 1
      SET @nStep = @nStep - 1
   END
END
GOTO Quit


/********************************************************************************
Step 3. Screen = 6092
   SKU         (Field01)
   SKU Desc1   (Field02)
   SKU Desc2   (Field03)
   QTY SCAN    (Field04)
   QTY AVAIL   (Field05)
   VARIANCE    (Field06)
   PAGES       (Field07)
********************************************************************************/
Step_3:
BEGIN
   IF @nInputKey = 1 -- ENTER
   BEGIN
      -- Screen mapping
      SET @cSKU = @cOutField01 
      
      -- Get variance
      SELECT TOP 1 
         @cSKU = CASE WHEN A.SKU IS NULL THEN B.SKU ELSE A.SKU END, 
         @nQTYSKU = ISNULL( B.QTY, 0), 
         @nQTYAvail = ISNULL( A.QTY, 0)
      FROM 
      (
         SELECT SKU, QTY - QTYPicked AS QTY
         FROM dbo.SKUxLOC WITH (NOLOCK)
         WHERE LOC = @cLOC
            AND QTY > 0
      ) A FULL OUTER JOIN
      (
         SELECT SKU, QTY
         FROM rdt.rdtAuditLOCLog WITH (NOLOCK)
         WHERE LOC = @cLOC
      ) B ON (A.SKU = B.SKU)
      WHERE (A.QTY <> B.QTY
         OR A.SKU IS NULL
         OR B.SKU IS NULL)
         AND (CASE WHEN A.SKU IS NULL THEN B.SKU ELSE A.SKU END) > @cSKU
      ORDER BY 1
      
      IF @@ROWCOUNT = 0
      BEGIN
         -- Prepare prev screen var
         SET @cOutField01 = @cLOC
         SET @cOutField02 = '' -- SKU
         SET @cOutField03 = CAST( @nQTYScan AS NVARCHAR( 5))
         
         -- Go to prev screen
         SET @nScn = @nScn - 1
         SET @nStep = @nStep - 1
      END
      ELSE
      BEGIN
         -- Get SKU info
         SELECT @cDescr = Descr FROM dbo.SKU WITH (NOLOCK) WHERE StorerKey = @cStorerKey AND SKU = @cSKU

         SET @nCurrRec += 1
         
         -- Prepare next screen var
         SET @cOutField01 = @cSKU
         SET @cOutField02 = SUBSTRING( @cDescr, 1, 20)
         SET @cOutField03 = SUBSTRING( @cDescr, 21, 20)
         SET @cOutField04 = CAST( @nQTYSKU AS NVARCHAR( 5))
         SET @cOutField05 = CAST( @nQTYAvail AS NVARCHAR( 5))
         SET @cOutField06 = CAST( @nQTYSKU - @nQTYAvail AS NVARCHAR( 5))
         SET @cOutField07 = CAST( @nCurrRec AS NVARCHAR( 5)) + '/' + CAST( @nTotalRec AS NVARCHAR( 5))
      END      
   END
   
   IF @nInputKey = 0 -- ESC
   BEGIN
      -- Prepare prev screen var
      SET @cOutField01 = @cLOC
      SET @cOutField02 = '' -- SKU
      SET @cOutField03 = CAST( @nQTYScan AS NVARCHAR( 5))
      
      -- Go to prev screen
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

      StorerKey = @cStorerKey,
      Facility  = @cFacility,
      
      V_LOC     = @cLOC,
      V_SKU     = @cSKU,

      V_String21 = @cExtendedValidateSP,

      V_Integer1 = @nQTYScan,
      V_Integer2 = @nTotalRec,
      V_Integer3 = @nCurrRec,
   
      I_Field01 = @cInField01,  O_Field01 = @cOutField01,   FieldAttr01  = @cFieldAttr01,
      I_Field02 = @cInField02,  O_Field02 = @cOutField02,   FieldAttr02  = @cFieldAttr02,
      I_Field03 = @cInField03,  O_Field03 = @cOutField03,   FieldAttr03  = @cFieldAttr03,
      I_Field04 = @cInField04,  O_Field04 = @cOutField04,   FieldAttr04  = @cFieldAttr04,
      I_Field05 = @cInField05,  O_Field05 = @cOutField05,   FieldAttr05  = @cFieldAttr05,
      I_Field06 = @cInField06,  O_Field06 = @cOutField06,   FieldAttr06  = @cFieldAttr06,
      I_Field07 = @cInField07,  O_Field07 = @cOutField07,   FieldAttr07  = @cFieldAttr07,
      I_Field08 = @cInField08,  O_Field08 = @cOutField08,   FieldAttr08  = @cFieldAttr08,
      I_Field09 = @cInField09,  O_Field09 = @cOutField09,   FieldAttr09  = @cFieldAttr09,
      I_Field10 = @cInField10,  O_Field10 = @cOutField10,   FieldAttr10  = @cFieldAttr10,
      I_Field11 = @cInField11,  O_Field11 = @cOutField11,   FieldAttr11  = @cFieldAttr11,
      I_Field12 = @cInField12,  O_Field12 = @cOutField12,   FieldAttr12  = @cFieldAttr12,
      I_Field13 = @cInField13,  O_Field13 = @cOutField13,   FieldAttr13  = @cFieldAttr13,
      I_Field14 = @cInField14,  O_Field14 = @cOutField14,   FieldAttr14  = @cFieldAttr14,
      I_Field15 = @cInField15,  O_Field15 = @cOutField15,   FieldAttr15  = @cFieldAttr15
      
   WHERE Mobile = @nMobile
END

GO