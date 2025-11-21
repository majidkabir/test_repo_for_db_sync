SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO



/************************************************************************/
/* Copyright: MAERSK                                                    */
/* Purpose: inquiry the serialno information                            */
/*                                                                      */
/* Modifications log:                                                   */
/*                                                                      */
/* Date       Rev  Author      Purposes                                 */
/* 2017/12/04 1.0  Yee Kung    3548-Initial document create             */
/* 2018/10/05 1.1  TungGH      Performance                              */
/* 2020/03/20 1.2  James       WMS-12577 Show newest serialno record    */
/*                             (max serialnokey) (james01)              */
/* 2023/12/01 1.3  James       WMS-24256 Add display Loc (james02)      */
/*                             Revamp the info display on screen 2      */
/*                             ExtInfoSP only display 3 lines           */
/************************************************************************/

CREATE   PROC [RDT].[rdtfnc_SerialNo_Inquiry] (
   @nMobile    INT,
   @nErrNo     INT  OUTPUT,
   @cErrMsg    NVARCHAR(1024) OUTPUT -- screen limitation, 20 char max
)
AS
SET NOCOUNT ON
SET QUOTED_IDENTIFIER OFF
SET ANSI_NULLS OFF
SET CONCAT_NULL_YIELDS_NULL OFF


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

   @cSerialNo  NVARCHAR (60),
   @cSKU       NVARCHAR (20),
   @cSKUDescr  NVARCHAR (40),
   @cID        NVARCHAR (20),

   @cExtendedInfoSP NVARCHAR(20),
   @cExtendedInfo1 NVARCHAR(20),
   @cExtendedInfo2 NVARCHAR(20),
   @cExtendedInfo3 NVARCHAR(20),
   @cExtendedInfo4 NVARCHAR(20),
   @cExtendedInfo5 NVARCHAR(20),
   @cExtendedInfo6 NVARCHAR(20),

   @cSQL          NVARCHAR(MAX),
   @cSQLParam     NVARCHAR(MAX),
   @cLoc          NVARCHAR( 10),
   @cSNoStatus    NVARCHAR( 10),
   
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

   @cSKU       = V_SKU,
   @cSKUDescr  = V_SKUDescr,
   @cID        = V_ID,
   @cLoc       = V_LOC,
   
   @cExtendedInfo1 = V_String1,
   @cExtendedInfo2 = V_String2,
   @cExtendedInfo3 = V_String3,
   @cExtendedInfo4 = V_String4,
   @cExtendedInfo5 = V_String5,
   @cExtendedInfo6 = V_String6,
   @cExtendedInfoSP = V_String7,
   @cSNoStatus    = V_String8,
   @cSerialNo     = V_String41,

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

FROM RDT.RDTMOBREC WITH (NOLOCK)
WHERE Mobile = @nMobile

IF @nFunc = 627 -- Serial No inquiry
BEGIN
   -- Redirect to respective screen
   IF @nStep = 0 GOTO Step_0   -- Inquiry by serialno
   IF @nStep = 1 GOTO Step_1   -- Scn = 5090. SERIALNO
   IF @nStep = 2 GOTO Step_2   -- Scn = 5091. SERIALNO,SKU,SKUDECR,ID,STATUS
END

--RETURN -- Do nothing if incorrect step

/********************************************************************************
Step 0. func = 627. Menu
********************************************************************************/
Step_0:
BEGIN

   -- Set the entry point
   SET @nScn  = 5090
   SET @nStep = 1

   SET @cExtendedInfoSP = rdt.RDTGetConfig( @nFunc, 'ExtendedInfoSP', @cStorerkey)
   IF @cExtendedInfoSP = ' '
      SET @cExtendedInfoSP = ''

   -- Initiate var
   SET @cSerialNo = ''
   -- Init screen
   SET @cOutField01 = '' -- LOC
END
GOTO Quit

/********************************************************************************
Step 1. Scn = 5090. SERIALNO
   SERIALNO:     (field01, input)
********************************************************************************/

