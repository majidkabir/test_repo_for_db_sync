SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
  
/************************************************************************/    
/* Trigger:  ntrEC_InventoryHoldUpdate                                  */    
/* Creation Date:                                                       */    
/* Copyright: IDS                                                       */    
/* Written by:                                                          */    
/*                                                                      */    
/* Purpose:                                                             */    
/*                                                                      */    
/* Input Parameters:                                                    */    
/*                                                                      */    
/* Output Parameters:  None                                             */    
/*                                                                      */    
/* Return Status:  None                                                 */    
/*                                                                      */    
/* Usage:                                                               */    
/*                                                                      */    
/* Local Variables:                                                     */    
/*                                                                      */    
/* Called By: When records updated                                      */    
/*                                                                      */    
/* PVCS Version: 1.0                                                    */    
/*                                                                      */    
/* Version: 5.4                                                         */    
/*                                                                      */    
/* Data Modifications:                                                  */    
/*                                                                      */    
/* Updates:                                                             */    
/* Date         Author    Ver.  Purposes                                */    
/* 2011-06-06   KHLim     1.0   SET WhoOff = WhoOn                      */    
/* 2011-06-24   KHLim01   1.0   add UPDATE(TrafficCop) to allow bypass  */    
/************************************************************************/    
CREATE TRIGGER [ntrEC_InventoryHoldUpdate]  
ON [dbo].[EC_InventoryHold]  
FOR  UPDATE  
AS  
 IF @@ROWCOUNT=0  
 BEGIN  
     RETURN  
 END  
   
 SET NOCOUNT ON     
 SET ANSI_NULLS OFF    
 SET QUOTED_IDENTIFIER OFF     
 SET CONCAT_NULL_YIELDS_NULL OFF     
   
 DECLARE @n_PrimaryKey INT  
        ,@c_lot NVARCHAR(10)  
        ,@c_Loc NVARCHAR(10)  
        ,@c_ID NVARCHAR(18)  
        ,@c_StorerKey NVARCHAR(15)  
        ,@c_SKU NVARCHAR(20)  
        ,@c_lottable01 NVARCHAR(18)  
        ,@c_lottable02 NVARCHAR(18)  
        ,@c_lottable03 NVARCHAR(18)  
        ,@d_lottable04 DATETIME  
        ,@d_lottable05 DATETIME  
        ,@c_Status NVARCHAR(10)  
        ,@c_Hold NVARCHAR(1)  
        ,@b_success INT  
        ,@n_err INT  
        ,@c_errmsg NVARCHAR(250)  
        ,@c_remark NVARCHAR(260)  
        ,@n_starttcnt INT     
   
 SELECT @n_starttcnt = @@TRANCOUNT   
   
 BEGIN TRAN    
  
   SET @n_PrimaryKey = ''  
      
 IF UPDATE (Hold)  
 BEGIN  
  BEGIN TRAN    
    
  WHILE (1=1)  
  BEGIN  
      SELECT TOP 1   
            @n_PrimaryKey = [InventoryHoldKey]  
           ,@c_StorerKey = [Storerkey]  
           ,@c_SKU = [SKU]  
           ,@c_lottable01 = ISNULL([Lottable01] ,'')  
           ,@c_lottable02 = ISNULL([Lottable02] ,'')  
           ,@c_lottable03 = ISNULL([Lottable03] ,'')  
           ,@d_lottable04 = [Lottable04]  
           ,@d_lottable05 = [Lottable05]  
           ,@c_Status = [ReasonCode]  
           ,@c_Hold = CAST([Hold] AS CHAR(1))  
           ,@c_remark = [Remark]  
      FROM   INSERTED  
      WHERE  INSERTED.InventoryHoldKey>@n_PrimaryKey  
      ORDER BY  
             INSERTED.InventoryHoldKey  
        
      IF @@ROWCOUNT=0  
      BEGIN  
          BREAK  
      END    
        
          SET @b_success = 1  
  
      EXEC nspInventoryHoldWrapper   
           '' -- @c_lot  
          ,'' -- @c_Loc  
          ,'' -- @c_ID  
          ,@c_StorerKey  
          ,@c_SKU  
          ,@c_lottable01  
          ,@c_lottable02  
          ,@c_lottable03  
          ,@d_lottable04  
          ,@d_lottable05  
          ,@c_Status  
          ,@c_Hold  
          ,@b_success OUTPUT  
          ,@n_err OUTPUT  
          ,@c_errmsg OUTPUT  
          ,@c_remark       
        
      IF @b_success<>1  
      BEGIN  
          SELECT @n_err = 74000    
          SELECT @c_errmsg = 'ntrEC_InventoryHoldUpdate: '+ISNULL(RTRIM(@c_errmsg) ,'')   
          ROLLBACK TRAN   
              EXECUTE nsp_LogError @n_err, @c_errmsg, 'ntrEC_InventoryHoldUpdate'        
              RAISERROR (@c_ErrMsg, 16, 1) WITH SETERROR      
              RETURN    
      END  
  END    
    
  WHILE @@TRANCOUNT>@n_starttcnt  
  BEGIN  
      COMMIT TRAN  
  END   
    
  RETURN  
 END    
    

GO