SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/************************************************************************/  
/* Store procedure: ispPieceRcvExtInfo06                                */  
/* Copyright      : IDS                                                 */  
/*                                                                      */  
/* Purpose: RDT Piece Receiving show extended info @ step5              */  
/*          Show SKU Received over total SKU per ID                     */  
/*                                                                      */  
/* Called from:                                                         */  
/*                                                                      */  
/* Exceed version: 5.4                                                  */  
/*                                                                      */  
/* Modifications log:                                                   */  
/*                                                                      */  
/* Date        Rev  Author      Purposes                                */  
/* 2018-02-12  1.0  ChewKP      WMS-3872. Created                       */  
/************************************************************************/  
  
CREATE PROCEDURE [dbo].[ispPieceRcvExtInfoLV]  
   @c_ReceiptKey     NVARCHAR(10),  
   @c_POKey          NVARCHAR(10),  
   @c_ToLOC          NVARCHAR(10),  
   @c_ToID           NVARCHAR(18),  
   @c_Lottable01     NVARCHAR(18),  
   @c_Lottable02     NVARCHAR(18),  
   @c_Lottable03     NVARCHAR(18),  
   @d_Lottable04     DATETIME,  
   @c_StorerKey      NVARCHAR(15),  
   @c_SKU            NVARCHAR(20),  
   @c_oFieled01      NVARCHAR(20) OUTPUT  
AS  
BEGIN  
   SET NOCOUNT ON  
   SET QUOTED_IDENTIFIER OFF  
   SET ANSI_NULLS OFF  
   SET CONCAT_NULL_YIELDS_NULL OFF  
  
   DECLARE @n_TotalQty      INT,  
           @n_ReceivedQty   INT,  
           @n_Qty           INT,  
           @n_Step          INT,  
           @c_Qty           NVARCHAR( 5),  
           @c_ExtASN        NVARCHAR( 20),  
           @n_QtyReceive    INT,  
           @n_QtyExpected   INT,  
           @n_QtyInProgress INT  
  
   -- Get user input qty here as not a pass in value  
   SELECT @n_Step = Step  
          --@c_Qty = I_Field05,  
          --@c_ExtASN = V_String26  
   FROM RDT.RDTMOBREC WITH (NOLOCK)  
   WHERE UserName = sUser_sName()  
  
   IF @n_Step = 5  
   BEGIN  
        
      -- Get ASN info  
      SELECT @n_QtyReceive = ISNULL(SUM(QtyReceived),0)   
      FROM dbo.ReceiptDetail WITH (NOLOCK)   
      WHERE ReceiptKey = @c_ReceiptKey  
      AND SKU = @c_SKU  
      AND lottable02 = @c_Lottable02  
      AND FinalizeFlag = 'Y'  
        
      SELECT @n_QtyInProgress = ISNULL(SUM(BeforeReceivedQty),0)   
      FROM dbo.ReceiptDetail WITH (NOLOCK)   
      WHERE ReceiptKey = @c_ReceiptKey  
      AND SKU = @c_SKU  
      AND lottable02 = @c_Lottable02  
      AND FinalizeFlag = 'N'  
              
      SELECT @n_QtyExpected = ISNULL(SUM(QtyExpected),0)   
      FROM dbo.ReceiptDetail WITH (NOLOCK)   
      WHERE ReceiptKey = @c_ReceiptKey  
      AND SKU = @c_SKU  
      AND lottable02 = @c_Lottable02  
        
      SELECT @c_oFieled01 = 'REC QTY:  ' + CAST( @n_QtyReceive + @n_QtyInProgress + 1  AS NVARCHAR( 5)) + '/' +  CAST( @n_QtyExpected AS NVARCHAR( 5))     
        
        
        
   END  
     
  
      
  
QUIT:  
END -- End Procedure  

GO