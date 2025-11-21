SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO


/******************************************************************************/
/* Copyright: LF                                                              */
/* Purpose: IDSTW Data Capture for UCC                                        */
/*                                                                            */
/* Modifications log:                                                         */
/*                                                                            */
/* Date       Rev  Author     Purposes                                        */
/* 2014-11-18 1.0  ChewKP     Created                                         */
/* 2016-09-30 1.1  Ung        Performance tuning                              */
/* 2018-09-21 1.2  Ung        WMS-6419 Add ID                                 */
/*                            SkipCheckUCCInUCCTable                          */
/* 2018-10-31 1.3  Gan        Performance tuning                              */
/* 2019-07-11 1.4  SPChin     INC0772023 - Bug Fixed                          */
/******************************************************************************/

CREATE PROC [RDT].[rdtfnc_DataCaptureUCC] (
   @nMobile    int,
   @nErrNo     int  OUTPUT,
   @cErrMsg    NVARCHAR(1024) OUTPUT -- screen limitation, 20 NVARCHAR max
)
AS
   SET NOCOUNT ON
   SET QUOTED_IDENTIFIER OFF
   SET ANSI_NULLS OFF
   SET CONCAT_NULL_YIELDS_NULL OFF

-- Misc variable
DECLARE
   @nCount              INT,
   @nRowCount           INT, 
   @cCode               NVARCHAR(20),
   @cInSKU              NVARCHAR(20),
   @nTotalUCCSKUCapture INT,
   @nTotalUCCSKU        INT,
   @nSKUCnt             INT

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
   @cPrinter   NVARCHAR( 20),
   @cUserName  NVARCHAR( 18),

   @nError        INT,
   @b_success     INT,
   @n_err         INT,
   @c_errmsg      NVARCHAR( 250),
   @cPUOM         NVARCHAR( 10),
   @bSuccess      INT,

   @cUCC          NVARCHAR(20),
   @cSKU          NVARCHAR(20),
   @cID           NVARCHAR(18),

   @cItemValue1   NVARCHAR(5),
   @cItemValue2   NVARCHAR(5),
   @cItemValue3   NVARCHAR(5),
   @cItemValue4   NVARCHAR(5),
   @cItemValue5   NVARCHAR(5),
   @cItemValue6   NVARCHAR(5),
   @cItemValue7   NVARCHAR(5),

   @cItem1        NVARCHAR(12),
   @cItem2        NVARCHAR(12),
   @cItem3        NVARCHAR(12),
   @cItem4        NVARCHAR(12),
   @cItem5        NVARCHAR(12),
   @cItem6        NVARCHAR(12),
   @cItem7        NVARCHAR(12),
   
   @nQty          INT,
   @cCartonType   NVARCHAR(10),
   @cActualQty    NVARCHAR(5),
   
   @cSkipCheckUCCInUCCTable NVARCHAR(20),
   @cDecodeIDSP             NVARCHAR(20),

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

   @cStorerKey = StorerKey,
   @cFacility  = Facility,
   @cPrinter   = Printer,
   @cUserName  = UserName,

   @cPUOM       = V_UOM,

   @cUCC        = V_UCC,
   @cSKU        = V_SKU,
   @cID         = V_ID,

   @cItemValue1 = V_String1,
   @cItemValue2 = V_String2,
   @cItemValue3 = V_String3,
   @cItemValue4 = V_String4,
   @cItemValue5 = V_String5,
   @cItemValue6 = V_String6,
   @cItemValue7 = V_String7,

   @cItem1      = V_String11,
   @cItem2      = V_String12,
   @cItem3      = V_String13,
   @cItem4      = V_String14,
   @cItem5      = V_String15,
   @cItem6      = V_String16,
   @cItem7      = V_String17,

  -- @nQty        = CASE WHEN rdt.rdtIsValidQTY( LEFT( V_String21, 5), 0) = 1 THEN LEFT( V_String21, 5) ELSE 0 END,
   @cCartonType = V_String22,
   @cActualQty  = V_String23,
   
   @cSkipCheckUCCInUCCTable = V_String31,
   @cDecodeIDSP             = V_String32,
   
   @nQty       = V_Integer1,

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
   @cFieldAttr03 =  FieldAttr03,    @cFieldAttr04  = FieldAttr04,
   @cFieldAttr05 =  FieldAttr05,    @cFieldAttr06   = FieldAttr06,
   @cFieldAttr07 =  FieldAttr07,    @cFieldAttr08   = FieldAttr08,
   @cFieldAttr09 =  FieldAttr09,    @cFieldAttr10   = FieldAttr10,
   @cFieldAttr11 =  FieldAttr11,    @cFieldAttr12   = FieldAttr12,
   @cFieldAttr13 =  FieldAttr13,    @cFieldAttr14   = FieldAttr14,
   @cFieldAttr15 =  FieldAttr15

