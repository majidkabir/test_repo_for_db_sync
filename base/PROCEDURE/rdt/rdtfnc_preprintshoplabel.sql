SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
/*****************************************************************************/
/* Store procedure: rdtfnc_PrePrintShopLabel                                 */
/* Copyright      : IDS                                                      */
/*                                                                           */
/* Purpose: SOS#257607                                                       */
/*                                                                           */
/* Modifications log:                                                        */
/*                                                                           */
/* Date       Rev  Author   Purposes                                         */
/* 2012-10-05 1.0  James    Created                                          */
/* 2012-11-28 1.1  James    Enhancement (james01)                            */
/* 2012-12-10 1.2  James    Enhancement (james02)                            */
/* 2013-05-08 1.3  James    SOS276805 - Fix print seq (james02)              */
/* 2013-08-27 1.4  James    SOS287522 - Label format change (james03)        */
/* 2013-10-27 1.5  James    SOS293347 - Add label type (james04)             */
/* 2014-05-05 1.6  James    SOS307345 - Add custom sp to build label(james05)*/
/* 2014-10-28 1.7  James    SOS324404 Extend var length (james06)            */   
/* 2016-09-30 1.8  Ung      Performance tuning                               */
/* 2018-11-08 1.9  TungGH   Performance                                      */  
/*****************************************************************************/

