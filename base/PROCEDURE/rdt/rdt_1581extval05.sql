SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/************************************************************************/
/* Store procedure: rdt_1581ExtVal05                                    */
/* Copyright      : Maersk                                              */
/*                                                                      */
/* Purpose: Defy                                                        */
/*            FCR-549                                                   */
/* Modifications log:                                                   */
/* Date        Rev  Author      Purposes                                */
/* 2024-07-24  1.0  JHU151       FCR-549                                */
/************************************************************************/

CREATE   PROCEDURE rdt.rdt_1581ExtVal05
    @nMobile      INT
   ,@nFunc        INT
   ,@nStep        INT
   ,@nInputKey    INT
   ,@cLangCode    NVARCHAR( 3)
   ,@cStorerKey   NVARCHAR( 15)
   ,@cReceiptKey  NVARCHAR( 10)
   ,@cPOKey       NVARCHAR( 10)
   ,@cExtASN      NVARCHAR( 20)
   ,@cToLOC       NVARCHAR( 10)
   ,@cToID        NVARCHAR( 18)
   ,@cLottable01  NVARCHAR( 18)
   ,@cLottable02  NVARCHAR( 18)
   ,@cLottable03  NVARCHAR( 18)
   ,@dLottable04  DATETIME
   ,@cSKU         NVARCHAR( 20)
   ,@nQTY         INT
   ,@nErrNo       INT           OUTPUT
   ,@cErrMsg      NVARCHAR( 20) OUTPUT
AS
BEGIN
   SET NOCOUNT ON
   SET QUOTED_IDENTIFIER OFF
   SET ANSI_NULLS OFF
   SET CONCAT_NULL_YIELDS_NULL OFF


   IF @nFunc = 1581
   BEGIN
      DECLARE  @cAddRCPTValidtn     NVARCHAR(10)
      SET @cAddRCPTValidtn = rdt.RDTGetConfig( @nFunc, 'AddRCPTValidtn', @cStorerKey)
      /********************************************************************************
      Step 1. Screen = 1750. ASN, PO screen
      ASN    (field01, input)
      PO     (field02, input)
      EXTASN (field03, input)
      ********************************************************************************/
      IF @nStep = 1
      BEGIN
         IF @nInputKey = 1 -- ENTER
         BEGIN
            IF @cAddRCPTValidtn = '1'
            BEGIN
               IF NOT EXISTS(
                           SELECT 1
                              FROM dbo.Receipt WITH (NOLOCK)
                              WHERE Receiptkey = @cReceiptkey
                              AND Storerkey = @cStorerKey
                              AND RecType IN ('Normal','Return')
               )
               BEGIN
                  SET @nErrNo = 219701
                  SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Invalid ASN Type
                  GOTO Quit
               END
            END
         END
      END
      -- Lottable
      ELSE IF @nStep = 4
      BEGIN
         IF @nInputKey = 1
         BEGIN
            IF @cAddRCPTValidtn = '1'
            BEGIN
               SELECT UDF01 
               FROM CodeLkUp WITH(NOLOCK)
               WHERE Code = @nFunc 
               AND storerkey = @cStorerKey 
               AND ListName = 'LOT1_2LINK' 
               AND UDF02 = @cLottable02

               IF @@ROWCOUNT = 0
               BEGIN
                  SET @nErrNo = 219702
                  SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Invalid value
                  GOTO Quit
               END
            END
         END
      END
      ELSE IF @nstep = 9
      BEGIN
         IF @nInputKey = 1
         BEGIN
            DECLARE @cSerialNo           NVARCHAR(50)

            SET @cAddRCPTValidtn = rdt.RDTGetConfig( @nFunc, 'AddSerialValidtn', @cStorerKey)

            IF @cAddRCPTValidtn = '1'
            BEGIN
               SELECT
                  @cSku = V_SKU,
                  @cSerialNo = V_MAX
               FROM   RDTMOBREC (NOLOCK)
               WHERE  Mobile = @nMobile

               IF CHARINDEX(@cSku,@cSerialNo,1) <> 1
                  OR LEN(@cSerialNo) <= LEN(@cSku)
               BEGIN               
                  SET @nErrNo = -1
                  SET @cErrMsg = ''
                  GOTO Quit
               END
            END
         END
      END   
   END
   ELSE IF @nFunc = 1580
   BEGIN
      SET @cAddRCPTValidtn = rdt.RDTGetConfig( @nFunc, 'AddRCPTValidtn', @cStorerKey)
      /********************************************************************************
      Step 1. Screen = 1750. ASN, PO screen
      ASN    (field01, input)
      PO     (field02, input)
      EXTASN (field03, input)
      ********************************************************************************/
      IF @nStep = 1
      BEGIN
         IF @nInputKey = 1 -- ENTER
         BEGIN
            IF @cAddRCPTValidtn = '1'
            BEGIN
               IF NOT EXISTS(
                           SELECT 1
                              FROM dbo.Receipt WITH (NOLOCK)
                              WHERE Receiptkey = @cReceiptkey
                              AND Storerkey = @cStorerKey
                              AND RecType = 'Factory'
               )
               BEGIN
                  SET @nErrNo = 219701
                  SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Invalid ASN Type
                  GOTO Quit
               END
            END
         END
      END
   End
Quit:
END

GO