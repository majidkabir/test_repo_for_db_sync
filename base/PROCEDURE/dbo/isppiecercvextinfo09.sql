SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/***************************************************************************/
/* Store procedure: ispPieceRcvExtInfo09                                   */
/* Copyright      : LFLogistics                                            */
/*                                                                         */
/* Purpose: Display sku info based on config setup (svalue = column name)  */
/*                                                                         */
/* Date       Rev  Author     Purposes                                     */
/* 2021-07-29 1.0  James      WMS-17571 Created                            */
/***************************************************************************/

CREATE PROCEDURE [dbo].[ispPieceRcvExtInfo09] (
  @cReceiptKey   NVARCHAR( 10), 
  @cPOKey        NVARCHAR( 10), 
  @cLOC          NVARCHAR( 10), 
  @cToID         NVARCHAR( 18), 
  @cLottable01   NVARCHAR( 18), 
  @cLottable02   NVARCHAR( 18), 
  @cLottable03   NVARCHAR( 18), 
  @dLottable04   DATETIME,  
  @cStorer       NVARCHAR( 15), 
  @cSKU          NVARCHAR( 20), 
  @cExtendedInfo NVARCHAR( 20) OUTPUT
) AS
BEGIN
   SET NOCOUNT ON
   SET QUOTED_IDENTIFIER OFF
   SET ANSI_NULLS OFF
   SET CONCAT_NULL_YIELDS_NULL OFF

   DECLARE @cCheckSpecialSKU  NVARCHAR( 20)
          ,@cText             NVARCHAR( 60)
          ,@cErrMsg1          NVARCHAR( 20)
          ,@cErrMsg2          NVARCHAR( 20)
          ,@cErrMsg3          NVARCHAR( 20)
          ,@cSQL              NVARCHAR( 1000)
          ,@cSQLParam         NVARCHAR( 1000)
          ,@cErrMsg           NVARCHAR( 20)
          ,@nMobile           INT
          ,@nLength           INT
          ,@nStep             INT
          ,@nInputKey         INT
          ,@nFunc             INT
          ,@nErrNo            INT
          
   SELECT 
      @nStep = Step,
      @nInputKey = InputKey,
      @nFunc = Func, 
      @nMobile = Mobile 
   FROM rdt.rdtMobrec WITH (NOLOCK) 
   WHERE UserName = SUSER_SNAME()
          
   SET @cCheckSpecialSKU = rdt.rdtGetConfig( @nFunc, 'CheckSpecialSKU', @cStorer)
   
   -- Config not setup, no need further action
   IF @cCheckSpecialSKU = '0'
      GOTO Quit

   -- Not a valid column, no need further action
   IF NOT EXISTS( SELECT 1
      FROM INFORMATION_SCHEMA.COLUMNS 
      WHERE TABLE_NAME = 'SKU' 
         AND COLUMN_NAME = @cCheckSpecialSKU
         AND DATA_TYPE = 'nvarchar')
      GOTO Quit
      
   IF @nStep = 5  -- SKU/QTY 
   BEGIN
      IF @nInputKey = 1
      BEGIN
         SET @cSQL = 
            ' SELECT @cText = ' + @cCheckSpecialSKU 
         SET @cSQL = @cSQL +  ' FROM dbo.SKU WITH (NOLOCK) '  
         SET @cSQL = @cSQL +  ' WHERE StorerKey = @cStorerKey ' 
         SET @cSQL = @cSQL +  ' AND   SKU = @cSKU '

         SET @cSQLParam = 
            '@cStorerKey   NVARCHAR( 15), ' +  
            '@cSKU         NVARCHAR( 20), ' +  
            '@cText        NVARCHAR( 60)   OUTPUT ' 

         EXEC sp_ExecuteSQL @cSQL, @cSQLParam, 
            @cStorer, @cSKU, @cText OUTPUT

         IF ISNULL( @cText, '') <> ''
         BEGIN
            SET @nLength = LEN( @cText)
            
            IF @nLength > 40
               SET @cErrMsg3 = SUBSTRING( @cText, 41, 20)
            IF @nLength > 20
               SET @cErrMsg2 = SUBSTRING( @cText, 21, 20)

            SET @cErrMsg1 = SUBSTRING( @cText, 1, 20)

            SET @nErrNo = 0
            EXEC rdt.rdtInsertMsgQueue @nMobile, @nErrNo OUTPUT, @cErrMsg OUTPUT, 
            @cErrMsg1, @cErrMsg2, @cErrMsg3
            GOTO Quit
         END
      END
   END
   Quit:
END

GO