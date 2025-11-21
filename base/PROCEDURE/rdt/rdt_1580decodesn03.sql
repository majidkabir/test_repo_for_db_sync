SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/************************************************************************/
/* Store procedure: rdt_1580DecodeSN03                                  */
/* Copyright      : Maersk                                              */
/*                                                                      */
/* Purpose: Decode comma delimeted serial no                            */
/*                                                                      */
/* Date        Rev  Author       Purposes                               */
/* 30-10-2023  1.0  Ung          WMS-23008 Created                      */
/************************************************************************/

CREATE   PROCEDURE [RDT].[rdt_1580DecodeSN03]
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

   -- Get SKU info
   DECLARE @cSKUGroup NVARCHAR( 10)
   SELECT @cSKUGroup = SKUGroup FROM dbo.SKU WITH (NOLOCK) WHERE StorerKey = @cStorerKey AND SKU = @cSKU

   -- Get decode info
   DECLARE @cDelimiter NVARCHAR( 1) = ''
   DECLARE @cLength NVARCHAR( 250) = ''
   DECLARE @nLength INT
   SELECT
      @cDelimiter = ISNULL( Short, ''), 
      @cLength = ISNULL( Long, '')
   FROM dbo.CodeLKUP WITH (NOLOCK)
   WHERE ListName = 'DecodeSN'
      AND StorerKey = @cStorerKey
      AND Code = @cSKUGroup

   -- Code lookup is setup
   IF @@ROWCOUNT > 0
   BEGIN
      IF @cDelimiter <> ''
      BEGIN
         INSERT INTO rdt.rdtReceiveSerialNoLog (Mobile, Func, StorerKey, SKU, SerialNo, QTY)
         SELECT @nMobile, @nFunc, @cStorerKey, @cSKU, ColValue, 1
         FROM dbo.fnc_DelimSplit (@cDelimiter, @cBarcode)
         WHERE ColValue <> ''
         IF @@ERROR <> 0
         BEGIN
            SET @nErrNo = 208101
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --INS Log Fail
            GOTO Quit
         END
      END
      ELSE
      BEGIN
         SET @nLength = TRY_CAST( @cLength AS INT)

         -- Check length setup
         IF @nLength IS NULL
         BEGIN
            SET @nErrNo = 208102
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Bad SNO setup
            GOTO Quit
         END

         -- Check length
         IF @nLength NOT BETWEEN 1 AND 30
         BEGIN
            SET @nErrNo = 208103
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Bad SNO setup
            GOTO Quit
         END

         -- Loop 
         DECLARE @cSubString NVARCHAR( 30)
         WHILE @cBarcode <> ''
         BEGIN
            SET @cSubString = LEFT( @cBarcode, @nLength)
            SET @cBarcode = SUBSTRING( @cBarcode, @nLength + 1, LEN( @cBarcode))

            INSERT INTO rdt.rdtReceiveSerialNoLog (Mobile, Func, StorerKey, SKU, SerialNo, QTY)
            VALUES (@nMobile, @nFunc, @cStorerKey, @cSKU, @cSubString, 1)
            IF @@ERROR <> 0
            BEGIN
               SET @nErrNo = 208104
               SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --INS Log Fail
               GOTO Quit
            END
         END
      END   

      SET @nBulkSNO = 1
   END

Quit:

END

GO