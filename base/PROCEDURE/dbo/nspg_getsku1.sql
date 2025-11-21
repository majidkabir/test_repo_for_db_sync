SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
/************************************************************************/    
/* Stored Procedure: nspg_GETSKU1                                       */    
/* Creation Date:                                                       */    
/* Copyright: IDS                                                       */    
/* Written by:                                                          */    
/*                                                                      */    
/* Purpose:                                                             */    
/*                                                                      */    
/* Called By:                                                           */    
/*                                                                      */    
/* PVCS Version: 1.4                                                    */    
/*                                                                      */    
/* Version: 5.4                                                         */    
/*                                                                      */    
/* Data Modifications:                                                  */    
/*                                                                      */    
/* Updates:                                                             */    
/* Date         Author        Purposes                                  */    
/* 30-Nov-09    SPChin        SOS154134 - Bug fixed for if SKU exist,   */                              
/*                                        return Packkey and UOM        */    
/* 24-Jan-2017  TLTING01 1.1  SET ANSI NULL option                      */
/************************************************************************/    
    
CREATE PROC    [dbo].[nspg_GETSKU1]    
               @c_StorerKey   NVARCHAR(15)    
,              @c_sku         NVARCHAR(20)          OUTPUT    
,              @b_success     int               OUTPUT    
,              @n_err         int               OUTPUT    
,              @c_errmsg      NVARCHAR(250)         OUTPUT    
,              @c_uom         NVARCHAR(10)          OUTPUT    
,              @c_packkey     NVARCHAR(10)          OUTPUT    
AS    
BEGIN    
   SET NOCOUNT ON     
   SET ANSI_NULLS OFF
   SET QUOTED_IDENTIFIER OFF     
   SET CONCAT_NULL_YIELDS_NULL OFF    
    
   DECLARE @n_continue int    
   SELECT @n_continue = 1    
   SELECT @b_success = 1    
    
  IF NOT EXISTS (SELECT 1 FROM SKU WITH (NOLOCK) WHERE Sku = @c_sku and StorerKey = @c_StorerKey)    
  BEGIN    
     IF EXISTS (SELECT 1 FROM SKU WITH (NOLOCK) WHERE AltSku = @c_sku and StorerKey = @c_StorerKey)    
     BEGIN    
        SELECT @c_sku = Sku, @c_packkey = SKU.PackKey, @c_uom = PACK.PackUOM3    
        FROM SKU WITH (NOLOCK)  
        JOIN PACK WITH (NOLOCK) ON (SKU.PackKey = PACK.PackKey)  
        WHERE AltSku = @c_sku and StorerKey = @c_StorerKey    
  
        RETURN    
     END    
         
     IF EXISTS (SELECT 1 FROM SKU WITH (NOLOCK) WHERE RetailSku = @c_sku and StorerKey = @c_StorerKey)    
     BEGIN    
        SELECT @c_sku = Sku, @c_packkey = SKU.PackKey, @c_uom = PACK.PackUOM3    
        FROM SKU WITH (NOLOCK)
        JOIN PACK WITH (NOLOCK) ON (SKU.PackKey = PACK.PackKey)   
        WHERE RetailSku = @c_sku and StorerKey = @c_StorerKey     
  
        RETURN    
     END    
  
     IF EXISTS (SELECT 1 FROM SKU WITH (NOLOCK) WHERE ManufacturerSku = @c_sku and StorerKey = @c_StorerKey)    
     BEGIN    
        SELECT @c_sku = Sku, @c_packkey = SKU.PackKey, @c_uom = PACK.PackUOM3    
        FROM SKU WITH (NOLOCK)
        JOIN PACK WITH (NOLOCK) ON (SKU.PackKey = PACK.PackKey)    
        WHERE ManufacturerSku = @c_sku and StorerKey = @c_StorerKey         
  
        RETURN            
     END    
  
     IF EXISTS (SELECT 1 FROM UPC WITH (NOLOCK) WHERE Upc = @c_sku AND Storerkey = @c_storerkey) -- SOS32885    
     BEGIN    
     -- BEGIN UPC Code Found    
         SELECT @c_sku = Sku, @c_packkey = PackKey, @c_uom = UOM    
         FROM  UPC WITH (NOLOCK)   
         WHERE Upc = @c_sku    
         AND Storerkey = @c_storerkey  -- SOS32885    
     END    
     ELSE    
     BEGIN    
        SELECT @n_continue=3    
        SELECT @n_err=68500    
        SELECT @c_errmsg='NSQL'+CONVERT(char(5),@n_err)+': Bad Sku (nspg_GETSKU1)'    
     END    
  END    
  ELSE -- SOS154134 Start   
  BEGIN    
      SELECT @c_sku = Sku, @c_packkey = SKU.PackKey, @c_uom = PACK.PackUOM3    
      FROM SKU WITH (NOLOCK)  
      JOIN PACK WITH (NOLOCK) ON (SKU.PackKey = PACK.PackKey)  
      WHERE Sku = @c_sku and StorerKey = @c_StorerKey    
  END  -- SOS154134 End   
    
  IF @n_continue = 3    
  BEGIN    
     SELECT @b_success = 0    
  END    
END    


GO