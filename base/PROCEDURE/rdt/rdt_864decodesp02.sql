SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/******************************************************************************/
/* Store procedure: rdt_864DecodeSP02                                         */
/* Copyright: LF Logistics                                                    */
/*                                                                            */
/* Purpose: Decode 2D barcode. Perform validation on each step.               */
/*                                                                            */
/* Date        Author    Ver.  Purposes                                       */
/* 29-03-2018  James     1.0   WMS4127. Created                               */
/******************************************************************************/

CREATE PROC [RDT].[rdt_864DecodeSP02] (
@nMobile        INT,
@nFunc          INT,
@cLangCode      NVARCHAR( 3),
@nStep          INT,
@nInputKey      INT,
@cStorerKey     NVARCHAR( 15), 
@cBarcode       NVARCHAR( 2000),
@cID            NVARCHAR( 18)  OUTPUT, 
@cSKU           NVARCHAR( 20)  OUTPUT, 
@nQTY           INT            OUTPUT, 
@cDropID        NVARCHAR( 20)  OUTPUT, 
@cLottable01    NVARCHAR( 18)  OUTPUT, 
@cLottable02    NVARCHAR( 18)  OUTPUT, 
@cLottable03    NVARCHAR( 18)  OUTPUT, 
@dLottable04    DATETIME       OUTPUT, 
@dLottable05    DATETIME       OUTPUT, 
@cLottable06    NVARCHAR( 30)  OUTPUT, 
@cLottable07    NVARCHAR( 30)  OUTPUT, 
@cLottable08    NVARCHAR( 30)  OUTPUT, 
@cLottable09    NVARCHAR( 30)  OUTPUT, 
@cLottable10    NVARCHAR( 30)  OUTPUT, 
@cLottable11    NVARCHAR( 30)  OUTPUT, 
@cLottable12    NVARCHAR( 30)  OUTPUT, 
@dLottable13    DATETIME       OUTPUT, 
@dLottable14    DATETIME       OUTPUT, 
@dLottable15    DATETIME       OUTPUT, 
@cUserDefine01  NVARCHAR( 60)  OUTPUT, 
@cUserDefine02  NVARCHAR( 60)  OUTPUT, 
@cUserDefine03  NVARCHAR( 60)  OUTPUT, 
@cUserDefine04  NVARCHAR( 60)  OUTPUT, 
@cUserDefine05  NVARCHAR( 60)  OUTPUT, 
@nErrNo         INT            OUTPUT, 
@cErrMsg        NVARCHAR( 20)  OUTPUT
) AS
BEGIN
   SET NOCOUNT ON
   SET ANSI_NULLS OFF
   SET QUOTED_IDENTIFIER OFF
   SET CONCAT_NULL_YIELDS_NULL OFF

   DECLARE @nPos     INT,
           @cExternPOKey      NVARCHAR( 20),
           @cOrderKey         NVARCHAR( 10), 
           @cConsigneeKey     NVARCHAR( 15), 
           @cPrevConsigneeKey NVARCHAR( 15), 
           @cBarcode1         NVARCHAR( 60), 
           @cBarcode2         NVARCHAR( 60), 
           @cSKUCode          NVARCHAR( 20), 
           @cQty              NVARCHAR( 5),
           @nPos1             INT,
           @nPos2             INT,
           @nPos3             INT,
           @nPos4             INT,
           @nPos5             INT
   
   IF @nFunc = 864 -- Pick To Drop ID
   BEGIN
      IF @nInputKey = 1 -- MUID
      BEGIN
         IF @nStep = 1 -- ENTER
         BEGIN
            IF ISNULL( @cBarcode, '') = ''
               GOTO Quit

            SELECT @cPrevConsigneeKey = V_String15
            FROM rdt.RDTMOBREC WITH (NOLOCK)
            WHERE Mobile = @nMobile

            SELECT @nPos1 = 0, @nPos2 = 0, @nPos3 = 0, @nPos4 = 0, @nPos5 = 0
            SELECT @cUserDefine01 = '', @cUserDefine02 = '', @cUserDefine03 = '', @cSKU = '', @cID = ''

            SET @nPos1 =  CHARINDEX ( ';' , @cBarcode) 
            SET @nPos2 =  CHARINDEX ( ';' , @cBarcode, @nPos1 + 1) 
            SET @nPos3 =  CHARINDEX ( ';' , @cBarcode, @nPos2 + 1) 
            SET @nPos4 =  CHARINDEX ( ';' , @cBarcode, @nPos3 + 1) 
            SET @nPos5 =  CHARINDEX ( ';' , @cBarcode, @nPos4 + 1) 

            IF @nPos1 > 0
               SET @cUserDefine01 = SUBSTRING( @cBarcode, 1, ( @nPos1 - 1))
            ELSE
            BEGIN
               SET @nErrNo = 123201
               SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Invalid Format
               GOTO Quit
            END

            IF @nPos2 > 0
               SET @cSKU = SUBSTRING( @cBarcode, ( @nPos1 + 1), ( @nPos2 - @nPos1 - 1))

            IF @nPos3 > 0
               SET @cUserDefine02 = SUBSTRING( @cBarcode, ( @nPos2 + 1), ( @nPos3 - @nPos2 - 1))

            IF @nPos4 > 0
            BEGIN
               SET @cUserDefine03 = SUBSTRING( @cBarcode, ( @nPos3 + 1), ( @nPos4 - @nPos3 - 1))
               SET @cID = SUBSTRING( @cBarcode, ( @nPos4 + 1), LEN( @cBarcode) - @nPos4 - 1)
            END

            -- Check if QR code scanned before
            IF NOT EXISTS ( 
               SELECT 1 FROM dbo.PICKDETAIL PD WITH (NOLOCK)
               JOIN dbo.ORDERDETAIL OD WITH (NOLOCK) ON ( PD.OrderKey = OD.OrderKey AND PD.OrderLineNumber = OD.OrderLineNumber)
               JOIN dbo.ORDERS O WITH (NOLOCK) ON ( OD.OrderKey = O.OrderKey)
               WHERE O.CONSIGNEEKEY = @cUserDefine01  -- stor
               AND   PD.SKU = @cSKU                     -- sku
               AND   PD.ID = @cID                       -- carton id
               AND   PD.OrderKey = @cUserDefine03       -- orderkey
               AND   PD.CaseID = @cUserDefine02-- externpokey
               AND   PD.Status = '0')        
            BEGIN
               SET @nErrNo = 123202
               SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Scanned Before
               GOTO Quit
            END
               --insert into traceinfo (tracename, timein, col1, col2, col3, col4, col5) values 
               --('864', getdate(), @cUserDefine01, @cSKU, @cID, @cUserDefine03, @cUserDefine02)

            -- 1st time use enter this module to scan MUID or user change different store then
            -- set default to drop id blank
            IF ISNULL( @cPrevConsigneeKey, '') = '' OR @cPrevConsigneeKey <> @cUserDefine01
               SET @cDropID = ''

            SET @nQTY = 1
            /*
            select '@nPos1', @nPos1, '@nPos2', @nPos2, '@nPos3', @nPos3
            SET @cID = '0014153923'  
            SET @cSKU = '4549845899968'  
            SET @nQTY = 2  
            SET @cDropID = ''  
            SET @cUserDefine01 = 'AS001'  
            */

         END
      END   -- @@nInputKey = 1
   END

Quit:

END

GO