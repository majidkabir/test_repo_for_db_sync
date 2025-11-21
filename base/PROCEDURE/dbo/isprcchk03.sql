SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/************************************************************************/
/* Store procedure: ispRCCHK03                                          */
/* Copyright: IDS                                                       */
/* Purpose:                                                             */
/*                                                                      */
/* Modifications log:                                                   */
/*                                                                      */
/* Date         Author    Ver.  Purposes                                */
/* 2013-03-14   Ung       1.0   SOS#293969 Update UCC.Status by LoseUCC */
/*                              flag in Location Master                 */
/* 2014-01-20   YTWan     1.1   SOS#298639 - Washington - Finalize by   */
/*                              Receipt Line. Add Default parameters    */
/*                              @c_ReceiptLineNumber.(Wan01)            */
/************************************************************************/

CREATE PROCEDURE [dbo].[ispRCCHK03]
   @c_ReceiptKey       NVARCHAR(10),
   @b_Success          INT = 1  OUTPUT,
   @n_ErrNo            INT = 0  OUTPUT,
   @c_Errmsg           NVARCHAR(250) = '' OUTPUT
,  @c_ReceiptLineNumber  NVARCHAR(5) = ''       --(Wan01)
AS
BEGIN
   SET NOCOUNT ON
   SET QUOTED_IDENTIFIER OFF
   SET ANSI_NULLS OFF
   SET CONCAT_NULL_YIELDS_NULL OFF

   DECLARE @c_RecType   NVARCHAR( 10)
   DECLARE @c_DocType   NVARCHAR( 1)
   DECLARE @c_StorerKey NVARCHAR( 15)
   
   DECLARE @cToLOC NVARCHAR( 10)
         , @cLoseUCC NVARCHAR(1)
         , @cUCCNo   NVARCHAR(20)
         , @cSKU     NVARCHAR(20)
         , @cReceiptLineNumber NVARCHAR(5)
         , @cID      NVARCHAR(18)
         
   SET @b_Success = 1
   
   
   SET @c_StorerKey = ''
   
   SELECT @c_StorerKey = StorerKey 
   FROM dbo.Receipt WITH (NOLOCK)
   WHERE ReceiptKey = @c_ReceiptKey
   
   
   DECLARE CUR_RECEIPT CURSOR LOCAL READ_ONLY FAST_FORWARD FOR   
   SELECT UCCNo, SKU, ReceiptLineNumber, Loc, ID FROM dbo.UCC WITH (NOLOCK)
   WHERE ReceiptKey = @c_ReceiptKey
   AND StorerKey = @c_StorerKey
   
   OPEN CUR_RECEIPT      
   FETCH NEXT FROM CUR_RECEIPT INTO @cUCCNo, @cSKU, @cReceiptLineNumber, @cToLoc, @cID
   WHILE @@FETCH_STATUS <> -1      
   BEGIN 
      
      SET @cLoseUCC = '0'
      
      SELECT @cLoseUCC = LoseUCC
      FROM dbo.LOC WITH (NOLOCK)
      WHERE Loc = @cToLoc
      
      IF @cLoseUCC = '1'
      BEGIN 
         UPDATE dbo.UCC WITH (ROWLOCK)
         SET Status = '6'
         WHERE UCCNo = @cUCCNo
         AND   SKU   = @cSKU
         AND   Loc   = @cToLoc
         AND   ID    = @cID
         AND   ReceiptKey = @c_ReceiptKey
         AND   ReceiptLinenumber = @cReceiptLineNumber
         
         IF @@ERROR <> 0 
         BEGIN
           SET @b_Success = 0
           SET @c_Errmsg = 'Error updating UCC (ispRCCHK03)'
         END
      END
      
      FETCH NEXT FROM CUR_RECEIPT INTO @cUCCNo, @cSKU, @cReceiptLineNumber, @cToLoc, @cID
      
   END     

END

GO