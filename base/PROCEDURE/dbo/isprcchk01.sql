SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/************************************************************************/
/* Store procedure: ispRCCHK01                                          */
/* Copyright: IDS                                                       */
/* Purpose: VF TBL TW Receiving is using UCC (interfaced). Once receive */
/*          UCC is not use in warehouse. So upon finalize, need to      */
/*          kill the UCC                                                */
/*                                                                      */
/* PVCS Version: 1.1                                                    */  
/*                                                                      */  
/* Modifications log:                                                   */
/*                                                                      */
/* Date         Author    Ver.  Purposes                                */
/* 2013-03-14   Ung       1.0   SOS288993 Blank UCC.ReceiptKey & LineNo */
/* 2014-01-20   YTWan     1.1   SOS#298639 - Washington - Finalize by   */
/*                              Receipt Line. Add Default parameters    */
/*                              @c_ReceiptLineNumber.(Wan01)            */
/************************************************************************/

CREATE PROCEDURE [dbo].[ispRCCHK01]
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
   
   DECLARE @cToLOC CHAR( 10)
   DECLARE @cToID  CHAR( 18)
   DECLARE @cSKU   CHAR( 20)
   DECLARE @nRDQTY INT
   DECLARE @nUCCQTY INT
   DECLARE @cPOType NVARCHAR(10)
   DECLARE @cPOKey  NVARCHAR(10)
   
   SET @b_Success = 1
   
   -- Get Receipt info
   SELECT TOP 1
      @cPOType = PO.POTYPE
   FROM dbo.Receipt R WITH (NOLOCK)
   INNER JOIN dbo.ReceiptDetail RD WITH (NOLOCK) ON RD.ReceiptKey = R.ReceiptKey
   INNER JOIN dbo.PO PO WITH (NOLOCK) ON PO.POKey = RD.POKey
   WHERE R.ReceiptKey = @c_ReceiptKey

   IF @@ROWCOUNT = 0
      RETURN

      
   -- Normal receipt
   --IF @c_RecType LIKE '%X'
   IF @cPOType NOT LIKE '%-X'
   BEGIN
      UPDATE UCC SET
         Status = '6'
      WHERE ReceiptKey = @c_ReceiptKey 
      IF @@ERROR <> 0
      BEGIN
         SET @b_Success = 0
         SET @c_Errmsg = 'Error updating UCC (ispRCCHK01)'
      END
   END
   ELSE
   BEGIN 
      -- Crossdock receipt
      SET @cSKU = ''
      SELECT TOP 1 
         @cToLOC = RD.ToLOC, 
         @cToID = RD.ToID, 
         @cSKU = RD.SKU, 
         @nRDQTY = SUM( BeforeReceivedQTY), 
         @nUCCQTY = 
            (SELECT SUM( UCC.QTY) 
            FROM UCC WITH (NOLOCK)
            WHERE RD.ReceiptKey = UCC.ReceiptKey 
               AND RD.ToLOC = UCC.LOC 
               AND RD.ToID = UCC.ID 
               AND RD.SKU = UCC.SKU 
               AND UCC.Status = '1')
      FROM ReceiptDetail RD
      WHERE RD.ReceiptKey = @c_ReceiptKey
      GROUP BY RD.ReceiptKey, RD.ToLOC, RD.ToID, RD.SKU
      HAVING SUM( BeforeReceivedQTY) <> 
         (SELECT SUM( UCC.QTY) 
         FROM UCC WITH (NOLOCK)
         WHERE RD.ReceiptKey = UCC.ReceiptKey 
            AND RD.ToLOC = UCC.LOC 
            AND RD.ToID = UCC.ID 
            AND RD.SKU = UCC.SKU 
            AND UCC.Status = '1')
   
      IF @cSKU <> ''
      BEGIN
         SET @b_Success = 0
         SET @c_Errmsg = 'ReceiveDetail.QTY <> UCC.QTY. ' + 
            ' SKU=' + RTRIM( @cSKU) + 
            ' LOC=' + RTRIM( @cToLOC) + 
            ' ID=' + RTRIM( @cToID) + 
            ' RDQTY=' + CAST( @nRDQTY AS VARCHAR( 10)) + 
            ' UCCQTY=' + CAST( @nUCCQTY AS VARCHAR( 10)) + 
            ' (ispRCCHK01)'
      END
   END
END

GO