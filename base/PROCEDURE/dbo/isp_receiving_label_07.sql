SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/************************************************************************/  
/* Stored Procedure: isp_Receiving_Label_07                             */  
/* Creation Date: 22/05/2013                                            */  
/* Copyright: IDS                                                       */  
/* Written by: GTGOH                                                    */  
/*                                                                      */  
/* Purpose: SOS#273208                                                  */  
/*                                                                      */  
/* Called By: r_dw_receivinglabel07                                     */  
/*                                                                      */  
/* PVCS Version: 1.2                                                    */  
/*                                                                      */  
/* Version: 5.4                                                         */  
/*                                                                      */  
/* Data Modifications:                                                  */  
/*                                                                      */  
/* Updates:                                                             */  
/* Date         Author  Ver   Purposes                                  */  
/************************************************************************/  
  
CREATE PROC [dbo].[isp_Receiving_Label_07] (  
   @c_receiptkey     nvarchar(10),  
   @c_receiptline    nvarchar(5),  
   @n_qty            int)  
 AS  
 BEGIN  
    SET NOCOUNT ON   
    SET QUOTED_IDENTIFIER OFF   
    SET ANSI_NULLS OFF     
    SET CONCAT_NULL_YIELDS_NULL OFF  
  
   DECLARE @Result TABLE(  
           SKU         varchar(20) NULL,  
           ALTSKU      varchar(20) NULL,  
           Lottable03  VARCHAR(18) NULL,  
           EditWho     varchar(18) NULL)  
    
   IF ISNULL(@n_qty,0) = 0  
   BEGIN  
      SET @n_qty = 1  
   END  
  
   WHILE @n_qty > 0  
   BEGIN  
  
      INSERT INTO @Result (SKU, ALTSKU, Lottable03, EditWho)  
      SELECT UPPER(RECEIPTDETAIL.SKU) as SKU,   
      SKU.ALTSKU,  
            UPPER(RECEIPTDETAIL.Lottable03) as Lottable03,  
      RECEIPTDETAIL.EditWho  
      FROM RECEIPT WITH (NOLOCK),  
      RECEIPTDETAIL WITH (NOLOCK),     
            SKU WITH (NOLOCK)  
      WHERE ( SKU.StorerKey = RECEIPTDETAIL.StorerKey ) and    
            ( SKU.Sku = RECEIPTDETAIL.Sku ) and    
            ( ( RECEIPTDETAIL.ReceiptKey = @c_receiptkey ) and  
        ( RECEIPTDETAIL.ReceiptlineNumber = @c_receiptline ) )  AND  
      ( RECEIPT.RECEIPTKEY = RECEIPTDETAIL.Receiptkey )   
        
      SET @n_qty = @n_qty - 1  
   END  
     
   SELECT * FROM @Result  
  
END

GO