FROM RDTMOBREC (NOLOCK)
WHERE Mobile = @nMobile

IF @nFunc = 821  -- Data Capture UCC
BEGIN
   -- Redirect to respective screen
   IF @nStep = 0 GOTO Step_0   -- Data Capture UCC
   IF @nStep = 1 GOTO Step_1   -- Scn = 4000. UCC, ID, CartonType
   IF @nStep = 2 GOTO Step_2   -- Scn = 4001. SKU, QTY
   IF @nStep = 3 GOTO Step_3   -- Scn = 4002. Item , QTY
END
RETURN -- Do nothing if incorrect step


/********************************************************************************
Step 0. func = 821. Menu
********************************************************************************/
Step_0:
BEGIN
   -- Storer configure
   SET @cDecodeIDSP = rdt.RDTGetConfig( @nFunc, 'DecodeIDSP', @cStorerKey)
   IF @cDecodeIDSP = '0'
      SET @cDecodeIDSP = ''
      
   --INC0772023
   SET @cSkipCheckUCCInUCCTable = rdt.RDTGetConfig( @nFunc, 'SkipCheckUCCInUCCTable', @cStorerKey)
         
   -- Get prefer UOM
   SET @cPUOM = ''
   SELECT @cPUOM = IsNULL( DefaultUOM, '6') -- If not defined, default as EA
   FROM RDT.rdtMobRec M WITH (NOLOCK)
      INNER JOIN RDT.rdtUser U WITH (NOLOCK) ON (M.UserName = U.UserName)
   WHERE M.Mobile = @nMobile

   -- EventLog
   EXEC RDT.rdt_STD_EventLog
     @cActionType = '1', -- Sign-in
     @cUserID     = @cUserName,
     @nMobileNo   = @nMobile,
     @nFunctionID = @nFunc,
     @cFacility   = @cFacility,
     @cStorerKey  = @cStorerkey,
     @nStep       = @nStep

   -- Init screen
   SET @cSKU = ''
   SET @cInSKU = ''
   SET @cOutField01 = ''
   SET @cOutField02 = ''

   -- Set the entry point
 SET @nScn = 4000
 SET @nStep = 1

 EXEC rdt.rdtSetFocusField @nMobile, 1
END
GOTO Quit


