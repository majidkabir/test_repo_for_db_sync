SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/************************************************************************/
/* Store procedure: rdt_ReceiveReserval_UCCQtyUnReceive                 */
/* Copyright      : IDS                                                 */
/*                                                                      */
/* Purposes:                                                            */
/* 1) Update UCC QTY and RECEIPTDETAIL QTY - Unreceive                  */
/*                                                                      */
/* Called from: 3                                                       */
/*    1. From PowerBuilder                                              */
/*    2. From scheduler                                                 */
/*    3. From others stored procedures or triggers                      */
/*    4. From interface program. DX, DTS                                */
/*                                                                      */
/* Exceed version: 5.4                                                  */
/*                                                                      */
/* Modifications log:                                                   */
/*                                                                      */
/* Date        Rev  Author      Purposes                                */
/************************************************************************/

CREATE PROC [RDT].[rdt_ReceiveReserval_UCCQtyUnReceive] (
   @cReceiptKey    NVARCHAR(10),
   @cLOC           NVARCHAR(10),
   @cID            NVARCHAR(18),
   @cUCC           NVARCHAR(20),
   @cStorerkey     NVARCHAR(15),
   @cQTY           NVARCHAR(4),
   @cReceiptLineNo NVARCHAR(5),
   @nError         INT      OUTPUT
) AS
BEGIN
SET NOCOUNT ON
SET QUOTED_IDENTIFIER OFF
SET ANSI_NULLS OFF
SET CONCAT_NULL_YIELDS_NULL OFF

   DECLARE @n_debug          INT   
 
   DECLARE @nFinalBFQty      INT,
           @nOriginalBFQty   INT

   DECLARE @cOriginalLOC     NVARCHAR(10),
           @cOriginalID      NVARCHAR(18)
   
   SET @n_debug = 0
   SET @nError = 0

   BEGIN TRAN
      
     SELECT @cOriginalLOC = RTRIM(UCC.LOC),
            @cOriginalID = RTRIM(UCC.ID)
     FROM dbo.UCC UCC (NOLOCK)
     WHERE  Storerkey = @cStorerkey 
       AND  ReceiptKey = @cReceiptKey 
       AND  ReceiptLineNumber = @cReceiptLineNo 
       AND  UCCNo = @cUCC 
       AND  Status = '1'
           

      UPDATE dbo.UCC WITH (ROWLOCK)
         SET Status = '0',
             ReceiptKey = '',
             ReceiptLineNumber = '',
             LOC = '',
             ID = ''
      WHERE Storerkey = @cStorerkey 
       AND  ReceiptKey = @cReceiptKey 
       AND  ReceiptLineNumber = @cReceiptLineNo 
       AND  UCCNo = @cUCC 
       AND  Status = '1'

   IF @@ERROR = 0 
   BEGIN
      COMMIT TRAN
   END 
   ELSE
   BEGIN
      ROLLBACK TRAN
      SELECT @nError = 1
      GOTO QUIT
   END              

   BEGIN TRAN

      SELECT @nFinalBFQty = RD.BeforeReceivedQty - CAST(@cQTY AS INT),
             @nOriginalBFQty = RD.BeforeReceivedQty
      FROM dbo.RECEIPTDETAIL RD (NOLOCK)
      WHERE RD.Storerkey = @cStorerkey 
       AND  RD.ReceiptKey = @cReceiptKey 
       AND  RD.ReceiptLineNumber = @cReceiptLineNo 

      IF @nFinalBFQty < 0
      BEGIN
         SELECT @nFinalBFQty = 0
      END

      UPDATE dbo.RECEIPTDETAIL WITH (ROWLOCK)
         SET BeforeReceivedQty = @nFinalBFQty,
             Trafficcop = NULL
      WHERE Storerkey = @cStorerkey 
       AND  ReceiptKey = @cReceiptKey 
       AND  ReceiptLineNumber = @cReceiptLineNo 

   IF @@ERROR = 0 
   BEGIN
      COMMIT TRAN
   END 
   ELSE
   BEGIN
      ROLLBACK TRAN
      SELECT @nError = 1

         UPDATE dbo.UCC WITH (ROWLOCK)
         SET Status = '1',
             ReceiptKey = @cReceiptKey,
             ReceiptLineNumber = @cReceiptLineNo,
             LOC = @cOriginalLOC,
             ID = @cOriginalID
      WHERE Storerkey = @cStorerkey 
       AND  ReceiptKey = @cReceiptKey 
       AND  ReceiptLineNumber = @cReceiptLineNo 
       AND  UCCNo = @cUCC 
       AND  Status = '0'

      GOTO QUIT
   END                     


QUIT:
END


GO