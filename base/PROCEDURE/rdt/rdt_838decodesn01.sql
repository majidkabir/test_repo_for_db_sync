SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
/************************************************************************/
/* Store procedure: rdt_838DecodeSN01                                   */
/* Copyright      : LF Logistics                                        */
/*                                                                      */
/* Purpose: Decode comma delimeted serial no                            */
/*                                                                      */
/* Date        Rev  Author       Purposes                               */
/* 13-03-2019  1.0  Ung          WMS-8134 Created                       */
/* 18-09-2019  1.1  James        WMS-10030 Check serial count (james01) */
/************************************************************************/

CREATE PROCEDURE [RDT].[rdt_838DecodeSN01]
   @nMobile     INT,           
   @nFunc       INT,           
   @cLangCode   NVARCHAR( 3),  
   @nStep       INT,           
   @nInputKey   INT,           
   @cStorerKey  NVARCHAR( 15), 
   @cFacility   NVARCHAR( 5),  
   @cSKU        NVARCHAR( 20),  
   @cBarcode    NVARCHAR( MAX),
   @cSerialNo   NVARCHAR( 30)  OUTPUT,
   @nSerialQTY  INT            OUTPUT,
   @nBulkSNO    INT            OUTPUT,
   @nErrNo      INT            OUTPUT,
   @cErrMsg     NVARCHAR( 20)  OUTPUT 
AS
BEGIN
   SET NOCOUNT ON
   SET QUOTED_IDENTIFIER OFF
   SET ANSI_NULLS OFF
   SET CONCAT_NULL_YIELDS_NULL OFF

   DECLARE @nReceiveSerialNoLogKey INT
   DECLARE @nSerialNo_Cnt          INT
   DECLARE @nQTY                   INT

   SELECT @nQTY = V_Qty
   FROM RDT.RDTMOBREC WITH (NOLOCK)
   WHERE Mobile = @nMobile
   /*
   -- Single serial no
   IF CHARINDEX( ',', @cBarCode) = 0 
   BEGIN
      SET @cSerialNo = LEFT( @cBarCode, 30)
      SET @nSerialQTY = 1
      
      SET @nBulkSNO = 0 -- No
   END
   */

   IF @nQTY = 1
   BEGIN
      IF CHARINDEX( ',', @cBarCode) > 0 
      BEGIN
         SET @nErrNo = 144051
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --'SrCnt NotMatch'
         GOTO Quit
      END

      SET @cSerialNo = LEFT( @cBarCode, 30)
      SET @nSerialQTY = 1
      
      SET @nBulkSNO = 0 -- No
   END
   -- Bulk serial no
   ELSE
   BEGIN
      -- Check serial no scanned match qty to pack (james01)
      SELECT @nSerialNo_Cnt = SUM( LEN( RTRIM( @cBarcode)) - LEN( REPLACE( RTRIM( @cBarcode), ',', '')) + 1)

      IF @nQTY <> @nSerialNo_Cnt
      BEGIN
         SET @nErrNo = 144052
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --'SrCnt NotMatch'
         GOTO Quit
      END

      -- Delete serial no temp table
      WHILE (1=1)
      BEGIN
         SELECT TOP 1 
            @nReceiveSerialNoLogKey = ReceiveSerialNoLogKey 
         FROM rdt.rdtReceiveSerialNoLog WITH (NOLOCK)
         WHERE Mobile = @nMobile
            AND Func = @nFunc

         IF @@ROWCOUNT > 0
            DELETE rdt.rdtReceiveSerialNoLog 
            WHERE ReceiveSerialNoLogKey = @nReceiveSerialNoLogKey
         ELSE
            BREAK      
      END
   
      -- Decode base on delimeter
      INSERT INTO rdt.rdtReceiveSerialNoLog (Mobile, Func, StorerKey, SKU, SerialNo, QTY)
      SELECT @nMobile, @nFunc, @cStorerKey, @cSKU, ColValue, 1
      FROM dbo.fnc_DelimSplit (',', @cBarcode)
      WHERE ColValue <> ''
   
      /*
      -- Check serial no valid
      IF EXISTS( SELECT TOP 1 1
         FROM rdt.rdtReceiveSerialNoLog WITH (NOLOCK)
         WHERE Mobile = @nMobile
            AND Func = @nFunc)
            -- AND (LEN( SerialNo) <> 11 OR SerialNo LIKE '%[^0-9]%'))
      BEGIN
         SET @nErrNo = 135851
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Invalid SNO
         GOTO Quit
      END
      */
   
      SET @nBulkSNO = 1 -- Yes
   END
   
Quit:

END

GO