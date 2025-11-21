SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO


/************************************************************************/
/* Store procedure: rdt_600RcvFilter03                                  */
/* Copyright      : LF Logistics                                        */
/*                                                                      */
/* Purpose: Filter by Lottable based on codelkup setup. For this storer */
/*          use lottable to decode sku and lottable is unique. So here  */
/*          filter by lottable to select correct receiptdetail line     */
/*                                                                      */
/* Date        Rev  Author      Purposes                                */
/* 21-02-2019  1.0  James       WMS7837 Created                         */
/* 16-08-2023  1.1  YeeKung     WMS-23201 Fix mobile   (yeekung01)      */              
/************************************************************************/

CREATE   PROCEDURE [RDT].[rdt_600RcvFilter03]
   @nMobile     INT,
   @nFunc       INT,
   @cLangCode   NVARCHAR(  3),
   @cReceiptKey NVARCHAR( 10),
   @cPOKey      NVARCHAR( 10),
   @cToLOC      NVARCHAR( 10),
   @cToID       NVARCHAR( 18),
   @cSKU        NVARCHAR( 20),
   @cUCC        NVARCHAR( 20),
   @nQTY        INT,
   @cLottable01 NVARCHAR( 18),
   @cLottable02 NVARCHAR( 18),
   @cLottable03 NVARCHAR( 18),
   @dLottable04 DATETIME,
   @dLottable05 DATETIME,
   @cLottable06 NVARCHAR( 30),
   @cLottable07 NVARCHAR( 30),
   @cLottable08 NVARCHAR( 30),
   @cLottable09 NVARCHAR( 30),
   @cLottable10 NVARCHAR( 30),
   @cLottable11 NVARCHAR( 30),
   @cLottable12 NVARCHAR( 30),
   @dLottable13 DATETIME,
   @dLottable14 DATETIME,
   @dLottable15 DATETIME,
   @cCustomSQL  NVARCHAR( MAX) OUTPUT,
   @nErrNo      INT            OUTPUT,
   @cErrMsg     NVARCHAR( 20)  OUTPUT
AS
BEGIN
   SET NOCOUNT ON
   SET QUOTED_IDENTIFIER OFF
   SET ANSI_NULLS OFF
   SET CONCAT_NULL_YIELDS_NULL OFF

   DECLARE @cNValue  NVARCHAR( 30)
   DECLARE @cDValue  DATETIME
   DECLARE @cColumnName NVARCHAR( 60)
   DECLARE @cDataType   NVARCHAR( 128)
   DECLARE @cStorerKey  NVARCHAR( 15)

   SELECT @cStorerKey = StorerKey
   FROM rdt.RDTMOBREC WITH (NOLOCK)
   WHERE mobile = @nMobile    --(yeekung01)

   SELECT TOP 1 @cColumnName = Code
   FROM dbo.CodeLkUp WITH (NOLOCK)
   WHERE Listname = 'ASNSKUDeco'
   AND   Short = '1'
   AND   StorerKey = @cStorerKey
   ORDER BY 1

   IF @cColumnName <> ''
   BEGIN
      SET @cDataType = ''
      SELECT @cDataType = DATA_TYPE FROM INFORMATION_SCHEMA.COLUMNS
      WHERE TABLE_NAME = 'ReceiptDetail'
      AND   COLUMN_NAME = @cColumnName

      IF @cDataType = 'nvarchar'
      BEGIN
         IF @cColumnName = 'LOTTABLE01' SET @cNValue = @cLottable01
         IF @cColumnName = 'LOTTABLE02' SET @cNValue = @cLottable02
         IF @cColumnName = 'LOTTABLE03' SET @cNValue = @cLottable03
         IF @cColumnName = 'LOTTABLE06' SET @cNValue = @cLottable06
         IF @cColumnName = 'LOTTABLE07' SET @cNValue = @cLottable07
         IF @cColumnName = 'LOTTABLE08' SET @cNValue = @cLottable08
         IF @cColumnName = 'LOTTABLE09' SET @cNValue = @cLottable09
         IF @cColumnName = 'LOTTABLE10' SET @cNValue = @cLottable10
         IF @cColumnName = 'LOTTABLE11' SET @cNValue = @cLottable11
         IF @cColumnName = 'LOTTABLE12' SET @cNValue = @cLottable12

         SET @cCustomSQL = @cCustomSQL + '     AND ' + @cColumnName + ' = ' + QUOTENAME( @cNValue, '''')
      END
   END

QUIT:
END -- End Procedure


GO