SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/************************************************************************/
/* Store procedure: rdt_608RcvFilter02                                  */
/* Copyright      : LF Logistics                                        */
/*                                                                      */
/* Purpose: Filter by Lot01                                             */
/*                                                                      */
/* Date        Rev  Author      Purposes                                */
/* 2020-05-28  1.0  James       WMS-13257 Created                       */
/************************************************************************/

CREATE PROCEDURE [RDT].[rdt_608RcvFilter02]
    @nMobile     INT      
   ,@nFunc       INT       
   ,@cLangCode   NVARCHAR(  3)
   ,@cReceiptKey NVARCHAR( 10)
   ,@cPOKey      NVARCHAR( 10)
   ,@cToLOC      NVARCHAR( 10)
   ,@cToID       NVARCHAR( 18)
   ,@cSKU        NVARCHAR( 20)
   ,@cUCC        NVARCHAR( 20)
   ,@nQTY        INT          
   ,@cLottable01 NVARCHAR( 18)
   ,@cLottable02 NVARCHAR( 18)
   ,@cLottable03 NVARCHAR( 18)
   ,@dLottable04 DATETIME     
   ,@dLottable05 DATETIME     
   ,@cLottable06 NVARCHAR( 30)
   ,@cLottable07 NVARCHAR( 30)
   ,@cLottable08 NVARCHAR( 30)
   ,@cLottable09 NVARCHAR( 30)
   ,@cLottable10 NVARCHAR( 30)
   ,@cLottable11 NVARCHAR( 30)
   ,@cLottable12 NVARCHAR( 30)
   ,@dLottable13 DATETIME     
   ,@dLottable14 DATETIME     
   ,@dLottable15 DATETIME     
   ,@cCustomSQL  NVARCHAR( MAX) OUTPUT 
   ,@nErrNo      INT            OUTPUT 
   ,@cErrMsg     NVARCHAR( 20)  OUTPUT 
AS
BEGIN
   SET NOCOUNT ON
   SET QUOTED_IDENTIFIER OFF
   SET ANSI_NULLS OFF
   SET CONCAT_NULL_YIELDS_NULL OFF

   DECLARE @nSKUNotInASN         INT
   DECLARE @cExternReceiptKey    NVARCHAR( 20)
   DECLARE @cUserDefine01        NVARCHAR( 30)
   DECLARE @cUserDefine02        NVARCHAR( 30)
   DECLARE @cUserDefine03        NVARCHAR( 30)
   DECLARE @cUserDefine04        NVARCHAR( 30)
   DECLARE @cUserDefine05        NVARCHAR( 30)
   DECLARE @dUserDefine06        DATETIME
   DECLARE @dUserDefine07        DATETIME
   DECLARE @cUserDefine08        NVARCHAR( 30)
   DECLARE @cUserDefine09        NVARCHAR( 30)
   DECLARE @cUserDefine10        NVARCHAR( 30)
   
   SET @nSKUNotInASN = 0
   IF NOT EXISTS ( SELECT 1 FROM dbo.RECEIPTDETAIL WITH (NOLOCK)
                   WHERE ReceiptKey = @cReceiptKey
                   AND   SKU = @cSKU)
      SET @nSKUNotInASN = 1
   ELSE
      SET @nSKUNotInASN = 0

/*
   If scan the SKU do not in receiptdetail, 
   RDT generate a new receiptdetail line base on 1st receipdetail.ExternReceiptKey, 
   Lottable06 ~ Lottable10, lottable02, 07,08,09, Userdefine01~10 , 
*/ 

   IF @nSKUNotInASN = 1
   BEGIN
      SELECT TOP 1
         @cExternReceiptKey = ExternReceiptKey,
         @cLottable06 = Lottable06,
         @cLottable07 = Lottable07,
         @cLottable08 = Lottable08,
         @cLottable09 = Lottable09,
         @cLottable10 = Lottable10,
         @cUserDefine01 = UserDefine01,
         @cUserDefine02 = UserDefine02,
         @cUserDefine03 = UserDefine03,
         @cUserDefine04 = UserDefine04,
         @cUserDefine05 = UserDefine05,
         @dUserDefine06 = UserDefine06,
         @dUserDefine07 = UserDefine07,
         @cUserDefine08 = UserDefine08,
         @cUserDefine09 = UserDefine09,
         @cUserDefine10 = UserDefine10
      FROM dbo.RECEIPTDETAIL WITH (NOLOCK)
      WHERE ReceiptKey = @cReceiptKey
      ORDER BY 1
      
      IF @@ROWCOUNT = 1
      BEGIN
         SET @cCustomSQL = @cCustomSQL + 
            '     AND ExternReceiptKey = ' + QUOTENAME( @cExternReceiptKey, '''')
         SET @cCustomSQL = @cCustomSQL + 
            '     AND Lottable02 = ' + QUOTENAME( @cLottable02, '''')
         SET @cCustomSQL = @cCustomSQL + 
            '     AND Lottable06 = ' + QUOTENAME( @cLottable06, '''')
         SET @cCustomSQL = @cCustomSQL + 
            '     AND Lottable07 = ' + QUOTENAME( @cLottable07, '''')
         SET @cCustomSQL = @cCustomSQL + 
            '     AND Lottable08 = ' + QUOTENAME( @cLottable08, '''')
         SET @cCustomSQL = @cCustomSQL + 
            '     AND Lottable09 = ' + QUOTENAME( @cLottable09, '''')
         SET @cCustomSQL = @cCustomSQL + 
            '     AND Lottable10 = ' + QUOTENAME( @cLottable10, '''')
         SET @cCustomSQL = @cCustomSQL + 
            '     AND UserDefine01 = ' + QUOTENAME( @cUserDefine01, '''')
         SET @cCustomSQL = @cCustomSQL + 
            '     AND UserDefine02 = ' + QUOTENAME( @cUserDefine02, '''')
         SET @cCustomSQL = @cCustomSQL + 
            '     AND UserDefine03 = ' + QUOTENAME( @cUserDefine03, '''')
         SET @cCustomSQL = @cCustomSQL + 
            '     AND UserDefine04 = ' + QUOTENAME( @cUserDefine04, '''')
         SET @cCustomSQL = @cCustomSQL + 
            '     AND UserDefine05 = ' + QUOTENAME( @cUserDefine05, '''')
         IF ISNULL( @dUserDefine06, 0) = 0
            SET @cCustomSQL = @cCustomSQL + '     AND UserDefine06 = UserDefine06'
         ELSE
            SET @cCustomSQL = @cCustomSQL + 
            '     AND UserDefine06 = ''' + CONVERT( DATETIME, @dUserDefine06, 120) + ''
         IF ISNULL( @dUserDefine07, 0) = 0
            SET @cCustomSQL = @cCustomSQL + '     AND UserDefine07 = UserDefine07'
         ELSE
            SET @cCustomSQL = @cCustomSQL + 
            '     AND UserDefine07 = ''' + CONVERT( DATETIME, @dUserDefine07, 120) + ''
         SET @cCustomSQL = @cCustomSQL + 
            '     AND UserDefine08 = ' + QUOTENAME( @cUserDefine08, '''')
         SET @cCustomSQL = @cCustomSQL + 
            '     AND UserDefine09 = ' + QUOTENAME( @cUserDefine09, '''')
         SET @cCustomSQL = @cCustomSQL + 
            '     AND UserDefine10 = ' + QUOTENAME( @cUserDefine10, '''')
      END
   END
   
QUIT:
END -- End Procedure


GO