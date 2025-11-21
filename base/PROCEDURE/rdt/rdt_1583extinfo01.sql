SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/******************************************************************************/
/* Store procedure: rdt_1583ExtInfo01                                         */
/* Copyright      : LFLogistics                                               */
/*                                                                            */
/* Purpose: ReceiptDetail filter                                              */
/*                                                                            */
/* Date        Rev  Author      Purposes                                      */
/* 2022-04-05  1.0  YeeKung     WMS-19352 Created (yeekung01)                 */
/* 2022-06-20  1.1  YeeKung     WMS-20053 Add Putaway remark (yeekung01)     */
/******************************************************************************/

CREATE   PROCEDURE [RDT].[rdt_1583ExtInfo01]
    @nMobile     INT
   ,@nFunc       INT
   ,@cLangCode   NVARCHAR(  3)
   ,@nStep         INT          
   ,@nInputKey     INT          
   ,@cFacility     NVARCHAR( 5) 
   ,@cStorerKey    NVARCHAR( 15)
   ,@cReceiptKey   NVARCHAR( 10)
   ,@cSSCC         NVARCHAR( 20)
   ,@cLOC          NVARCHAR( 20)
   ,@cID           NVARCHAR( 18)
   ,@cSKU          NVARCHAR( 20)
   ,@nQTY          INT      
   ,@cLottable01   NVARCHAR( 18)
   ,@cLottable02   NVARCHAR( 18)
   ,@cLottable03   NVARCHAR( 18)
   ,@dLottable04   DATETIME
   ,@dLottable05   DATETIME
   ,@cLottable06   NVARCHAR( 30)
   ,@cLottable07   NVARCHAR( 30)
   ,@cLottable08   NVARCHAR( 30)
   ,@cLottable09   NVARCHAR( 30)
   ,@cLottable10   NVARCHAR( 30)
   ,@cLottable11   NVARCHAR( 30)
   ,@cLottable12   NVARCHAR( 30)
   ,@dLottable13   DATETIME     
   ,@dLottable14   DATETIME     
   ,@dLottable15   DATETIME     
   ,@cOption       NVARCHAR( 1) 
   ,@dArriveDate   DATETIME      
   ,@cExtendedInfo NVARCHAR(20)  OUTPUT
   ,@nErrNo      INT            OUTPUT
   ,@cErrMsg     NVARCHAR( 20)  OUTPUT
AS
BEGIN
   SET NOCOUNT ON
   SET QUOTED_IDENTIFIER OFF
   SET ANSI_NULLS OFF
   SET CONCAT_NULL_YIELDS_NULL OFF

   DECLARE @cUserName NVARCHAR(18)

   SELECT @cUserName=USERNAME
   FROM RDT.RDTMOBREC (NOLOCK)
   WHERE MOBILE=@nMobile

   IF  (SELECT COUNT(1)
               FROM receiptdetail (nolock)
               where receiptkey=@cReceiptKey
                AND SUBSTRING(SKU,1,10)=SUBSTRING(@cSKU,1,10)
               --AND UserDefine01=@cSSCC
               and toid<>'')=1
   BEGIN
      SET @cExtendedInfo= 'YES'

      IF EXISTS(SELECT  1
                  FROM LOTXLOCXID LLI (NOLOCK) JOIN LOC loc(NOLOCK) ON LLI.LOC=LOC.LOC
                   JOIN SKU SKU (NOLOCK) ON SKU.SKU =LLI.SKU AND SKU.storerkey=LLI.storerkey
                  WHERE  SKU.STORERKEY=@cstorerkey
                  AND LLI.SKU=@csku
                  GROUP BY SKU.REORDERPOINT
                  HAVING SUM(LLI.QTY-LLI.qtyallocated-LLI.qtypicked-LLI.qtyreplen) <CASE WHEN ISNULL(SKU.REORDERPOINT,'')='' THEN 0 ELSE SKU.REORDERPOINT END)
          OR NOT EXISTS (SELECT  1
                  FROM LOTXLOCXID LLI (NOLOCK) JOIN LOC loc(NOLOCK) ON LLI.LOC=LOC.LOC
                   JOIN SKU SKU (NOLOCK) ON SKU.SKU =LLI.SKU AND SKU.storerkey=LLI.storerkey
                  WHERE SKU.STORERKEY=@cstorerkey
                  AND LLI.SKU=@csku
                  )
         SET @cExtendedInfo=@cExtendedInfo+' Pick Phase'
      ELSE
         SET @cExtendedInfo=@cExtendedInfo+' Buffer'
   END
   ELSE
   BEGIN
      SET @cExtendedInfo= 'NO' 

      IF (SELECT COUNT(1)
               FROM receiptdetail (nolock)
               where receiptkey=@cReceiptKey
                AND SKU=@cSKU
               --AND UserDefine01=@cSSCC
               and ISNULL(toid,'')<>'') in(0,1)
         SET @cExtendedInfo=@cExtendedInfo+' Pick Phase'
      ELSE
         SET @cExtendedInfo=@cExtendedInfo+' Buffer'
   END

   -- Logging
   EXEC RDT.rdt_STD_EventLog
      @cActionType     = '3', -- Sign-in
      @cUserID         = @cUserName,
      @nMobileNo       = @nMobile,
      @nFunctionID     = @nFunc,
      @cFacility       = @cFacility,
      @cStorerKey      = @cStorerKey,
      @nStep           = @nStep,
      @cReceiptKey     = @cReceiptkey,
      @cSKU            = @cSKU,
      @cRefNo1         = @cExtendedInfo,
      @cRemark         = @cSSCC

QUIT:
END -- End Procedure

GO