SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/************************************************************************/  
/* SP: isp_InsertPickDet_Log                                            */  
/* Creation Date: 28th Oct 2009                                         */  
/* Copyright: IDS                                                       */  
/* Written by: Shong                                                    */  
/*                                                                      */  
/* Called By: ntrPikingInfoAdd                                          */  
/*                                                                      */  
/*                                                                      */  
/* Updates:                                                             */  
/* Date         Author    Ver.  Purposes                                */  
/* 28-Oct-2009  Shong     1.0   Insert into PickDet_Log                 */  
/* 22-Jun-2010  Shong     1.1   Get PackKey from SKU                    */ 
/* 28-Mar-2011  Shong     1.2   Delete Previous Orders PickDet_Log      */
/************************************************************************/  
CREATE PROC [dbo].[isp_InsertPickDet_Log]    
   @cOrderKey NVARCHAR(10),  
   @cOrderLineNumber NVARCHAR(5)='',   
   @n_err INT OUTPUT,  
   @c_errmsg NVARCHAR(215) OUTPUT, 
   @cPickSlipNo   NVARCHAR(10)=''   
AS  
BEGIN
    DECLARE @cPickDetailKey  NVARCHAR(18)
           ,@nStartTran      INT
           ,@n_Continue      INT  
    
    SET @nStartTran = @@TRANCOUNT  
    SET @n_Continue = 1 
    
    BEGIN TRAN  
    
    IF EXISTS(
           SELECT 1
           FROM   StorerConfig sc WITH (NOLOCK)
                  JOIN ORDERS o WITH (NOLOCK)
                       ON  sc.StorerKey = o.StorerKey
           WHERE  o.OrderKey = @cOrderKey AND
                  sc.ConfigKey = 'ScanInPickLog' AND
                  sc.SValue = '1'
       )
    BEGIN
        IF ISNULL(RTRIM(@cOrderLineNumber) ,'')<>''
        BEGIN
           -- Shong 28th Mar 2011
           IF EXISTS(SELECT 1 FROM PICKDET_LOG pl (NOLOCK) 
                     WHERE pl.OrderKey = @cOrderKey AND
                           pl.OrderLineNumber = @cOrderLineNumber)
           BEGIN
              DELETE FROM PICKDET_LOG
              WHERE OrderKey = @cOrderKey AND
                    OrderLineNumber = @cOrderLineNumber
              IF @@ERROR<>0  
              BEGIN  
                 SET @c_errmsg = 'Delete PICKDET_LOG Failed'
                 SET @n_continue = 3  
              END                                    
           END

           DECLARE cur_PickDetailKey CURSOR LOCAL FAST_FORWARD READ_ONLY 
           FOR
               SELECT PickDetailKey
               FROM   PICKDETAIL p WITH (NOLOCK)
               WHERE  p.OrderKey = @cOrderKey AND
                      p.OrderLineNumber = @cOrderLineNumber
           
                                
        END
        ELSE
        BEGIN
          IF EXISTS(SELECT 1 FROM PICKDET_LOG pl (NOLOCK) 
                    WHERE pl.OrderKey = @cOrderKey)
          BEGIN
             DELETE FROM PICKDET_LOG
             WHERE OrderKey = @cOrderKey            
             IF @@ERROR<>0  
             BEGIN  
                SET @c_errmsg = 'Delete PICKDET_LOG Failed'
                SET @n_continue = 3  
             END                 
          END      
                     
          DECLARE cur_PickDetailKey CURSOR LOCAL FAST_FORWARD READ_ONLY 
          FOR
             SELECT PickDetailKey
             FROM   PICKDETAIL p WITH (NOLOCK)
             WHERE  p.OrderKey = @cOrderKey
        END 
        
        OPEN cur_PickDetailKey 
        
        FETCH NEXT FROM cur_PickDetailKey INTO @cPickDetailKey  
        WHILE @@FETCH_STATUS<>-1
        BEGIN
            IF NOT EXISTS(
                   SELECT 1
                   FROM   PICKDET_LOG p WITH (NOLOCK)
                   WHERE  p.PickDetailKey = @cPickDetailKey
               )
            BEGIN
                INSERT INTO PICKDET_LOG
                  (
                    PickDetailKey, OrderKey, OrderLineNumber, Storerkey, Sku, 
                    Lot, Loc, ID, UOM, Qty, [Status], DropID, PackKey, WaveKey, 
                    AddDate, AddWho, LogDate, LogWho, PickSlipNo
                  )
                SELECT P.PickDetailKey
                      ,P.OrderKey
                      ,P.OrderLineNumber
                      ,P.Storerkey
                      ,P.Sku
                      ,P.Lot
                      ,P.Loc
                      ,P.ID
                      ,P.UOM
                      ,P.Qty
                      ,P.[Status]
                      ,P.DropID
                      ,P.PackKey
                      ,P.WaveKey
                      ,P.AddDate
                      ,P.AddWho
                      ,GETDATE() -- LogDate
                      ,SUSER_SNAME() -- LogWho
                      ,ISNULL(p.PickSlipNo ,@cPickSlipNo)
                FROM   PICKDETAIL p WITH (NOLOCK) 
                JOIN   SKU S WITH (NOLOCK) ON S.StorerKey = P.StorerKey and S.SKU = P.SKU  
                WHERE  P.PickDetailKey = @cPickDetailKey  
                
                IF @@ERROR<>0
                BEGIN
                    SELECT @n_continue = 3
                END
            END
            
            FETCH NEXT FROM cur_PickDetailKey INTO @cPickDetailKey
        END 
        CLOSE cur_PickDetailKey 
        DEALLOCATE cur_PickDetailKey
    END  
    
    IF @n_continue=3 -- Error Occured - Process And Return
    BEGIN
        IF @@TRANCOUNT=1 AND
           @@TRANCOUNT>=@nStartTran
        BEGIN
            ROLLBACK TRAN
        END
        ELSE
        BEGIN
            WHILE @@TRANCOUNT>@nStartTran
            BEGIN
                COMMIT TRAN
            END
        END 
        EXECUTE nsp_logerror @n_err, @c_errmsg, 'isp_InsertPickDet_Log' 
        RAISERROR (@c_errmsg, 16, 1) WITH SETERROR    -- SQL2012 
        RETURN
    END
    ELSE
    BEGIN
        WHILE @@TRANCOUNT>@nStartTran
        BEGIN
            COMMIT TRAN
        END 
        RETURN
    END
END -- Procedure  

GO