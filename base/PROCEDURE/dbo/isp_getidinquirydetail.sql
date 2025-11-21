SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER ON;
GO
/******************************************************************************/    
/* Function: isp_GetIDInquiryDetail                                           */    
/* Creation Date: 12-NOV-2014                                                 */    
/* Copyright: LFL                                                             */    
/* Written by: YTWan                                                          */    
/*                                                                            */    
/* Purpose:                                                                   */    
/*                                                                            */    
/* Input Parameters: Search Parameters                                        */    
/*                                                                            */    
/* OUTPUT Parameters: Table                                                   */    
/*                                                                            */    
/* Return Status: NONE                                                        */    
/*                                                                            */    
/* Usage:                                                                     */    
/*                                                                            */    
/* Local Variables:                                                           */    
/*                                                                            */    
/* Called By: When Retrieve Records                                           */    
/*                                                                            */    
/* PVCS Version: 1.13                                                         */    
/*                                                                            */    
/* Version: 5.4                                                               */    
/* Data Modifications:                                                        */    
/*                                                                            */    
/* Updates:                                                                   */    
/* Date         Author     Ver   Purposes                                     */    
/******************************************************************************/    

CREATE PROC [dbo].[isp_GetIDInquiryDetail](  @c_ReceiptKey  NVARCHAR(10)
                                          ,  @c_ID          NVARCHAR(18)
                                          ) 
AS  
BEGIN
   SET NOCOUNT ON  
   SET QUOTED_IDENTIFIER OFF  
   SET ANSI_NULLS OFF  
   SET CONCAT_NULL_YIELDS_NULL OFF  

   SELECT  PLIMG.ReceiptKey
         , PLIMG.ID  
         , PLIMG.LotNo   
         , PLIMG.Storerkey     
         , PLIMG.Sku             
         , PLIMG.Descr          
         , UOM         = CASE WHEN PACK.Packkey IS NULL THEN '' ELSE PLIMG.UOM END            
         , QtyReceived = CASE WHEN PACK.Packkey IS NULL THEN PLIMG.QtyReceived
                         WHEN PLIMG.UOM = PACK.PackUOM1 AND PACK.Casecnt   > 0 THEN PLIMG.QtyReceived / PACK.Casecnt
                         WHEN PLIMG.UOM = PACK.PackUOM2 AND PACK.InnerPack > 0 THEN PLIMG.QtyReceived / PACK.InnerPack   
                         WHEN PLIMG.UOM = PACK.PackUOM4 AND PACK.Pallet    > 0 THEN PLIMG.QtyReceived / PACK.Pallet
                         ELSE PLIMG.QtyReceived
                         END  
         , PLIMG.ReceiptDate
         , PLIMG.AddDate
         , '    '          --rowfocusindicatorcol
   FROM PALLETIMAGE PLIMG WITH (NOLOCK)
   LEFT JOIN SKU    SKU   WITH (NOLOCK) ON (PLIMG.Storerkey = SKU.Storerkey)
                                        AND(PLIMG.Sku = SKU.Sku)
   LEFT JOIN PACK   PACK  WITH (NOLOCK) ON (SKU.Packkey = PACK.Packkey)
   WHERE ReceiptKey = @c_Receiptkey
   AND   ID         = @c_ID 
END

GO