Step_1:
BEGIN
   IF @nInputKey = 1 --ENTER
   BEGIN

      --Screen Mapping
      SET @cSerialNo = @cInField01;

      --Validate Blank
      IF @cSerialNo ='' OR @cSerialNo IS NULL
      BEGIN
         SET @nErrNo  = 117601
         SET @cErrMsg = rdt.rdtgetmessage(@nErrNo,@cLangCode,'DSP') --SerialNoReq
         EXEC rdt.rdtSetFocusField @nMobile, 1
         GOTO Step1_fail
      END

      -- (james01)
      SELECT TOP 1
         @cSKU = SKU,
         @cID = ID,
         @cSNoStatus = [Status]
      FROM dbo.SerialNo WITH (NOLOCK)
      WHERE Serialno = @cSerialNo
      ORDER BY SerialNoKey DESC

      -- Validate Serial No
      IF @@ROWCOUNT = 0
      BEGIN
         SET @nErrNo  = 117602
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --'SRNoNotExist'
         EXEC rdt.rdtSetFocusField @nMobile, 1
         GOTO Step1_Fail
      END

      SELECT @cSKUDescr = DESCR 
      FROM dbo.SKU WITH (NOLOCK) 
      WHERE StorerKey = @cStorerKey
      AND   SKU = @cSKU

      SELECT TOP 1 
         @cLoc = LLI.Loc
      FROM dbo.LOTxLOCxID LLI WITH (NOLOCK)
      JOIN dbo.LOC LOC WITH (NOLOCK) ON LLI.Loc = LOC.Loc
      WHERE LLI.StorerKey = @cStorerKey
      AND   LLI.Id = @cID
      AND   LLI.Sku = @cSKU
      AND   LOC.Facility = @cFacility
      ORDER BY 1
      
      SET @cOutField01 = SUBSTRING( @cSerialNo, 1, 20) --SerialNo Line#1
      SET @cOutField02 = SUBSTRING( @cSerialNo, 21, 10) --SerialNo Line#2
      SET @cOutField03 = @cSKU --SKU
      SET @cOutField04 = rdt.rdtFormatString(@cSKUDescr, 1, 20) --sku decription
      SET @cOutField05 = rdt.rdtFormatString(@cSKUDescr, 21, 20)  --sku decription
      SET @cOutField06 = @cLoc
      SET @cOutField07 = CASE WHEN LEN( @cID) <= 16 THEN ': ' + @cID 
                              WHEN LEN( @cID) = 17 THEN ':' + @cID
                              ELSE @cID
                         END
      SET @cOutField08 = CASE WHEN @cSNoStatus = '0' THEN '0 = OPEN'
                              WHEN @cSNoStatus = '1' THEN '1 = RECEIVED'
                              WHEN @cSNoStatus = '2' THEN '2 = ALLOC'
                              WHEN @cSNoStatus = '3' THEN '3 = REPLEN'
                              WHEN @cSNoStatus = '5' THEN '5 = PICKED'
                              WHEN @cSNoStatus = '6' THEN '6 = PACKED'
                              WHEN @cSNoStatus = '9' THEN '9 = SHIPPED'
                              ELSE 'ERR STATUS'
                         END
      SET @cExtendedInfo1 = ''
      SET @cExtendedInfo2 = ''
      SET @cExtendedInfo3 = ''

      IF @cExtendedInfoSP <> ''
      BEGIN
         IF EXISTS( SELECT 1 FROM dbo.sysobjects WHERE name = @cExtendedInfoSP AND type = 'P')
         BEGIN
            SET @cSQL =
            'EXEC rdt.' + RTRIM(@cExtendedInfoSP) +
            ' @nMobile, @nFunc, @cLangCode, @nStep, @nInputKey, @cStorerkey, @cSKU, @cID, @cSerialNo,'+
            ' @cExtendedInfo1 OUTPUT, @cExtendedInfo2 OUTPUT, @cExtendedInfo3 OUTPUT, @cExtendedInfo4 OUTPUT, @cExtendedInfo5 OUTPUT, @cExtendedInfo6 OUTPUT, @nErrNo OUTPUT, @cErrMsg OUTPUT'

            SET @cSQLParam =
            '@nMobile        INT,'+
            '@nFunc          INT,'+
            '@cLangCode      NVARCHAR( 3),'+
            '@nStep          INT,'+
            '@nInputKey      INT,'+
            '@cStorerkey     NVARCHAR( 15),'+
            '@cSKU           NVARCHAR( 20),'+
            '@cID            NVARCHAR( 20),'+
            '@cSerialNo      NVARCHAR( 20),'+
            '@cExtendedInfo1 NVARCHAR( 20) OUTPUT,'+
            '@cExtendedInfo2 NVARCHAR( 20) OUTPUT,'+
            '@cExtendedInfo3 NVARCHAR( 20) OUTPUT,'+
            '@cExtendedInfo4 NVARCHAR( 20) OUTPUT,'+
            '@cExtendedInfo5 NVARCHAR( 20) OUTPUT,'+
            '@cExtendedInfo6 NVARCHAR( 20) OUTPUT,'+
            '@nErrNo         INT            OUTPUT,'+
            '@cErrMsg        NVARCHAR( 20)  OUTPUT'

            EXEC sp_ExecuteSQL @cSQL, @cSQLParam,
                 @nMobile, @nFunc, @cLangCode, @nStep, @nInputKey, @cStorerkey, @cSKU, @cID,@cSerialNo
                 ,@cExtendedInfo1 OUTPUT ,@cExtendedInfo2 OUTPUT ,@cExtendedInfo3 OUTPUT
                 ,@cExtendedInfo4 OUTPUT ,@cExtendedInfo5 OUTPUT, @cExtendedInfo6 OUTPUT, @nErrNo OUTPUT, @cErrMsg OUTPUT

            SET @cOutField09 = @cExtendedInfo1
            SET @cOutField10 = @cExtendedInfo2
            SET @cOutField11 = @cExtendedInfo3
         END
      END

      -- Go to next screen
      SET @nScn  = @nScn + 1
      SET @nStep = @nStep + 1

	END

   IF @nInputKey = 0 --ESC
   BEGIN
      --go to main menu
      SET @nFunc       = @nMenu
      SET @nScn        = @nMenu
      SET @nStep       = 0
      SET @cOutField01 = '' --SerialNo
   END
   GOTO Quit

   Step1_fail:
   BEGIN
      SET @cOutField01= ''
      SET @cSerialNo  = ''
   END
