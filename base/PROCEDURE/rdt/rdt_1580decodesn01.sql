SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO


/************************************************************************/
/* Store procedure: rdt_1580DecodeSN01                                  */
/* Copyright      : LF Logistics                                        */
/*                                                                      */
/* Purpose: Decode comma delimeted serial no                            */
/*                                                                      */
/* Date        Rev  Author       Purposes                               */
/* 02-08-2018  1.0  Ung          WMS-5722 Created                       */
/* 11-10-2018  1.1  Ung          WMS-6183 Validate serial no            */
/* 06-06-2020  1.2  James        Add hoc fix to allow alphanumeric      */
/*                               of serial no (james01)                 */
/************************************************************************/

CREATE PROCEDURE [RDT].[rdt_1580DecodeSN01]
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
   DECLARE @nRowCount INT

   SELECT TOP 1 
      @nReceiveSerialNoLogKey = ReceiveSerialNoLogKey 
   FROM rdt.rdtReceiveSerialNoLog WITH (NOLOCK)
   WHERE Mobile = @nMobile
      AND Func = @nFunc
   
   WHILE @@ROWCOUNT > 0
   BEGIN
      DELETE rdt.rdtReceiveSerialNoLog 
      WHERE ReceiveSerialNoLogKey = @nReceiveSerialNoLogKey
      
      SELECT TOP 1 
         @nReceiveSerialNoLogKey = ReceiveSerialNoLogKey 
      FROM rdt.rdtReceiveSerialNoLog WITH (NOLOCK)
      WHERE Mobile = @nMobile
         AND Func = @nFunc
   END
   
   INSERT INTO rdt.rdtReceiveSerialNoLog (Mobile, Func, StorerKey, SKU, SerialNo, QTY)
   SELECT @nMobile, @nFunc, @cStorerKey, @cSKU, ColValue, 1
   FROM dbo.fnc_DelimSplit (';', @cBarcode)
   WHERE ColValue <> ''
   
   IF EXISTS( SELECT TOP 1 1
      FROM rdt.rdtReceiveSerialNoLog WITH (NOLOCK)
      WHERE Mobile = @nMobile
         AND Func = @nFunc
         --AND (LEN( SerialNo) <> 11 OR SerialNo LIKE '%[0-9]%'))
         AND (LEN( SerialNo) <> 11))
   BEGIN
      SET @nErrNo = 130101
      SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Invalid SNO
      GOTO Quit
   END
   
   SET @nBulkSNO = 1

Quit:

END

GO