/********************************************************************************
Step 1. Scn = 4000.
   UCC         (Field01, input)
   ID          (Field02, input)
   Carton Type (Field03, input)
********************************************************************************/
Step_1:
BEGIN
   IF @nInputKey = 1 --ENTER
   BEGIN
      DECLARE @cIDBarcode NVARCHAR( 60)
      
      SET @cUCC = @cInField01
      SET @cID = @cInField02
      SET @cIDBarcode = @cInField02
      SET @cCartonType = @cInField03

      -- Validate blank
      IF ISNULL(RTRIM(@cUCC), '') = ''
      BEGIN
         SET @nErrNo = 92101
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --UCCReq
         GOTO Quit
      END

      -- Check UCC format
      IF rdt.rdtIsValidFormat( @nFunc, @cStorerKey, 'UCC', @cUCC) = 0
      BEGIN
         SET @nErrNo = 92117
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Invalid Format
         EXEC rdt.rdtSetFocusField @nMobile, 1
         SET @cOutField01 = ''
         GOTO Quit
      END

      IF @cSkipCheckUCCInUCCTable = '0'
      BEGIN
         -- Check UCC exist
         IF NOT EXISTS ( SELECT 1 FROM dbo.UCC WITH (NOLOCK) WHERE UCCNo = @cUCC AND StorerKey = @cStorerKey )
         BEGIN
            SET @nErrNo = 92102
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --InvalidUCC
            EXEC rdt.rdtSetFocusField @nMobile, 1
            SET @cOutField01 = ''
            GOTO Quit
         END
      END
      SET @cOutField01 = @cUCC 

      -- Check ID format
      IF rdt.rdtIsValidFormat( @nFunc, @cStorerKey, 'ID', @cID) = 0
      BEGIN
         SET @nErrNo = 92118
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Invalid Format
         EXEC rdt.rdtSetFocusField @nMobile, 2
         SET @cOutField02 = ''
         GOTO Quit
      END
      
      IF @cDecodeIDSP <> ''
      BEGIN
         -- Standard decode
         IF @cDecodeIDSP = '1'
         BEGIN
            EXEC rdt.rdt_Decode @nMobile, @nFunc, @cLangCode, @nStep, @nInputKey, @cStorerKey, @cFacility, @cIDBarcode, 
               @cID   = @cID  OUTPUT, 
               @cType = 'ID'
         END
      END
      SET @cOutField02 = @cID 

      -- Prepare Next Screen Variable
      SET @cOutField01 = @cUCC
      SET @cOutField02 = @cID
      SET @cOutField03 = ''
      SET @cOutField04 = ''
      SET @cOutField05 = ''
      SET @cOutField06 = ''

      -- GOTO Next Screen
      SET @nScn = @nScn + 1
      SET @nStep = @nStep + 1

      EXEC rdt.rdtSetFocusField @nMobile, 2
   END

   IF @nInputKey = 0
   BEGIN
      -- EventLog
      EXEC RDT.rdt_STD_EventLog
         @cActionType = '9', -- Sign in function
         @cUserID     = @cUserName,
         @nMobileNo   = @nMobile,
         @nFunctionID = @nFunc,
         @cFacility   = @cFacility,
         @cStorerKey  = @cStorerkey,
         @nStep       = @nStep

      -- go to main menu
      SET @nFunc = @nMenu
      SET @nScn  = @nMenu
      SET @nStep = 0
      SET @cOutField01 = ''
   END
END
GOTO QUIT


