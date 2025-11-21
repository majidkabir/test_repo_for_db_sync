SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/************************************************************************/
/* Store procedure: rdt_838SerialNoSP01                                 */
/* Copyright      : Maersk WMS                                          */
/*                                                                      */
/* Purpose: Custom SerialNo SP for In Forever                           */
/*                                                                      */
/* Date        Rev  Author       Purposes                               */
/* 2024-06-05  1.0  CYU027       FCR-340 Created                        */
/* 2024-06-14  1.1  JHU151       FCR-352 ZA_DEFY - Fn838 -Default Pick 
                                 Quantity                               */
/************************************************************************/

CREATE   PROCEDURE [RDT].[rdt_838SerialNoSP01]
   @nMobile          INT,
   @nFunc            INT,
   @cLangCode        NVARCHAR( 3),
   @nStep            INT,
   @nInputKey        INT,
   @cFacility        NVARCHAR( 3),
   @cStorerKey       NVARCHAR( 15),
   @cSKU             NVARCHAR( 20),
   @cSKUDesc         NVARCHAR( 60),
   @nQTY             INT,
   @cType            NVARCHAR( 15), --CHECK/UPDATE
   @cDocType         NVARCHAR( 10), --ASN/SO/PACK...
   @cDocNo           NVARCHAR( 20), --ReceiptKey/OrderKey/PickSlipNo...
   @cInField01       NVARCHAR( 60) OUTPUT,  @cOutField01 NVARCHAR( 60) OUTPUT,  @cFieldAttr01 NVARCHAR( 1) OUTPUT,
   @cInField02       NVARCHAR( 60) OUTPUT,  @cOutField02 NVARCHAR( 60) OUTPUT,  @cFieldAttr02 NVARCHAR( 1) OUTPUT,
   @cInField03       NVARCHAR( 60) OUTPUT,  @cOutField03 NVARCHAR( 60) OUTPUT,  @cFieldAttr03 NVARCHAR( 1) OUTPUT,
   @cInField04       NVARCHAR( 60) OUTPUT,  @cOutField04 NVARCHAR( 60) OUTPUT,  @cFieldAttr04 NVARCHAR( 1) OUTPUT,
   @cInField05       NVARCHAR( 60) OUTPUT,  @cOutField05 NVARCHAR( 60) OUTPUT,  @cFieldAttr05 NVARCHAR( 1) OUTPUT,
   @cInField06       NVARCHAR( 60) OUTPUT,  @cOutField06 NVARCHAR( 60) OUTPUT,  @cFieldAttr06 NVARCHAR( 1) OUTPUT,
   @cInField07       NVARCHAR( 60) OUTPUT,  @cOutField07 NVARCHAR( 60) OUTPUT,  @cFieldAttr07 NVARCHAR( 1) OUTPUT,
   @cInField08       NVARCHAR( 60) OUTPUT,  @cOutField08 NVARCHAR( 60) OUTPUT,  @cFieldAttr08 NVARCHAR( 1) OUTPUT,
   @cInField09       NVARCHAR( 60) OUTPUT,  @cOutField09 NVARCHAR( 60) OUTPUT,  @cFieldAttr09 NVARCHAR( 1) OUTPUT,
   @cInField10       NVARCHAR( 60) OUTPUT,  @cOutField10 NVARCHAR( 60) OUTPUT,  @cFieldAttr10 NVARCHAR( 1) OUTPUT,
   @cInField11       NVARCHAR( 60) OUTPUT,  @cOutField11 NVARCHAR( 60) OUTPUT,  @cFieldAttr11 NVARCHAR( 1) OUTPUT,
   @cInField12       NVARCHAR( 60) OUTPUT,  @cOutField12 NVARCHAR( 60) OUTPUT,  @cFieldAttr12 NVARCHAR( 1) OUTPUT,
   @cInField13       NVARCHAR( 60) OUTPUT,  @cOutField13 NVARCHAR( 60) OUTPUT,  @cFieldAttr13 NVARCHAR( 1) OUTPUT,
   @cInField14       NVARCHAR( 60) OUTPUT,  @cOutField14 NVARCHAR( 60) OUTPUT,  @cFieldAttr14 NVARCHAR( 1) OUTPUT,
   @cInField15       NVARCHAR( 60) OUTPUT,  @cOutField15 NVARCHAR( 60) OUTPUT,  @cFieldAttr15 NVARCHAR( 1) OUTPUT,
   @nMoreSNO         INT           OUTPUT,
   @cSerialNo        NVARCHAR( 60) OUTPUT,
   @nSerialQTY       INT           OUTPUT,
   @nErrNo           INT           OUTPUT,
   @cErrMsg          NVARCHAR( 20) OUTPUT,
   @nScn             INT = 0,
   @nBulkSNO         INT = 0       OUTPUT,
   @nBulkSNOQTY      INT = 0       OUTPUT,
   @cSerialCaptureType  NVARCHAR( 1) = '',
   @nScan            INT = 0       OUTPUT
