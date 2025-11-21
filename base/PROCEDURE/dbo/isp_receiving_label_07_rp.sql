SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/***************************************************************************/
/* Store procedure: isp_Receiving_Label_07_RP                              */
/* Purpose: SKU label                                                      */
/*                                                                         */
/* Modifications log:                                                      */
/*                                                                         */
/* Date       Rev  Author   Purposes                                       */
/* 2013-09-03 1.0  Ung      SOS273208 Created                              */
/* 2014-07-08 1.1  James    SOS315468 - Replace DateTime with Lottable01   */
/*                          (james01)                                      */
/* 2016-03-8  1.2  ChewKP   SOS#364996 - Changes of Mapping                */
/***************************************************************************/

CREATE PROC [dbo].[isp_Receiving_Label_07_RP] (
   @nMobile     INT,
   @nFunc       INT,
   @cLangCode   NVARCHAR( 3),
   @cStorerKey  NVARCHAR( 15),
   @cByRef1     NVARCHAR( 20),
   @cByRef2     NVARCHAR( 20),
   @cByRef3     NVARCHAR( 20),
   @cByRef4     NVARCHAR( 20),
   @cByRef5     NVARCHAR( 20),
   @cByRef6     NVARCHAR( 20),
   @cByRef7     NVARCHAR( 20),
   @cByRef8     NVARCHAR( 20),
   @cByRef9     NVARCHAR( 20),
   @cByRef10    NVARCHAR( 20),
   @cPrintTemplate NVARCHAR( MAX),
   @cPrintData  NVARCHAR( MAX) OUTPUT,
   @nErrNo      INT            OUTPUT,
   @cErrMsg     NVARCHAR( 20)  OUTPUT  -- screen limitation, 20 char max
)
AS
   SET NOCOUNT ON
   SET QUOTED_IDENTIFIER OFF
   SET ANSI_NULLS OFF
   SET CONCAT_NULL_YIELDS_NULL OFF

   DECLARE @cReceiptKey    NVARCHAR(10)
   DECLARE @cReceiptLineNo NVARCHAR(5)
   DECLARE @nQTY           INT
   DECLARE @cSKU           NVARCHAR(20)
   DECLARE @cALTSKU        NVARCHAR(20)
   DECLARE @cLottable03    NVARCHAR(18)
   DECLARE @cEditWho       NVARCHAR(18)
   DECLARE @cField01       NVARCHAR(20)
   DECLARE @cField02       NVARCHAR(20)
   DECLARE @cField03       NVARCHAR(20)
   DECLARE @cField04       NVARCHAR(20)
   DECLARE @cLottable01    NVARCHAR(18)   -- (james01)

   SET @cReceiptKey    = @cByRef1
   SET @cReceiptLineNo = @cByRef2
   SET @nQTY           = @cByRef3
   SET @cPrintData     = ''

   DECLARE @Result TABLE
   (
      SKU         NVARCHAR(20) NULL,
      ALTSKU      NVARCHAR(20) NULL,
      Lottable03  NVARCHAR(18) NULL,
      EditWho     NVARCHAR(18) NULL
   )

   IF ISNULL( @nQTY, 0) = 0
   BEGIN
      SET @nQTY = 1
   END

   -- Loop each QTY
   WHILE @nQTY > 0
   BEGIN
      -- Get ReceiptDetail info
      SELECT 
         @cSKU = UPPER(RD.SKU),
         @cALTSKU = UPPER(SKU.ALTSKU),
         @cLottable03 = UPPER(RD.Lottable03),
         @cEditWho = UPPER(RD.EditWho), 
         @cLottable01 = UPPER(RD.Lottable01)     -- (james01)
      FROM Receipt R WITH (NOLOCK)
         JOIN ReceiptDetail RD WITH (NOLOCK) ON (R.ReceiptKey = RD.ReceiptKey)
         JOIN SKU WITH (NOLOCK) ON (RD.StorerKey = SKU.StorerKey AND RD.SKU = SKU.SKU)
      WHERE R.ReceiptKey = @cReceiptKey
         AND RD.ReceiptlineNumber = @cReceiptLineNo

      -- Format output field
      --SET @cField01 = SUBSTRING( @cLottable03 , 1, 3) + '-' + 
      --                SUBSTRING( @cLottable03 , 4, 3) + '-' + 
      --                SUBSTRING( @cLottable03 , 7, 2) + '-' + 
      --                SUBSTRING( @cLottable03 , 9, 1) + '-' +  
      --                SUBSTRING( @cLottable03 , 10, 1) 
      
      --SET @cField02 = SUBSTRING( @cSKU , 1, 6) + '-' + 
      --                SUBSTRING( @cSKU , 7, 3) + '-' + 
      --                SUBSTRING( @cSKU , 10, 6) 

      SET @cField01 = SUBSTRING( @cLottable03 , 1, 3) + '-'
      
      SET @cField02 = SUBSTRING( @cLottable03 , 4, 3) + '-' + 
                      SUBSTRING( @cLottable03 , 7, 2) + '-' 
      
      SET @cField03 = SUBSTRING( @cLottable03 , 9, 1) + '-' +
                      SUBSTRING( @cLottable03 , 10, 1) 
                      
      SET @cField04 = SUBSTRING(@cSKU, 1,6) + '-' + SUBSTRING(@cSKU, 7,3) + '-' + SUBSTRING(@cSKU, 10,6) 
                      
      -- Replace field with actual value
      SET @cPrintTemplate = REPLACE (@cPrintTemplate, '<Field01>', RTRIM( @cField01)) -- Lottable03
      SET @cPrintTemplate = REPLACE (@cPrintTemplate, '<Field02>', RTRIM( @cField02))  
      SET @cPrintTemplate = REPLACE (@cPrintTemplate, '<Field03>', RTRIM( @cField03)) 
      SET @cPrintTemplate = REPLACE (@cPrintTemplate, '<Field04>', RTRIM( @cField04)) 
      SET @cPrintTemplate = REPLACE (@cPrintTemplate, '<Field05>', RTRIM( @cALTSKU)) 
      SET @cPrintTemplate = REPLACE (@cPrintTemplate, '<Field06>', RTRIM( @cEditWho)) 
      SET @cPrintTemplate = REPLACE (@cPrintTemplate, '<Field07>', RTRIM( @cLottable01)) 
      
      
      --SET @cPrintTemplate = REPLACE (@cPrintTemplate, '<Field03>', RTRIM( @cAltSKU))
      --SET @cPrintTemplate = REPLACE (@cPrintTemplate, '<Field04>', RTRIM( @cEditWho))
      --SET @cPrintTemplate = REPLACE (@cPrintTemplate, '<Field05>', RTRIM( GETDATE()))
      --SET @cPrintTemplate = REPLACE (@cPrintTemplate, '<Field05>', RTRIM( @cLottable01))  -- RSO (james01)

      -- Output label to print
      SET @cPrintData = @cPrintData + @cPrintTemplate

      SET @nQTY = @nQTY - 1
   END

GO