END
GOTO Quit

/********************************************************************************
Step 2. Scn = 5091.
SerialNo1      (Field1)
SerialNo2      (Field2)
SKU            (Field3)
Description1   (Field4)
Description2   (Field5)
LOC            (Field6)
ID             (Field7)
Status         (Field8)
ExtendedInfo1  (Field9)
ExtendedInfo2  (Field10)
ExtendedInfo3  (Field11)
********************************************************************************/
Step_2:
BEGIN
   IF @nInputKey = 0 -- ESC
   BEGIN
      -- Prepare prev screen var
      SET @cSerialNo    = ' '
      SET @cOutField01  = ' ' --SerialNo
      SET @cOutField02  = ' ' --SerialNo
      SET @cOutField03  = ' ' --SKU
      SET @cOutField04  = ' ' --sku decription
      SET @cOutField05  = ' ' --sku decription
      SET @cOutField06  = ' ' --LOC
      SET @cOutField07  = ' ' --ID
      SET @cOutField08  = ' ' --Status
      SET @cOutField09  = ' ' --ExtendedInfo1
      SET @cOutField10  = ' ' --ExtendedInfo2
      SET @cOutField11  = ' ' --ExtendedInfo3


      -- Go to prev screen
      SET @nScn  = @nScn - 1
      SET @nStep = @nStep - 1
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
      EditDate   = GETDATE(),
      ErrMsg     = @cErrMsg,
      Func       = @nFunc,
      Step       = @nStep,
      Scn        = @nScn,

      StorerKey  = @cStorerKey,
      Facility   = @cFacility,
      Printer    = @cPrinter,

      V_SKU      = @cSKU       ,
      V_SKUDescr = @cSKUDescr  ,
      V_ID       = @cID        ,
      V_LOC      = @cLoc,
      
      V_String1  = @cExtendedInfo1,
      V_String2  = @cExtendedInfo2,
      V_String3  = @cExtendedInfo3,
      V_String4  = @cExtendedInfo4,
      V_String5  = @cExtendedInfo5,
      V_String6  = @cExtendedInfo6,
      V_String7  = @cExtendedInfoSP,
      V_String8  = @cSNoStatus,
      V_String41 = @cSerialNo  ,

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