/********************************************************************************
Step 2. Scn = 4001.
   UCC          (field01)
   ID           (field02)
   SKU          (field03, input)
   SKU          (field04)
   Qty Expected (field05)
   Qty Actual   (field06, input)
********************************************************************************/
Step_2:
BEGIN
   IF @nInputKey = 1
   BEGIN
      DECLARE @cUPC NVARCHAR( 30)
      
      SET @cUPC = @cInField03
      SET @cActualQty = @cInField06

      IF @cUPC = ''
      BEGIN
         SET @nErrNo = 92103
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --SKUReq
         EXEC rdt.rdtSetFocusField @nMobile, 3
         GOTO Step_2_Fail
      END

      -- Get SKU barcode count
      SET @nSKUCnt = 0
      EXEC rdt.rdt_GETSKUCNT
          @cStorerKey  = @cStorerKey
         ,@cSKU        = @cUPC
         ,@nSKUCnt     = @nSKUCnt       OUTPUT
         ,@bSuccess    = @b_Success     OUTPUT
         ,@nErr        = @nErrNo        OUTPUT
         ,@cErrMsg     = @cErrMsg       OUTPUT

      -- Check SKU/UPC
      IF @nSKUCnt = 0
      BEGIN
         SET @nErrNo = 92115
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') -- Invalid SKU
         GOTO Step_2_Fail
      END

      -- Check multi SKU barcode
      IF @nSKUCnt > 1
      BEGIN
         SET @nErrNo = 92116
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') -- MultiSKUBarCod
         GOTO Step_2_Fail
      END

      -- Get SKU code
      EXEC rdt.rdt_GETSKU
          @cStorerKey  = @cStorerKey
         ,@cSKU        = @cUPC          OUTPUT
         ,@bSuccess    = @b_Success     OUTPUT
         ,@nErr        = @nErrNo        OUTPUT
         ,@cErrMsg     = @cErrMsg       OUTPUT
      
      SET @cSKU = @cUPC

      IF @cSkipCheckUCCInUCCTable = '0'
      BEGIN
         IF NOT EXISTS ( SELECT 1 FROM dbo.UCC WITH (NOLOCK)
                         WHERE UCCNo = @cUCC
                         AND SKU = @cSKU )
         BEGIN
            SET @nErrNo = 92104
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Invalid SKU
            EXEC rdt.rdtSetFocusField @nMobile, 3
            GOTO Step_2_Fail
         END
      END

      IF EXISTS( SELECT 1 FROM rdt.RDTDataCapture WITH (NOLOCK)
                 WHERE StorerKey = @cStorerKey
                 AND V_UCC = @cUCC
                 AND V_SKU = @cSKU )
      BEGIN
         SET @nErrNo = 92113
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Invalid SKU
         EXEC rdt.rdtSetFocusField @nMobile, 3
         GOTO Step_2_Fail
      END

      -- Get UCC info
      SELECT @nQty = ISNULL(Qty,0 )
      FROM dbo.UCC WITH (NOLOCK)
      WHERE UCCNo    = @cUCC
      AND StorerKey  = @cStorerKey
      AND SKU        = @cSKU

      SET @cOutField03 = @cSKU
      SET @cOutField04 = @cSKU
      SET @cOutField05 = CAST ( @nQty AS NVARCHAR(5) )

      IF @cActualQty = ''
      BEGIN
         EXEC rdt.rdtSetFocusField @nMobile, 6 -- ActQTY
         GOTO Quit
      END
         
      IF rdt.rdtIsValidQTY( @cActualQty, 0) = 0
      BEGIN
         SET @nErrNo = 92105
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Invalid Qty
         EXEC rdt.rdtSetFocusField @nMobile, 6
         GOTO Step_2_Fail
      END

      SET @nCount = 1
      SET @cItem1 = ''
      SET @cItem2 = ''
      SET @cItem3 = ''
      SET @cItem4 = ''
      SET @cItem5 = ''
      SET @cItem6 = ''
      SET @cItem7 = ''

      DECLARE CursorCodeLkup CURSOR LOCAL FAST_FORWARD READ_ONLY FOR
         SELECT Description
         FROM dbo.CodeLkup WITH (NOLOCK)
         WHERE ListName = 'RDTDataCap'
         AND StorerKey = @cStorerKey
      ORDER BY Code
      OPEN CursorCodeLkup
      FETCH NEXT FROM CursorCodeLkup INTO @cCode

      WHILE @@FETCH_STATUS <> -1
      BEGIN
         IF @nCount = 1
         BEGIN
            SET @cItem1 = @cCode
         END
         ELSE IF @nCount = 2
         BEGIN
            SET @cItem2 = @cCode
         END
         ELSE IF @nCount = 3
         BEGIN
            SET @cItem3 = @cCode
         END
         ELSE IF @nCount = 4
         BEGIN
            SET @cItem4 = @cCode
         END
         ELSE IF @nCount = 5
         BEGIN
            SET @cItem5 = @cCode
         END
         ELSE IF @nCount = 6
         BEGIN
            SET @cItem6 = @cCode
         END
         ELSE IF @nCount = 7
         BEGIN
            SET @cItem7 = @cCode
         END

         SET @nCount = @nCount + 1

         FETCH NEXT FROM CursorCodeLkup INTO @cCode
      END
      CLOSE CursorCodeLkup
      DEALLOCATE CursorCodeLkup

    -- Prepare Next Screen Variable
      SET @cOutField01 = @cItem1
      SET @cOutField03 = @cItem2
      SET @cOutField05 = @cItem3
      SET @cOutField07 = @cItem4
      SET @cOutField09 = @cItem5
      SET @cOutField11 = @cItem6
      SET @cOutField13 = @cItem7

      SET @cOutField02 = ''
      SET @cOutField04 = ''
      SET @cOutField06 = ''
      SET @cOutField08 = ''
      SET @cOutField10 = ''
      SET @cOutField12 = ''
      SET @cOutField14 = ''

      EXEC rdt.rdtSetFocusField @nMobile, 2 -- QTY

      SET @nScn = @nScn + 1
      SET @nStep = @nStep + 1
   END  -- Inputkey = 1

   IF @nInputKey = 0
   BEGIN
      SET @cOutfield01 = '' -- UCC
      SET @cOutfield02 = '' -- ID
      SET @cOutfield03 = '' -- Carton type
      
      EXEC rdt.rdtSetFocusField @nMobile, 1 -- UCC

      SET @nScn = @nScn - 1
      SET @nStep = @nStep - 1
   END
   GOTO Quit

   STEP_2_FAIL:
   BEGIN
      SET @cOutField03 = ''
      SET @cOutField06 = ''
   END
