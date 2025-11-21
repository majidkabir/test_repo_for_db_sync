SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/******************************************************************************/
/* Store procedure: rdt_PTLPiece_MultiSKU                                     */
/* Copyright      : LF Logistics                                              */
/*                                                                            */
/* Purpose: Prompt multi SKU that share same barcode for selection            */
/*                                                                            */
/* Date        Rev  Author      Purposes                                      */
/* 29-03-2022  1.0  Ung         WMS-19254 MultiSKUBarcode with dynamic scope  */
/* 09-05-2022  1.1  Ung         WMS-19254 Add UPC param                       */
/******************************************************************************/

CREATE PROCEDURE [RDT].[rdt_PTLPiece_MultiSKU]
   @nMobile    INT,
   @nFunc      INT,
   @cLangCode  NVARCHAR( 3),
   @nStep      INT,          
   @nInputKey  INT,          
   @cFacility  NVARCHAR( 5),  
   @cStorerKey NVARCHAR( 15),
   @cStation   NVARCHAR( 10),
   @cMethod    NVARCHAR( 1), 
   @cSKU       NVARCHAR( 20),
   @cLastPos   NVARCHAR( 10),
   @cOption    NVARCHAR( 1), 
   @cInField01 NVARCHAR( 60) OUTPUT,  @cOutField01 NVARCHAR( 60) OUTPUT,
   @cInField02 NVARCHAR( 60) OUTPUT,  @cOutField02 NVARCHAR( 60) OUTPUT,
   @cInField03 NVARCHAR( 60) OUTPUT,  @cOutField03 NVARCHAR( 60) OUTPUT,
   @cInField04 NVARCHAR( 60) OUTPUT,  @cOutField04 NVARCHAR( 60) OUTPUT,
   @cInField05 NVARCHAR( 60) OUTPUT,  @cOutField05 NVARCHAR( 60) OUTPUT,
   @cInField06 NVARCHAR( 60) OUTPUT,  @cOutField06 NVARCHAR( 60) OUTPUT,
   @cInField07 NVARCHAR( 60) OUTPUT,  @cOutField07 NVARCHAR( 60) OUTPUT,
   @cInField08 NVARCHAR( 60) OUTPUT,  @cOutField08 NVARCHAR( 60) OUTPUT,
   @cInField09 NVARCHAR( 60) OUTPUT,  @cOutField09 NVARCHAR( 60) OUTPUT,
   @cInField10 NVARCHAR( 60) OUTPUT,  @cOutField10 NVARCHAR( 60) OUTPUT,
   @cInField11 NVARCHAR( 60) OUTPUT,  @cOutField11 NVARCHAR( 60) OUTPUT,
   @cInField12 NVARCHAR( 60) OUTPUT,  @cOutField12 NVARCHAR( 60) OUTPUT,
   @cInField13 NVARCHAR( 60) OUTPUT,  @cOutField13 NVARCHAR( 60) OUTPUT,
   @cInField14 NVARCHAR( 60) OUTPUT,  @cOutField14 NVARCHAR( 60) OUTPUT,
   @cInField15 NVARCHAR( 60) OUTPUT,  @cOutField15 NVARCHAR( 60) OUTPUT,
   @cType      NVARCHAR( 10),
   @cMultiSKUBarcode NVARCHAR( 1),
   @cUPC       NVARCHAR( 30) OUTPUT,
   @nErrNo     INT           OUTPUT,
   @cErrMsg    NVARCHAR( 20) OUTPUT
