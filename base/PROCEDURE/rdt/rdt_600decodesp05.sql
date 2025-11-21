SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO


/******************************************************************************/
/* Store procedure: rdt_600DecodeSP05                                         */
/* Copyright: LF Logistics                                                    */
/*                                                                            */
/* Purpose: Decode lottable06, return sku                                     */
/*                                                                            */
/* Date        Author    Ver.  Purposes                                       */
/* 19-02-2018  James     1.0   WMS-7837 Created                               */
/* 05-05-2023  YeeKung   1.1   WMS-22369 Add output for barcode in decodesp   */
/*                            (yeekung01)                                     */
/******************************************************************************/

CREATE   PROC [RDT].[rdt_600DecodeSP05] (
   @nMobile      INT,
   @nFunc        INT,
   @cLangCode    NVARCHAR( 3),
   @nStep        INT,
   @nInputKey    INT,
   @cStorerKey   NVARCHAR( 15),
   @cReceiptKey  NVARCHAR( 10),
   @cPOKey       NVARCHAR( 10),
   @cLOC         NVARCHAR( 10),
   @cBarcode     NVARCHAR( 2000)  OUTPUT,
   @cFieldName   NVARCHAR( 10),
   @cID          NVARCHAR( 18)  OUTPUT,
   @cSKU         NVARCHAR( 20)  OUTPUT,
   @nQTY         INT            OUTPUT,
   @cLottable01  NVARCHAR( 18)  OUTPUT,
   @cLottable02  NVARCHAR( 18)  OUTPUT,
   @cLottable03  NVARCHAR( 18)  OUTPUT,
   @dLottable04  DATETIME       OUTPUT,
   @dLottable05  DATETIME       OUTPUT,
   @cLottable06  NVARCHAR( 30)  OUTPUT,
   @cLottable07  NVARCHAR( 30)  OUTPUT,
   @cLottable08  NVARCHAR( 30)  OUTPUT,
   @cLottable09  NVARCHAR( 30)  OUTPUT,
   @cLottable10  NVARCHAR( 30)  OUTPUT,
   @cLottable11  NVARCHAR( 30)  OUTPUT,
   @cLottable12  NVARCHAR( 30)  OUTPUT,
   @dLottable13  DATETIME       OUTPUT,
   @dLottable14  DATETIME       OUTPUT,
   @dLottable15  DATETIME       OUTPUT,
   @nErrNo       INT            OUTPUT,
   @cErrMsg      NVARCHAR( 20)  OUTPUT
) AS
BEGIN
   SET NOCOUNT ON
   SET ANSI_NULLS OFF
   SET QUOTED_IDENTIFIER OFF
   SET CONCAT_NULL_YIELDS_NULL OFF

   DECLARE @cCustomSQL          NVARCHAR( 1000),
           @cStartSQL           NVARCHAR( 1000),
           @cOrderBySQL         NVARCHAR( 1000),
           @cExecStatements     NVARCHAR( MAX),
           @cExecArguments      NVARCHAR( MAX),
           @cColumnName         NVARCHAR( 60),
           @cDataType           NVARCHAR( 128),
           @n_Err               INT


   IF @nFunc = 600 -- Normal receiving
   BEGIN
      IF @nStep = 4 -- SKU
      BEGIN
         IF @nInputKey = 1 -- ENTER
         BEGIN
            IF @cBarcode <> ''
            BEGIN
               SELECT TOP 1 @cColumnName = Code
               FROM dbo.CodeLkUp WITH (NOLOCK)
               WHERE Listname = 'ASNSKUDeco'
               AND   Short = '1'
               AND   StorerKey = @cStorerKey
               ORDER BY 1

               IF @cColumnName <> ''
               BEGIN
                  -- Get lookup field data type
                  SET @cDataType = ''
                  SELECT @cDataType = DATA_TYPE FROM INFORMATION_SCHEMA.COLUMNS
                  WHERE TABLE_NAME = 'ReceiptDetail'
                  AND   COLUMN_NAME = @cColumnName

                  IF @cDataType <> ''
                  BEGIN
                     IF @cDataType = 'nvarchar' AND ISNULL( @cBarcode, '') = '' SET @n_Err = 0 ELSE
                     IF @cDataType = 'datetime' SET @n_Err = rdt.rdtIsValidDate( @cBarcode)    ELSE
                     IF @cDataType = 'int'      SET @n_Err = rdt.rdtIsInteger( @cBarcode)      ELSE
                     IF @cDataType = 'float'    SET @n_Err = rdt.rdtIsValidQTY( @cBarcode, 20)

                     -- Check data type
                     IF @n_Err = 0
                     BEGIN
                        SET @nErrNo = 134651
                        SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Invalid Barcode
                        GOTO Quit
                     END
                  END
               END
               ELSE
               BEGIN
                  SET @nErrNo = 134652
                  SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Decode Col Req
                  GOTO Quit
               END

               SET @cStartSQL = '
               SELECT TOP 1 @cSKU = SKU
               FROM dbo.ReceiptDetail WITH (NOLOCK)
               WHERE ReceiptKey = @cReceiptKey'

               SET @cCustomSQL = ' AND ' + @cColumnName + ' = ' + '''' + @cBarcode + ''''

               SET @cOrderBySQL = ' ORDER BY 1'

               SET @cExecStatements = @cStartSQL + @cCustomSQL + @cOrderBySQL

               SET @cExecArguments =  N'@cReceiptKey     NVARCHAR( 10), ' +
                                       '@cSKU            NVARCHAR( 20) OUTPUT '


               EXEC sp_ExecuteSql @cExecStatements
                                 ,@cExecArguments
                                 ,@cReceiptKey
                                 ,@cSKU         OUTPUT

            END
         END
      END
   END

Quit:

END

GO