END
GOTO QUIT


/********************************************************************************
Step 3. Scn = 4002.
   Item1 (field01 , field02 Input)
   Item1 (field03 , field04 Input)
   Item1 (field05 , field06 Input)
   Item1 (field07 , field08 Input)
   Item1 (field09 , field10 Input)
   Item1 (field11 , field12 Input)
   Item1 (field13 , field14 Input)
********************************************************************************/
Step_3:
BEGIN
   IF @nInputKey = 1
   BEGIN
      SET @cItemValue1 = ISNULL(RTRIM(@cInField02),'0')
      SET @cItemValue2 = ISNULL(RTRIM(@cInField04),'0')
      SET @cItemValue3 = ISNULL(RTRIM(@cInField06),'0')
      SET @cItemValue4 = ISNULL(RTRIM(@cInField08),'0')
      SET @cItemValue5 = ISNULL(RTRIM(@cInField10),'0')
      SET @cItemValue6 = ISNULL(RTRIM(@cInField12),'0')
      SET @cItemValue7 = ISNULL(RTRIM(@cInField14),'0')

      IF @cItemValue1 <> '' AND ISNUMERIC(@cItemValue1) <> 1
      BEGIN
         SET @nErrNo = 92106
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Invalid Qty
         GOTO Step_3_Fail
      END

      IF @cItemValue2 <> '' AND ISNUMERIC(@cItemValue2) <> 1
      BEGIN
         SET @nErrNo = 92107
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Invalid Qty
         GOTO Step_3_Fail
      END

      IF @cItemValue3 <> '' AND ISNUMERIC(@cItemValue3) <> 1
      BEGIN
         SET @nErrNo = 92108
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Invalid Qty
         GOTO Step_3_Fail
      END

      IF @cItemValue4 <> '' AND ISNUMERIC(@cItemValue4) <> 1
      BEGIN
         SET @nErrNo = 92109
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Invalid Qty
         GOTO Step_3_Fail
      END

      IF @cItemValue5 <> '' AND ISNUMERIC(@cItemValue5) <> 1
      BEGIN
         SET @nErrNo = 92110
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Invalid Qty
         GOTO Step_3_Fail
      END

      IF @cItemValue6 <> '' AND ISNUMERIC(@cItemValue6) <> 1
      BEGIN
         SET @nErrNo = 92111
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Invalid Qty
         GOTO Step_3_Fail
      END

      IF @cItemValue7 <> '' AND ISNUMERIC(@cItemValue7) <> 1
      BEGIN
         SET @nErrNo = 92112
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Invalid Qty
         GOTO Step_3_Fail
      END

      -- INSERT INTO DATA Capture --
      INSERT INTO RDT.RDTDataCapture
         (StorerKey, Facility, V_SKU, V_Qty, V_UCC, V_ID, V_Zone,
          V_String1, V_String2, V_String3, V_String4, V_String5, V_String6, V_String7 )
      VALUES
         (@cStorerKEy, @cFacility, @cSKU, @cActualQty, @cUCC, @cID, @cCartonType,
          @cItemValue1, @cItemValue2, @cItemValue3, @cItemValue4, @cItemValue5, @cItemValue6, @cItemValue7 )

      IF @@ERROR <> 0
      BEGIN
         SET @nErrNo = 92114
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --InsDataCapFail
         GOTO Step_3_Fail
      END

      SET @nTotalUCCSKUCapture = 0
      SET @nTotalUCCSKU = 0

      SELECT @nTotalUCCSKU = Count(Distinct SKU)
      FROM dbo.UCC WITH (NOLOCK)
      WHERE UCCNo = @cUCC
      AND StorerKey = @cStorerKey

      SELECT @nTotalUCCSKUCapture = Count(Distinct V_SKU)
      FROM RDT.RDTDataCapture WITH (NOLOCK)
      WHERE V_UCC = @cUCC
      AND StorerKey = @cStorerKey

      IF @nTotalUCCSKU = @nTotalUCCSKUCapture
      BEGIN
         SET @cOutField01 = ''
         SET @cOutField02 = ''
         SET @cOutField03 = ''
         SET @cSKU        = ''

         EXEC rdt.rdtSetFocusField @nMobile, 1 -- UCC
         
         SET @nScn = @nScn - 2
         SET @nStep = @nStep - 2
      END
      ELSE
      BEGIN
         SET @cOutField01 = @cUCC
         SET @cOutField02 = @cID
         SET @cOutField03 = '' -- SKU
         SET @cOutField04 = '' -- SKU
         SET @cOutField05 = '' -- EXP QTY
         SET @cOutField06 = '' -- ACT QTY

         SET @nScn = @nScn - 1
         SET @nStep = @nStep - 1

         EXEC rdt.rdtSetFocusField @nMobile, 3 -- SKU
      END
   END

   IF @nInputKey = 0
   BEGIN
      SET @cOutfield01 = @cUCC
      SET @cOutfield02 = @cID
      SET @cOutfield03 = ''
      SET @cOutfield04 = ''
      SET @cOutfield05 = ''
      SET @cOutfield06 = ''

      EXEC rdt.rdtSetFocusField @nMobile, 3 -- SKU

      SET @nScn = @nScn - 1
      SET @nStep = @nStep - 1
   END
   GOTO Quit

   STEP_3_FAIL:
   BEGIN
      SET @cOutField01 = @cItem1
      SET @cOutField03 = @cItem2
      SET @cOutField05 = @cItem3
      SET @cOutField07 = @cItem4
      SET @cOutField09 = @cItem5
      SET @cOutField11 = @cItem6
      SET @cOutField13 = @cItem7

      SET @cOutField02 = @cItemValue1
      SET @cOutField04 = @cItemValue2
      SET @cOutField06 = @cItemValue3
      SET @cOutField08 = @cItemValue4
      SET @cOutField10 = @cItemValue5
      SET @cOutField12 = @cItemValue6
      SET @cOutField14 = @cItemValue7

      EXEC rdt.rdtSetFocusField @nMobile, 2
   END

END
GOTO QUIT


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
      InputKey  = @nInputKey,

      V_UOM      = @cPUOM,
      V_UCC      = @cUCC,
      V_SKU      = @cSKU,
      V_ID       = @cID,

      V_String1   =   @cItemValue1,
      V_String2   =   @cItemValue2,
      V_String3   =   @cItemValue3,
      V_String4   =   @cItemValue4,
      V_String5   =   @cItemValue5,
      V_String6   =   @cItemValue6,
      V_String7   =   @cItemValue7,

      V_String11  =  @cItem1,
      V_String12  =  @cItem2,
      V_String13  =  @cItem3,
      V_String14  =  @cItem4,
      V_String15  =  @cItem5,
      V_String16  =  @cItem6,
      V_String17  =  @cItem7,

      --V_String21 = @nQty,
      V_String22 = @cCartonType,
      V_String23 = @cActualQty,
      
      V_String31 = @cSkipCheckUCCInUCCTable,
      V_String32 = @cDecodeIDSP, 
      
      V_Integer1 = @nQty,

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