AS
BEGIN
   SET NOCOUNT ON
   SET QUOTED_IDENTIFIER OFF
   SET ANSI_NULLS OFF
   SET CONCAT_NULL_YIELDS_NULL OFF

   DECLARE @cSQL      NVARCHAR( MAX)
   DECLARE @cSQLParam NVARCHAR( MAX)

   -- Get method level storer config (setup at CodeLKUP.Notes)
   DECLARE @cMultiSKUBarcodeSP NVARCHAR( 30)
   SET @cMultiSKUBarcodeSP = rdt.rdt_PTLPiece_GetConfig( @nFunc, 'MultiSKUBarcodeSP', @cStorerKey, @cMethod)
   IF @cMultiSKUBarcodeSP = '0'
      SET @cMultiSKUBarcodeSP = ''
      
   IF EXISTS( SELECT 1 FROM dbo.sysobjects WHERE name = @cMultiSKUBarcodeSP AND type = 'P')
   BEGIN
      SET @cSQL = 'EXEC rdt.' + RTRIM( @cMultiSKUBarcodeSP) +
         ' @nMobile, @nFunc, @cLangCode, @nStep, @nInputKey, @cFacility, @cStorerKey, @cStation, @cMethod, @cSKU, @cLastPos, @cOption, ' +
         ' @cUPC OUTPUT, @nErrNo OUTPUT, @cErrMsg OUTPUT'
      SET @cSQLParam =
         '@nMobile      INT,           ' +
         '@nFunc        INT,           ' +
         '@cLangCode    NVARCHAR( 3),  ' +
         '@nStep        INT,           ' +
         '@nInputKey    INT,           ' +
         '@cFacility    NVARCHAR( 5),  ' + 
         '@cStorerKey   NVARCHAR( 15), ' +
         '@cStation     NVARCHAR( 10), ' +
         '@cMethod      NVARCHAR( 1),  ' +
         '@cSKU         NVARCHAR( 20), ' +
         '@cLastPos     NVARCHAR( 10), ' +
         '@cOption      NVARCHAR( 1),  ' +
         '@cUPC         NVARCHAR( 30)  OUTPUT, ' + 
         '@nErrNo       INT            OUTPUT, ' +
         '@cErrMsg      NVARCHAR( 20)  OUTPUT  '

      EXEC sp_ExecuteSQL @cSQL, @cSQLParam,
         @nMobile, @nFunc, @cLangCode, @nStep, @nInputKey, @cFacility, @cStorerKey, @cStation, @cMethod, @cSKU, @cLastPos, @cOption,
         @cUPC OUTPUT, @nErrNo OUTPUT, @cErrMsg OUTPUT
      
      IF @nErrNo <> 0
         GOTO Quit

      EXEC rdt.rdt_MultiSKUBarcode @nMobile, @nFunc, @cLangCode,
         @cInField01 OUTPUT,  @cOutField01 OUTPUT,
         @cInField02 OUTPUT,  @cOutField02 OUTPUT,
         @cInField03 OUTPUT,  @cOutField03 OUTPUT,
         @cInField04 OUTPUT,  @cOutField04 OUTPUT,
         @cInField05 OUTPUT,  @cOutField05 OUTPUT,
         @cInField06 OUTPUT,  @cOutField06 OUTPUT,
         @cInField07 OUTPUT,  @cOutField07 OUTPUT,
         @cInField08 OUTPUT,  @cOutField08 OUTPUT,
         @cInField09 OUTPUT,  @cOutField09 OUTPUT,
         @cInField10 OUTPUT,  @cOutField10 OUTPUT,
         @cInField11 OUTPUT,  @cOutField11 OUTPUT,
         @cInField12 OUTPUT,  @cOutField12 OUTPUT,
         @cInField13 OUTPUT,  @cOutField13 OUTPUT,
         @cInField14 OUTPUT,  @cOutField14 OUTPUT,
         @cInField15 OUTPUT,  @cOutField15 OUTPUT,
         @cType,
         @cMultiSKUBarcode,
         @cStorerKey,
         @cUPC     OUTPUT,
         @nErrNo   OUTPUT,
         @cErrMsg  OUTPUT,
         'CURSOR',   -- DocType
         'NONE',     -- DocNo
         '',         -- DocType2
         ''          -- DocNo2
   END
   ELSE
      EXEC rdt.rdt_MultiSKUBarcode @nMobile, @nFunc, @cLangCode,
         @cInField01 OUTPUT,  @cOutField01 OUTPUT,
         @cInField02 OUTPUT,  @cOutField02 OUTPUT,
         @cInField03 OUTPUT,  @cOutField03 OUTPUT,
         @cInField04 OUTPUT,  @cOutField04 OUTPUT,
         @cInField05 OUTPUT,  @cOutField05 OUTPUT,
         @cInField06 OUTPUT,  @cOutField06 OUTPUT,
         @cInField07 OUTPUT,  @cOutField07 OUTPUT,
         @cInField08 OUTPUT,  @cOutField08 OUTPUT,
         @cInField09 OUTPUT,  @cOutField09 OUTPUT,
         @cInField10 OUTPUT,  @cOutField10 OUTPUT,
         @cInField11 OUTPUT,  @cOutField11 OUTPUT,
         @cInField12 OUTPUT,  @cOutField12 OUTPUT,
         @cInField13 OUTPUT,  @cOutField13 OUTPUT,
         @cInField14 OUTPUT,  @cOutField14 OUTPUT,
         @cInField15 OUTPUT,  @cOutField15 OUTPUT,
         @cType,
         @cMultiSKUBarcode,
         @cStorerKey,
         @cUPC     OUTPUT,
         @nErrNo   OUTPUT,
         @cErrMsg  OUTPUT

Quit:

END

GO