AS
BEGIN

   DECLARE @nRowCount         INT
   DECLARE @cSQL              NVARCHAR( MAX)
   DECLARE @cSQLParam         NVARCHAR( MAX)
   DECLARE @cBarcode          NVARCHAR( MAX)
   DECLARE @nTotal            INT
   DECLARE @cUserDefine03     NVARCHAR(20)
   DECLARE @cUserDefine04     NVARCHAR(20)

   SET @nTotal = @nQTY -- Simplified

   -- Check serial no tally QTY
   IF @cType = 'CHECK'
   BEGIN

      SELECT TOP 1
         @cUserDefine03 = OD.UserDefine03,
         @cUserDefine04 = OD.UserDefine04
      FROM PICKHEADER PH WITH (NOLOCK)
         INNER JOIN ORDERDETAIL OD WITH (NOLOCK)
         ON PH.OrderKey = OD.OrderKey
      WHERE PH.PickHeaderKey = @cDocNo
        AND OD.Sku = @cSKU

      IF (@cUserDefine03 <> 'IsTagLoopRequired') OR ( @cUserDefine04 <> 'Y')
         GOTO QUIT

      -- Prepare next screen var
      SET @cOutField01 = @cSKU
      SET @cOutField02 = rdt.rdtFormatString( @cSKUDesc, 1, 20)  -- SKU desc 1
      SET @cOutField03 = rdt.rdtFormatString( @cSKUDesc, 21, 20) -- SKU desc 2
      SET @cOutField04 = '' -- SerialNo
      SET @cOutField05 = CAST( @nScan AS NVARCHAR(5)) + '/' + CAST( @nTotal AS NVARCHAR(5))

      EXEC rdt.rdtSetFocusField @nMobile, 3 -- SerialNo

      SET @cOutField15 = CAST( @nScan AS NVARCHAR(5)) -- Save scan to hidden field

      SET @nMoreSNO = 1 -- Need serial no
   END

   -- Update serial no
   IF @cType = 'UPDATE'
   BEGIN
      DECLARE @cDecodeSerialNoSP NVARCHAR( 20)
      DECLARE @cExtSNOValSP      NVARCHAR(20)
      DECLARE @cExtSNOUpdSP      NVARCHAR(20)
      DECLARE @cRetailSKU        NVARCHAR( 20)
      DECLARE @cAltSKU           NVARCHAR( 20)
      DECLARE @cManufacturerSKU  NVARCHAR( 20)

      -- Get SKU info
      SELECT
         @cAltSKU = AltSKU,
         @cRetailSKU = RetailSKU,
         @cManufacturerSKU = ManufacturerSKU
      FROM dbo.SKU WITH (NOLOCK)
      WHERE StorerKey = @cStorerKey
        AND SKU = @cSKU

      -- Get storer configure
      SET @cDecodeSerialNoSP = rdt.RDTGetConfig( @nFunc, 'DecodeSerialNoSP', @cStorerKey)
      IF @cDecodeSerialNoSP = '0'
         SET @cDecodeSerialNoSP = ''
      SET @cExtSNOValSP = rdt.RDTGetConfig( @nFunc, 'ExtendedSerialNoValidateSP', @cStorerKey)
      IF @cExtSNOValSP = '0'
         SET @cExtSNOValSP = ''
      SET @cExtSNOUpdSP = rdt.RDTGetConfig( @nFunc, 'ExtendedSerialNoUpdateSP', @cStorerKey)   --(yeekung01)
      IF @cExtSNOUpdSP = '0'
         SET @cExtSNOUpdSP = ''

      -- Screen mapping
      IF @nScn = 0 OR @nScn = 4830 -- For normal serial no screen
      BEGIN
         SET @cSerialNo = @cInField04
         SET @cBarcode = @cInField04
      END
      ELSE
      BEGIN
         -- For long serial no, 2D barcode
         UPDATE rdt.rdtMobRec SET
                                 @cSerialNo = LEFT( V_Max, 30),
                                 @cBarcode = V_Max,               -- Read the 2D barcode
                                 V_Max = '',                      -- Clear the field at same time
                                 EditDate = GETDATE()
         WHERE Mobile = @nMobile
      END
      SET @nScan = CAST( @cOutField15 AS INT)

      -- Decode serial no
      IF @cDecodeSerialNoSP <> ''
      BEGIN
         IF EXISTS( SELECT 1 FROM sys.objects WHERE name = @cDecodeSerialNoSP AND type = 'P')
         BEGIN
            SET @cSQL = 'EXEC rdt.' + RTRIM( @cDecodeSerialNoSP) +
                        ' @nMobile, @nFunc, @cLangCode, @nStep, @nInputKey, @cStorerKey, @cFacility, @cSKU, @cBarcode, ' +
                        ' @cSerialNo OUTPUT, @nSerialQTY OUTPUT, @nBulkSNO OUTPUT, @nErrNo OUTPUT, @cErrMsg OUTPUT '
            SET @cSQLParam =
                    ' @nMobile     INT,            ' +
                    ' @nFunc       INT,            ' +
                    ' @cLangCode   NVARCHAR( 3),   ' +
                    ' @nStep       INT,            ' +
                    ' @nInputKey   INT,            ' +
                    ' @cStorerKey  NVARCHAR( 15),  ' +
                    ' @cFacility   NVARCHAR( 5),   ' +
                    ' @cSKU        NVARCHAR( 20),  ' +
                    ' @cBarcode    NVARCHAR( MAX), ' +
                    ' @cSerialNo   NVARCHAR( 30)  OUTPUT, ' +
                    ' @nSerialQTY  INT            OUTPUT, ' +
                    ' @nBulkSNO    INT            OUTPUT, ' +
                    ' @nErrNo      INT            OUTPUT, ' +
                    ' @cErrMsg     NVARCHAR( 20)  OUTPUT  '

            EXEC sp_ExecuteSQL @cSQL, @cSQLParam,
                 @nMobile, @nFunc, @cLangCode, @nStep, @nInputKey, @cStorerKey, @cFacility, @cSKU, @cBarcode,
                 @cSerialNo OUTPUT, @nSerialQTY OUTPUT, @nBulkSNO OUTPUT, @nErrNo  OUTPUT, @cErrMsg  OUTPUT

            IF @nErrNo <> 0
               GOTO Quit
         END
      END

      -- Bulk serial no
      IF @nBulkSNO = 1
      BEGIN
         SET @cSerialNo = ''
         SET @nSerialQTY = 0
         SET @nBulkSNOQTY = 0

         DECLARE @cSNO NVARCHAR( 30)
         DECLARE @nSNO_QTY INT
         DECLARE @curSNO CURSOR
         SET @curSNO = CURSOR LOCAL READ_ONLY FAST_FORWARD FOR
            SELECT SerialNo, QTY
            FROM rdt.rdtReceiveSerialNoLog WITH (NOLOCK)
            WHERE Mobile = @nMobile
              AND Func = @nFunc
         OPEN @curSNO
         FETCH NEXT FROM @curSNO INTO @cSNO, @nSNO_QTY
         WHILE @@FETCH_STATUS = 0
         BEGIN

            -- Extended update
            IF @cExtSNOUpdSP <> ''
            BEGIN
               SET @cSQL = 'EXEC rdt.' + RTRIM( @cExtSNOUpdSP) +
                           ' @nMobile, @nFunc, @cLangCode, @nStep, @nInputKey, @cFacility, @cStorerkey, ' +
                           ' @cSKU, @nQTY, @cSerialNo, @cType, @cDocType, @cDocNo, @nErrNo OUTPUT, @cErrMsg OUTPUT '

               SET @cSQLParam =
                       '@nMobile      INT,           ' +
                       '@nFunc        INT,           ' +
                       '@cLangCode    NVARCHAR( 3),  ' +
                       '@nStep        INT,           ' +
                       '@nInputKey    INT,           ' +
                       '@cFacility    NVARCHAR( 5),  ' +
                       '@cStorerkey   NVARCHAR( 15), ' +
                       '@cSKU         NVARCHAR( 20), ' +
                       '@nQTY         INT,           ' +
                       '@cSerialNo    NVARCHAR( 30), ' +
                       '@cType        NVARCHAR( 15), ' +
                       '@cDocType     NVARCHAR( 10), ' +
                       '@cDocNo       NVARCHAR( 20), ' +
                       '@nErrNo       INT           OUTPUT, ' +
                       '@cErrMsg      NVARCHAR( 20) OUTPUT  '

               EXEC sp_ExecuteSQL @cSQL, @cSQLParam,
                    @nMobile, @nFunc, @cLangCode, @nStep, @nInputKey, @cFacility, @cStorerKey,
                    @cSKU, @nSNO_QTY, @cSNO, @cType, @cDocType, @cDocNo, @nErrNo OUTPUT, @cErrMsg OUTPUT

               IF @nErrNo <> 0
                  GOTO Quit
            END


            -- Extended validate
            IF @cExtSNOValSP <> ''
            BEGIN
               SET @cSQL = 'EXEC rdt.' + RTRIM( @cExtSNOValSP) +
                           ' @nMobile, @nFunc, @cLangCode, @nStep, @nInputKey, @cFacility, @cStorerkey, ' +
                           ' @cSKU, @nQTY, @cSerialNo, @cType, @cDocType, @cDocNo, @nErrNo OUTPUT, @cErrMsg OUTPUT '

               SET @cSQLParam =
                       '@nMobile      INT,           ' +
                       '@nFunc        INT,           ' +
                       '@cLangCode    NVARCHAR( 3),  ' +
                       '@nStep        INT,           ' +
                       '@nInputKey    INT,           ' +
                       '@cFacility    NVARCHAR( 5),  ' +
                       '@cStorerkey   NVARCHAR( 15), ' +
                       '@cSKU         NVARCHAR( 20), ' +
                       '@nQTY         INT,           ' +
                       '@cSerialNo    NVARCHAR( 30), ' +
                       '@cType        NVARCHAR( 15), ' +
                       '@cDocType     NVARCHAR( 10), ' +
                       '@cDocNo       NVARCHAR( 20), ' +
                       '@nErrNo       INT           OUTPUT, ' +
                       '@cErrMsg      NVARCHAR( 20) OUTPUT  '

               EXEC sp_ExecuteSQL @cSQL, @cSQLParam,
                    @nMobile, @nFunc, @cLangCode, @nStep, @nInputKey, @cFacility, @cStorerKey,
                    @cSKU, @nSNO_QTY, @cSNO, @cType, @cDocType, @cDocNo, @nErrNo OUTPUT, @cErrMsg OUTPUT

               IF @nErrNo <> 0
                  GOTO Quit
            END

            -- Calc scanned (simplified)
            SET @nScan = @nScan + 1
            SET @nBulkSNOQTY = @nBulkSNOQTY + @nSNO_QTY

            FETCH NEXT FROM @curSNO INTO @cSNO, @nSNO_QTY
         END
      END

         -- Single serial no
      ELSE
      BEGIN
         -- Check blank
         IF @cSerialNo = ''
         BEGIN
            SET @nErrNo = 108951
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Need SerialNo
            GOTO Quit
         END

         -- Check barcode format
         IF rdt.rdtIsValidFormat( @nFunc, @cStorerKey, 'SerialNo', @cSerialNo) = 0
         BEGIN
            SET @nErrNo = 108952
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Invalid Format
            GOTO Quit
         END

		 --JHU151
		 -- Exist Check in serial table
		 IF rdt.RDTGetConfig( @nFunc, 'ValidateSerialNo', @cStorerkey) = '1'
		 BEGIN
			 IF NOT EXISTS(SELECT 1 FROM SerialNo WHERE StorerKey = @cStorerKey AND SKU = @cSKU AND SerialNo = @cSerialNo)			
			 BEGIN
				SET @nErrNo = 217210
				--SET @cErrMsg = 'not ' + @cSerialNo
				SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') -- serial does not exists
				GOTO Quit
			 END
		 END

         -- Check serial no is SKU barcode
         IF @cSKU = @cSerialNo OR
            @cAltSKU = @cSerialNo OR
            @cRetailSKU = @cSerialNo OR
            @cManufacturerSKU = @cSerialNo
         BEGIN
            SET @nErrNo = 108954
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Invalid SNO
            GOTO Quit
         END

         -- Check serial no is UPC barcode
         IF EXISTS( SELECT TOP 1 1 FROM UPC WHERE StorerKey = @cStorerKey AND SKU = @cSKU AND UPC = @cSerialNo)
         BEGIN
            SET @nErrNo = 108955
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Invalid SNO
            GOTO Quit
         END

         -- Extended update
         IF @cExtSNOUpdSP <> ''
         BEGIN
            SET @cSQL = 'EXEC rdt.' + RTRIM( @cExtSNOUpdSP) +
                        ' @nMobile, @nFunc, @cLangCode, @nStep, @nInputKey, @cFacility, @cStorerkey, ' +
                        ' @cSKU, @nQTY, @cSerialNo, @cType, @cDocType, @cDocNo, @nErrNo OUTPUT, @cErrMsg OUTPUT '

            SET @cSQLParam =
                    '@nMobile      INT,           ' +
                    '@nFunc        INT,           ' +
                    '@cLangCode    NVARCHAR( 3),  ' +
                    '@nStep        INT,           ' +
                    '@nInputKey    INT,           ' +
                    '@cFacility    NVARCHAR( 5),  ' +
                    '@cStorerkey   NVARCHAR( 15), ' +
                    '@cSKU         NVARCHAR( 20), ' +
                    '@nQTY         INT,           ' +
                    '@cSerialNo    NVARCHAR( 30), ' +
                    '@cType        NVARCHAR( 15), ' +
                    '@cDocType     NVARCHAR( 10), ' +
                    '@cDocNo       NVARCHAR( 20), ' +
                    '@nErrNo       INT           OUTPUT, ' +
                    '@cErrMsg      NVARCHAR( 20) OUTPUT  '

            EXEC sp_ExecuteSQL @cSQL, @cSQLParam,
                 @nMobile, @nFunc, @cLangCode, @nStep, @nInputKey, @cFacility, @cStorerKey,
                 @cSKU, @nSerialQTY, @cSerialNo, @cType, @cDocType, @cDocNo, @nErrNo OUTPUT, @cErrMsg OUTPUT

            IF @nErrNo <> 0
               GOTO Quit
         END

         -- Extended validate
         IF @cExtSNOValSP <> ''
         BEGIN
            SET @cSQL = 'EXEC rdt.' + RTRIM( @cExtSNOValSP) +
                        ' @nMobile, @nFunc, @cLangCode, @nStep, @nInputKey, @cFacility, @cStorerkey, ' +
                        ' @cSKU, @nQTY, @cSerialNo, @cType, @cDocType, @cDocNo, @nErrNo OUTPUT, @cErrMsg OUTPUT '

            SET @cSQLParam =
                    '@nMobile      INT,           ' +
                    '@nFunc        INT,           ' +
                    '@cLangCode    NVARCHAR( 3),  ' +
                    '@nStep        INT,           ' +
                    '@nInputKey    INT,           ' +
                    '@cFacility    NVARCHAR( 5),  ' +
                    '@cStorerkey   NVARCHAR( 15), ' +
                    '@cSKU         NVARCHAR( 20), ' +
                    '@nQTY         INT,           ' +
                    '@cSerialNo    NVARCHAR( 30), ' +
                    '@cType        NVARCHAR( 15), ' +
                    '@cDocType     NVARCHAR( 10), ' +
                    '@cDocNo       NVARCHAR( 20), ' +
                    '@nErrNo       INT           OUTPUT, ' +
                    '@cErrMsg      NVARCHAR( 20) OUTPUT  '

            EXEC sp_ExecuteSQL @cSQL, @cSQLParam,
                 @nMobile, @nFunc, @cLangCode, @nStep, @nInputKey, @cFacility, @cStorerKey,
                 @cSKU, @nQTY, @cSerialNo, @cType, @cDocType, @cDocNo, @nErrNo OUTPUT, @cErrMsg OUTPUT

            IF @nErrNo <> 0
               GOTO Quit
         END

         -- Calc scanned (simplified)
         SET @nScan = @nScan + 1
         SET @nSerialQTY = 1
      END

      -- Check need serial no
      IF @nScan <> @nTotal AND @nTotal <> 0
      BEGIN
         -- Prepare next screen var
         SET @cOutField01 = @cSKU
         SET @cOutField02 = rdt.rdtFormatString( @cSKUDesc, 1, 20)  -- SKU desc 1
         SET @cOutField03 = rdt.rdtFormatString( @cSKUDesc, 21, 20) -- SKU desc 2
         SET @cOutField04 = '' -- SerialNo
         SET @cOutField05 = CAST( @nScan AS NVARCHAR(5)) + '/' + CAST( @nTotal AS NVARCHAR(5))

         EXEC rdt.rdtSetFocusField @nMobile, 3 -- SerialNo

         SET @cOutField15 = CAST( @nScan AS NVARCHAR(5)) -- Save scan to hidden field
         SET @nMoreSNO = 1 -- Need serial no
      END
      ELSE
         SET @nMoreSNO = 0 -- Don't need serial no

   END



   Quit:

END

GO