CREATE PROC [RDT].[rdtfnc_PrePrintShopLabel](
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
   @cPrinter            NVARCHAR(10),
   @cPrinter_Paper      NVARCHAR(10),
   @cUserName           NVARCHAR(18),

   @cStorerKey          NVARCHAR(15),
   @cFacility           NVARCHAR(5),

   @cReportType         NVARCHAR(10),
   @cPrintJobName       NVARCHAR(50),
   @cDataWindow         NVARCHAR(50),
   @cTargetDB           NVARCHAR(20),

   @cShopNo             NVARCHAR(6),   -- (james06)
   @cSection            NVARCHAR(5),
   @cSeparate           NVARCHAR(5),
   @cPrintQty           NVARCHAR(5),
   @cDistCenter         NVARCHAR(6),   -- (james06)
   @cBultoNo            NVARCHAR(5),
   @cMaxBultoNo         NVARCHAR(5),
   @cMinBultoNo         NVARCHAR(5),
   @cCheckDigit         NVARCHAR(1),
   @cPrintBarFrom       NVARCHAR(20),
   @cPrintBarTo         NVARCHAR(20),
   @cTempBarcodeFrom    NVARCHAR(20),
   @cTempBarcodeTo      NVARCHAR(20),
   @cCode               NVARCHAR(30),
   @cUDF03              NVARCHAR(30),
   @cUDF04              NVARCHAR(30),
   @cLabelType          NVARCHAR(10),  -- (james04)
   @cShopLabelType      NVARCHAR(10),  -- (james04)

   @nPrintQty           INT,
   @nBultoNo            INT,
   @nNewBultoNo         INT,
   @nTranCount          INT,

   @cBuildLabelNo       NVARCHAR( 20),
   @cLabelNo_Out        NVARCHAR( 20),
   @cLoadKey            NVARCHAR( 10),
   @bSuccess            INT,

   @cInField01 NVARCHAR( 60),   @cOutField01 NVARCHAR( 60),
   @cInField02 NVARCHAR( 60),   @cOutField02 NVARCHAR( 60),
   @cInField03 NVARCHAR( 60),   @cOutField03 NVARCHAR( 60),
   @cInField04 NVARCHAR( 60),   @cOutField04 NVARCHAR( 60),
   @cInField05 NVARCHAR( 60),   @cOutField05 NVARCHAR( 60),
   @cInField06 NVARCHAR( 60),   @cOutField06 NVARCHAR( 60),
   @cInField07 NVARCHAR( 60), @cOutField07 NVARCHAR( 60),
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
   @cPrinter_Paper   = Printer_Paper,
   @cUserName        = UserName,

   @cShopNo          = V_String1,
   @cSection         = V_String2,
   @cSeparate        = V_String3,
   @cPrintQty        = V_String4,
   @cDistCenter      = V_String5,
   @cLabelType       = V_String6,
   @cShopLabelType   = V_String7,

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
IF @nFunc = 590
BEGIN
   IF @nStep = 0 GOTO Step_0   -- Menu. Func = 590
   IF @nStep = 1 GOTO Step_1   -- Scn = 3240   Shop no, section, separate, print qty
   IF @nStep = 2 GOTO Step_2   -- Scn = 3241   Confirm Print
END

RETURN -- Do nothing if incorrect step

/********************************************************************************
Step 0. Called from menu (func = 1634)
********************************************************************************/
Step_0:
BEGIN
   -- Set the entry point
   SET @nScn  = 3240
   SET @nStep = 1

   -- initialise all variable
   SET @cShopNo = ''
   SET @cSection = ''
   SET @cSeparate = ''
   SET @cPrintQty = ''

   -- Prep next screen var
   SET @cOutField01 = ''
   SET @cOutField02 = ''
   SET @cOutField03 = ''
   SET @cOutField04 = ''

   EXEC rdt.rdtSetFocusField @nMobile, 1
END
GOTO Quit

/********************************************************************************
Step 1. screen = 3240
   SHOP NO     (Field01, input)
   SECTION     (Field02, input)
   SEPARATE    (Field03, input)
   PRINT QTY   (Field04, input)
********************************************************************************/
Step_1:
BEGIN
   IF @nInputKey = 1 -- ENTER
   BEGIN
      -- Screen mapping
      SET @cStorerKey = @cInField01
      SET @cShopNo = @cInField02
      SET @cSection = @cInField03
      SET @cSeparate = @cInField04
      SET @cPrintQty = @cInField05
      SET @cLabelType = @cInField06

      IF ISNULL(@cStorerKey, '') = ''
      BEGIN
         SET @nErrNo = 77515
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --STORERKEY req
         SET @cShopNo = ''
         SET @cOutField01 = ''
         SET @cOutField02 = @cShopNo
         SET @cOutField03 = @cSection
         SET @cOutField04 = @cSeparate
         SET @cOutField05 = @cPrintQty
         SET @cOutField06 = @cLabelType
         EXEC rdt.rdtSetFocusField @nMobile, 1
         GOTO Quit
      END
      ELSE
      BEGIN
         IF NOT EXISTS (SELECT 1 FROM dbo.Storer WITH (NOLOCK)
                        WHERE StorerKey = @cStorerKey
                        AND   Type = '1')
         BEGIN
            SET @nErrNo = 77516
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --BAD STORERKEY
            SET @cShopNo = ''
            SET @cOutField01 = ''
            SET @cOutField02 = @cShopNo
            SET @cOutField03 = @cSection
            SET @cOutField04 = @cSeparate
            SET @cOutField05 = @cPrintQty
            SET @cOutField06 = @cLabelType
            EXEC rdt.rdtSetFocusField @nMobile, 1
            GOTO Quit
         END
      END

      -- Check whether the label type choosed   (james04)
      IF ISNULL( @cLabelType, '') = ''
      BEGIN
         SET @nErrNo = 77519
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --LABEL TYPE req
         SET @cLabelType = ''
         SET @cOutField06 = ''
         SET @cOutField01 = @cStorerKey
         SET @cOutField02 = @cShopNo
         SET @cOutField03 = @cSection
         SET @cOutField04 = @cSeparate
         SET @cOutField05 = @cPrintQty
         EXEC rdt.rdtSetFocusField @nMobile, 1
         GOTO Quit
      END

      -- Check valid label type
      IF NOT EXISTS (SELECT 1 FROM dbo.CodeLkUp WITH (NOLOCK)
                     WHERE ListName = 'SHOPLBLTYP'
                     AND   StorerKey = @cStorerKey
                     AND   Code = @cLabelType)
      BEGIN
         SET @nErrNo = 77520
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --INV LABEL TYPE
         SET @cLabelType = ''
         SET @cOutField06 = ''
         SET @cOutField01 = @cStorerKey
         SET @cOutField02 = @cShopNo
         SET @cOutField03 = @cSection
         SET @cOutField04 = @cSeparate
         SET @cOutField05 = @cPrintQty
         EXEC rdt.rdtSetFocusField @nMobile, 1
         GOTO Quit
      END
      ELSE
      BEGIN
         SELECT @cShopLabelType = Short,
                @cDistCenter = UDF01      -- (james04)
         FROM dbo.CodeLkUp WITH (NOLOCK)
         WHERE ListName = 'SHOPLBLTYP'
         AND   StorerKey = @cStorerKey
         AND   Code = @cLabelType

         IF ISNULL( @cShopLabelType, '') = ''
         BEGIN
            SET @nErrNo = 77521
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --SHOP LABEL REQ
            SET @cLabelType = ''
            SET @cOutField06 = ''
            SET @cOutField01 = @cStorerKey
            SET @cOutField02 = @cShopNo
            SET @cOutField03 = @cSection
            SET @cOutField04 = @cSeparate
            SET @cOutField05 = @cPrintQty
            EXEC rdt.rdtSetFocusField @nMobile, 1
            GOTO Quit
         END
      END

      IF ISNULL(@cShopNo, '') = ''
      BEGIN
         SET @nErrNo = 77501
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --SHOP NO req
         SET @cShopNo = ''
         SET @cOutField01 = @cStorerKey
         SET @cOutField02 = ''
         SET @cOutField03 = @cSection
         SET @cOutField04 = @cSeparate
         SET @cOutField05 = @cPrintQty
         SET @cOutField06 = @cLabelType
         EXEC rdt.rdtSetFocusField @nMobile, 1
         GOTO Quit
      END
      ELSE
      BEGIN
         IF NOT EXISTS (SELECT 1 FROM dbo.Storer WITH (NOLOCK)
                        WHERE StorerKey = 'ITX' + @cShopNo
                        AND   Type = 2)
         BEGIN
            SET @nErrNo = 77502
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --BAD SHOP NO
            SET @cShopNo = ''
            SET @cOutField01 = @cStorerKey
            SET @cOutField02 = ''
            SET @cOutField03 = @cSection
            SET @cOutField04 = @cSeparate
            SET @cOutField05 = @cPrintQty
            SET @cOutField06 = @cLabelType
            EXEC rdt.rdtSetFocusField @nMobile, 1
            GOTO Quit
         END
/*
         SELECT @cDistCenter = SUSR1
         FROM dbo.Storer WITH (NOLOCK)
         WHERE StorerKey = @cStorerKey
*/
         IF ISNULL(@cDistCenter, '') = ''
         BEGIN
            SET @nErrNo = 77513
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --BAD DIST CTR
            SET @cShopNo = ''
            SET @cOutField01 = @cStorerKey
            SET @cOutField02 = ''
            SET @cOutField03 = @cSection
            SET @cOutField04 = @cSeparate
            SET @cOutField05 = @cPrintQty
            SET @cOutField06 = @cLabelType
            EXEC rdt.rdtSetFocusField @nMobile, 1
            GOTO Quit
         END
         SET @cDistCenter = CASE WHEN LEN( RTRIM( @cDistCenter)) = 4 THEN  
                                    RIGHT( '0000' + RTRIM(LTRIM(@cDistCenter)), 4)  
                                 ELSE RIGHT( '000000' + RTRIM(LTRIM(@cDistCenter)), 6) END -- (james06)
         END

      IF ISNULL(@cSection, '') = ''
      BEGIN
         SET @nErrNo = 77503
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --SECTION req
         SET @cSection = ''
         SET @cOutField01 = @cStorerKey
         SET @cOutField02 = @cShopNo
         SET @cOutField03 = ''
         SET @cOutField04 = @cSeparate
         SET @cOutField05 = @cPrintQty
         SET @cOutField06 = @cLabelType
         EXEC rdt.rdtSetFocusField @nMobile, 2
         GOTO Quit
      END
      ELSE
      BEGIN
         IF NOT EXISTS (SELECT 1 FROM dbo.CODELKUP WITH (NOLOCK)
                        WHERE ListName = @cShopLabelType--'LABELNO'
                        AND   UDF01 = @cSection
                        AND   StorerKey = @cStorerKey)
         BEGIN
            SET @nErrNo = 77504
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --INVALID SECTION
            SET @cSection = ''
            SET @cOutField01 = @cStorerKey
            SET @cOutField02 = @cShopNo
            SET @cOutField03 = ''
            SET @cOutField04 = @cSeparate
            SET @cOutField05 = @cPrintQty
            SET @cOutField06 = @cLabelType
            EXEC rdt.rdtSetFocusField @nMobile, 2
            GOTO Quit
         END
      END
/*          IF ISNULL(@cSeparate, '') = ''
      BEGIN
         SET @nErrNo = 77505
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --SEPARATE req
         SET @cSeparate = ''
         SET @cOutField01 = @cStorerKey
         SET @cOutField02 = @cShopNo
         SET @cOutField03 = @cSection
         SET @cOutField04 = ''
         SET @cOutField05 = @cPrintQty
         EXEC rdt.rdtSetFocusField @nMobile, 3
         GOTO Quit
      END
      ELSE
      BEGIN
         IF NOT EXISTS (SELECT 1 FROM dbo.CODELKUP WITH (NOLOCK)
                        WHERE ListName = 'LABELNO'
                        AND   UDF01 = @cSection
                        AND   UDF02 = @cSeparate
                        AND   StorerKey = @cStorerKey)
         BEGIN
            SET @nErrNo = 77506
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --BAD SEPARATE
        SET @cSeparate = ''
            SET @cOutField01 = @cStorerKey
            SET @cOutField02 = @cShopNo
            SET @cOutField03 = @cSection
            SET @cOutField04 = ''
            SET @cOutField05 = @cPrintQty
            EXEC rdt.rdtSetFocusField @nMobile, 3
            GOTO Quit
         END
      END
*/
      IF ISNULL(@cPrintQty, '') = ''
      BEGIN
         SET @nErrNo = 77507
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --PRINT QTY req
         SET @cPrintQty = ''
         SET @cOutField01 = @cStorerKey
         SET @cOutField02 = @cShopNo
         SET @cOutField03 = @cSection
         SET @cOutField04 = @cSeparate
         SET @cOutField05 = ''
         SET @cOutField06 = @cLabelType
         EXEC rdt.rdtSetFocusField @nMobile, 4
         GOTO Quit
      END
      ELSE
      BEGIN
         IF RDT.rdtIsValidQTY( @cPrintQty, 1) = 0
         BEGIN
            SET @nErrNo = 77508
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --BAD PRINT QTY
            SET @cPrintQty = ''
            SET @cOutField01 = @cStorerKey
            SET @cOutField02 = @cShopNo
            SET @cOutField03 = @cSection
            SET @cOutField04 = @cSeparate
            SET @cOutField05 = ''
            SET @cOutField06 = @cLabelType
            EXEC rdt.rdtSetFocusField @nMobile, 4
            GOTO Quit
         END

         SET @nPrintQty = CAST(@cPrintQty AS INT)
      END

      IF NOT EXISTS (SELECT 1 FROM dbo.Storer A WITH (NOLOCK)
                     JOIN dbo.Storer B WITH (NOLOCK) ON (A.ConsigneeFor = B.Vat AND B.Type = '2')
                     WHERE A.StorerKey = @cStorerKey
                     AND   B.StorerKey = 'ITX' + @cShopNo)
      BEGIN
         SET @nErrNo = 77518
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --VAT<>CSNEEFOR
         SET @cOutField01 = @cStorerKey
         SET @cOutField02 = @cShopNo
         SET @cOutField03 = @cSection
         SET @cOutField04 = @cSeparate
         SET @cOutField05 = @nPrintQty
         SET @cOutField06 = @cLabelType
         EXEC rdt.rdtSetFocusField @nMobile, 4
         GOTO Quit
      END
      -- Generate first and last label
      /*
      Distribution Center  4 digits û storer.susr1
      Shop number  4 digits û user key in , shop number = storer.storerkey
      Section  1 digit û user key in
      Separate  1 digit û user key in
      Bult Number/Box   5 digits û Carton sequential number (Bulto/Box),please refer to the below point 1
      Check digit  1 digit û check digit barcode, please refer to the below point 2 java script,
      */

      IF EXISTS (SELECT 1
                 FROM dbo.CODELKUP WITH (NOLOCK)
                 WHERE ListName = @cShopLabelType--'LABELNO'
                 AND   UDF01 = RTRIM(@cSection)
                 --AND   UDF02 = RTRIM(@cSeparate)
                 AND   StorerKey = RTRIM(@cStorerKey)
                 AND   Long = RTRIM(@cShopNo))
      BEGIN
         SELECT @cBultoNo = UDF05,
                @cMinBultoNo = UDF03,
                @cMaxBultoNo = UDF04
         FROM dbo.CODELKUP WITH (NOLOCK)
         WHERE ListName = @cShopLabelType--'LABELNO'
         AND   UDF01 = RTRIM(@cSection)
         --AND   UDF02 = RTRIM(@cSeparate)
         AND   StorerKey = RTRIM(@cStorerKey)
         AND   Long = RTRIM(@cShopNo)

         --SET @cBultoNo = CAST(@cMinBultoNo AS INT) + CAST(@cBultoNo AS INT)

         -- 1st time setup or data error then reset
         IF ISNULL(@cBultoNo, '') = '' OR @cBultoNo = '0'
         BEGIN
            SET @nBultoNo = CAST(ISNULL(@cMinBultoNo, '') AS INT) + 1
         END
         ELSE
         BEGIN
            IF (CAST(@cBultoNo AS INT) + 1) > CAST(@cMaxBultoNo AS INT)
               SET @nBultoNo = CAST(@cMinBultoNo AS INT) + 1
            ELSE
               SET @nBultoNo = CAST(@cBultoNo AS INT) + 1
         END
      END
 ELSE
      BEGIN
         -- If not exists then copy from same storer + udf01 + udf02
         SELECT TOP 1 @nBultoNo = CAST(UDF03 AS INT) + 1
         FROM dbo.CODELKUP WITH (NOLOCK)
         WHERE ListName = @cShopLabelType--'LABELNO'
         AND   UDF01 = RTRIM(@cSection)
         --AND   UDF02 = RTRIM(@cSeparate)
         AND   StorerKey = RTRIM(@cStorerKey)
      END
      /*
      -- (james03)
      SET @cTempBarcodeFrom = ''
      SET @cTempBarcodeFrom = SUBSTRING(@cDistCenter, 1, 4)
      SET @cTempBarcodeFrom = RTRIM(@cTempBarcodeFrom) + RIGHT( '0000' + RTRIM(LTRIM(@cShopNo)), 4)
      SET @cTempBarcodeFrom = RTRIM(@cTempBarcodeFrom) + SUBSTRING(@cSection, 1, 1)
      SET @cTempBarcodeFrom = RTRIM(@cTempBarcodeFrom) + SUBSTRING(@cSeparate, 1, 1)
      SET @cTempBarcodeFrom = RTRIM(@cTempBarcodeFrom) + RIGHT( '00000' + CAST( @nBultoNo AS NVARCHAR( 5)), 5)
      SET @cCheckDigit = dbo.fnc_CalcCheckDigit_M10(RTRIM(@cTempBarcodeFrom), 0)
      SET @cTempBarcodeFrom = RTRIM(@cTempBarcodeFrom) + @cCheckDigit
      */
      -- (james05)
      SET @cBuildLabelNo = ''
      SET @cBuildLabelNo = rdt.RDTGetConfig( @nFunc, 'BuildLabelNo', @cStorerkey)

      IF ISNULL(@cBuildLabelNo,'') NOT IN ('', '0')
      BEGIN
         EXEC dbo.ispBuildShopLabel_Wrapper
             @c_SPName     = @cBuildLabelNo
            ,@c_LoadKey    = @cLoadKey
            ,@c_LabelType  = @cLabelType
            ,@c_StorerKey  = @cStorerKey
            ,@c_DistCenter = @cDistCenter
            ,@c_ShopNo     = @cShopNo
            ,@c_Section    = @cSection
            ,@c_Separate   = @cSeparate
            ,@n_BultoNo    = @nBultoNo
            ,@c_LabelNo    = @cLabelNo_Out   OUTPUT   -- Label out
            ,@b_Success    = @bSuccess       OUTPUT
            ,@n_ErrNo      = @nErrNo         OUTPUT
            ,@c_ErrMsg     = @cErrMsg        OUTPUT

         SET @cTempBarcodeFrom = @cLabelNo_Out
      END

      IF EXISTS (SELECT 1
                 FROM dbo.CODELKUP WITH (NOLOCK)
                 WHERE ListName = @cShopLabelType--'LABELNO'
                 AND   UDF01 = RTRIM(@cSection)
                 --AND   UDF02 = RTRIM(@cSeparate)
                 AND   StorerKey = RTRIM(@cStorerKey)
                 AND   Long = RTRIM(@cShopNo))
      BEGIN
         SELECT @cBultoNo = UDF05,
                @cMinBultoNo = UDF03,
                @cMaxBultoNo = UDF04
         FROM dbo.CODELKUP WITH (NOLOCK)
         WHERE ListName = @cShopLabelType--'LABELNO'
         AND   UDF01 = RTRIM(@cSection)
         --AND   UDF02 = RTRIM(@cSeparate)
         AND   StorerKey = RTRIM(@cStorerKey)
         AND   Long = RTRIM(@cShopNo)

         IF ISNULL(@cBultoNo, '') = '' OR @cBultoNo = '0'
         BEGIN
            SET @nBultoNo = CAST(@cMinBultoNo AS INT) + @nPrintQty
         END
         ELSE
         BEGIN
            IF (CAST(@cBultoNo AS INT) + @nPrintQty) > CAST(@cMaxBultoNo AS INT)
            BEGIN
               SET @nBultoNo = @nPrintQty - (CAST(@cMaxBultoNo AS INT) - (CAST(@cBultoNo AS INT)))
               SET @nBultoNo = CAST(@cMinBultoNo AS INT) + @nBultoNo
            END
            ELSE
               SET @nBultoNo = CAST(@cBultoNo AS INT) + @nPrintQty
         END
      END
      ELSE
      BEGIN
         -- If not exists then copy from same storer + udf01 + udf02
         SELECT TOP 1 @nBultoNo = CAST(UDF03 AS INT) + @nPrintQty
         FROM dbo.CODELKUP WITH (NOLOCK)
         WHERE ListName = @cShopLabelType--'LABELNO'
         AND   UDF01 = RTRIM(@cSection)
         --AND   UDF02 = RTRIM(@cSeparate)
         AND   StorerKey = RTRIM(@cStorerKey)
      END
      /*
      -- (james03)
      SET @cTempBarcodeTo = ''
      SET @cTempBarcodeTo = SUBSTRING(@cDistCenter, 1, 4)
      SET @cTempBarcodeTo = RTRIM(@cTempBarcodeTo) + RIGHT( '0000' + RTRIM(LTRIM(@cShopNo)), 4)
      SET @cTempBarcodeTo = RTRIM(@cTempBarcodeTo) + SUBSTRING(@cSection, 1, 1)
      SET @cTempBarcodeTo = RTRIM(@cTempBarcodeTo) + SUBSTRING(@cSeparate, 1, 1)
      SET @cTempBarcodeTo = RTRIM(@cTempBarcodeTo) + RIGHT( '00000' + CAST( @nBultoNo AS NVARCHAR( 5)), 5)
      SET @cCheckDigit = dbo.fnc_CalcCheckDigit_M10(RTRIM(@cTempBarcodeFrom), 0)
      SET @cTempBarcodeFrom = RTRIM(@cTempBarcodeFrom) + @cCheckDigit
      */

      -- (james05)
      SET @cBuildLabelNo = ''
      SET @cBuildLabelNo = rdt.RDTGetConfig( @nFunc, 'BuildLabelNo', @cStorerkey)

      IF ISNULL(@cBuildLabelNo,'') NOT IN ('', '0')
      BEGIN
         EXEC dbo.ispBuildShopLabel_Wrapper
             @c_SPName     = @cBuildLabelNo
            ,@c_LoadKey    = @cLoadKey
            ,@c_LabelType  = @cLabelType
            ,@c_StorerKey  = @cStorerKey
            ,@c_DistCenter = @cDistCenter
            ,@c_ShopNo     = @cShopNo
            ,@c_Section    = @cSection
            ,@c_Separate   = @cSeparate
            ,@n_BultoNo    = @nBultoNo
            ,@c_LabelNo    = @cLabelNo_Out   OUTPUT   -- Label out
            ,@b_Success    = @bSuccess       OUTPUT
            ,@n_ErrNo      = @nErrNo         OUTPUT
            ,@c_ErrMsg     = @cErrMsg        OUTPUT

         SET @cTempBarcodeTo = @cLabelNo_Out
      END

      --prepare next screen variable
      SET @cOutField01 = @cStorerKey
      SET @cOutField02 = @cShopNo
      SET @cOutField03 = @cSection
      SET @cOutField04 = @cSeparate
      SET @cOutField05 = @cPrintQty
      SET @cOutField06 = @cTempBarcodeFrom
      SET @cOutField07 = @cTempBarcodeTo
      SET @cOutField08 = @cLabelType

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

      SET @cOutField01 = ''
      SET @cOutField02 = ''
      SET @cOutField03 = ''
      SET @cOutField04 = ''

      SET @cShopNo = ''
      SET @cSection = ''
      SET @cSeparate = ''
      SET @cPrintQty = ''
   END
   GOTO Quit

END
GOTO Quit

/********************************************************************************
Step 2. screen = 3241
   SHOP NO     (Field01, input)
   SECTION     (Field02, input)
   SEPARATE    (Field03, input)
   PRINT QTY   (Field04, input)
********************************************************************************/
Step_2:
BEGIN
   IF @nInputKey = 1 -- ENTER
   BEGIN
      -- Screen mapping
      SET @cShopNo = @cInField02
      SET @cSection = @cInField03
      SET @cSeparate = @cInField04
      SET @cPrintQty = @cInField05

      SET @nPrintQty = CAST(@cPrintQty AS INT)

      -- Printing process
      -- Print the shop label
      IF ISNULL(@cPrinter, '') = ''
      BEGIN
         SET @nErrNo = 77509
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --NoLabelPrinter
         GOTO Quit
      END

      SELECT @cReportType = Long    -- (james04)
      FROM dbo.CodeLkUp WITH (NOLOCK)
      WHERE ListName = 'SHOPLBLTYP'
      AND   Code = @cLabelType
      AND   StorerKey = @cStorerKey

      --SET @cReportType = 'PRESHOPLBL'
      SET @cPrintJobName = 'PRINT_PRESHOPLBL'

      SELECT @cDataWindow = ISNULL(RTRIM(DataWindow), ''),
             @cTargetDB = ISNULL(RTRIM(TargetDB), '')
      FROM RDT.RDTReport WITH (NOLOCK)
      WHERE StorerKey = @cStorerKey
      AND   ReportType = @cReportType

      IF ISNULL(@cDataWindow, '') = ''
      BEGIN
         SET @nErrNo = 77510
       SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --DWNOTSETUP
         SET @nPrintQty = @cOutField04 -- Assign back the original print qty
         GOTO Quit
      END

      IF ISNULL(@cTargetDB, '') = ''
      BEGIN
         SET @nErrNo = 77511
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --TGETDB NOT SET
         SET @nPrintQty = @cOutField04 -- Assign back the original print qty
         GOTO Quit
      END

      SET @nErrNo = 0
      EXEC RDT.rdt_BuiltPrintJob
         @nMobile,
         @cStorerKey,
         @cReportType,
         @cPrintJobName,
         @cDataWindow,
         @cPrinter,
         @cTargetDB,
         @cLangCode,
         @nErrNo  OUTPUT,
         @cErrMsg OUTPUT,
         @cStorerKey,         -- (james02)
         @cDistCenter,
         @cSection,
         @cShopNo,
         @cSeparate,
         @nPrintQty,
         @cShopLabelType      -- (james04)

      IF @nErrNo <> 0
      BEGIN
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP')
         SET @nPrintQty = @cOutField04 -- Assign back the original print qty
         GOTO Quit
      END

      SET @nPrintQty = @cOutField04 -- Assign back the original print qty

      WHILE @@TRANCOUNT > @nTranCount
         COMMIT TRAN

      -- initialise all variable
      SET @cShopNo = ''
      SET @cSection = ''
      SET @cSeparate = ''
      SET @cPrintQty = ''

      -- Prep next screen var
      SET @cOutField01 = ''
      SET @cOutField02 = ''
      SET @cOutField03 = ''
      SET @cOutField04 = ''
      SET @cOutField05 = ''

      EXEC rdt.rdtSetFocusField @nMobile, 1

      -- Go back prev screen
      SET @nScn  = @nScn - 1
      SET @nStep = @nStep - 1
   END

   IF @nInputKey = 0 -- ESC
   BEGIN
      SET @cOutField01 = ''
      SET @cOutField02 = ''
      SET @cOutField03 = ''
      SET @cOutField04 = ''
      SET @cOutField05 = ''
      SET @cOutField06 = ''

      SET @cShopNo = ''
      SET @cSection = ''
      SET @cSeparate = ''
      SET @cPrintQty = ''
      SET @cPrintBarFrom = ''
      SET @cPrintBarTo = ''

      EXEC rdt.rdtSetFocusField @nMobile, 1

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
   UPDATE RDTMOBREC WITH (ROWLOCK) SET
       EditDate      = GETDATE(), 
       ErrMsg        = @cErrMsg,
       Func          = @nFunc,
       Step          = @nStep,
       Scn           = @nScn,

       StorerKey     = @cStorerKey,
       Facility      = @cFacility,
       Printer       = @cPrinter,
       Printer_Paper = @cPrinter_Paper,
       -- UserName      = @cUserName,

       V_String1     = @cShopNo,
       V_String2     = @cSection,
       V_String3     = @cSeparate,
       V_String4     = @cPrintQty,
       V_String5     = @cDistCenter,
       V_String6     = @cLabelType,
       V_String7     = @cShopLabelType,

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
      FieldAttr11  = @cFieldAttr11,  FieldAttr12  = @cFieldAttr12,
      FieldAttr13  = @cFieldAttr13,   FieldAttr14  = @cFieldAttr14,
      FieldAttr15  = @cFieldAttr15

   WHERE Mobile = @nMobile

END

GO