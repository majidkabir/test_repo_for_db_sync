SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/************************************************************************/        
/* Store procedure: isp_PurgeNonActivePAPendingMoveIn                   */        
/* Copyright      : LF Logistics                                        */        
/*                                                                      */        
/* Purpose: Clean Pending Move In, Run By Schedule job                  */        
/*                                                                      */        
/*                                                                      */        
/*                                                                      */        
/* Modifications log:                                                   */        
/*                                                                      */        
/* Date       Rev  Author   Purposes                                    */        
/* 2013-07-25 1.0  Shong    Created                                     */      
/************************************************************************/      
CREATE PROC [dbo].[isp_PurgeNonActivePAPendingMoveIn]  
AS  
BEGIN  
     
   DECLARE  
   @n_RFQty             INT ,               
   @c_RFLoc             NVARCHAR(10),           
   @c_RFLot             NVARCHAR(10),           
   @dt_RFAddDate        DATETIME,         
   @c_RFID              NVARCHAR(18),           
   @c_RFStorerkey       NVARCHAR(10),           
   @dt_PurgeDate        DATETIME,  
   @n_TranCount         INT,   
   @c_UserName          NVARCHAR(18)          
  
  
   SET @n_RFQty = 0        
   SET @n_TranCount = @@TRANCOUNT  
        
   SET @c_RFLoc = ''        
   SET @c_RFLot = ''        
   SET @dt_RFAddDate = ''        
   SET @c_RFID = ''        
   SET @c_RFStorerkey = ''        
   SET @dt_PurgeDate = DATEADD(minute, -60, GETDATE())               
  
   WHILE @@TRANCOUNT > 0   
      COMMIT TRAN   
                       
   DECLARE CUR_NonActivePutaway CURSOR LOCAL FAST_FORWARD READ_ONLY FOR                           
   SELECT   RFP.Qty        
          , RFP.SuggestedLoc        
          , RFP.Lot        
          , RFP.AddDate        
          , RFP.ID        
          , RFP.Storerkey   
          , RFP.ptcid       
   FROM dbo.RFPutaway RFP WITH (NOLOCK)        
   LEFT OUTER JOIN rdt.RDTMOBREC r WITH (NOLOCK) ON r.UserName = RFP.ptcid   
   WHERE RFP.AddDate < @dt_PurgeDate   
   OR    r.Mobile IS NULL         
   ORDER BY RFP.ptcid   
            
   OPEN CUR_NonActivePutaway            
   FETCH NEXT FROM CUR_NonActivePutaway INTO @n_RFQty, @c_RFLoc, @c_RFLot, @dt_RFAddDate, @c_RFID, @c_RFStorerkey, @c_UserName        
   WHILE @@FETCH_STATUS <> -1            
   BEGIN  
      BEGIN TRAN                  
      IF EXISTS (SELECT 1 FROM LotxLocxID WITH (NOLOCK)         
                 WHERE Lot = @c_RFLot        
                 AND   Loc = @c_RFLoc              
                 AND   ID  = @c_RFID)  
      BEGIN        
         UPDATE dbo.LotxLocxID WITH (ROWLOCK)        
               SET PendingMoveIn = CASE WHEN PendingMoveIn - @n_RFQty > 0 THEN PendingMoveIn - @n_RFQty        
                                   ELSE 0        
                                   END        
         WHERE Lot = @c_RFLot        
               AND Loc = @c_RFLoc        
               AND ID  = @c_RFID        
              
         IF @@Error <> 0        
         BEGIN        
            ROLLBACK TRAN  
            GOTO Quit        
         END        
      END  
        
      DELETE dbo.RFPUTAWAY WITH (ROWLOCK)        
      WHERE Storerkey = @c_RFStorerkey     
      AND Lot = @c_RFLot        
      AND SuggestedLoc = @c_RFLoc              
      AND ID  = @c_RFID     
      AND ptcID = @c_UserName   
      AND AddDate = @dt_RFAddDate              
      IF @@Error <> 0        
      BEGIN        
         ROLLBACK TRAN  
         GOTO Quit        
      END        
      ELSE  
      BEGIN  
         WHILE @@TRANCOUNT > 0         
            COMMIT TRAN    
      END           
      FETCH NEXT FROM CUR_NonActivePutaway INTO @n_RFQty, @c_RFLoc, @c_RFLot, @dt_RFAddDate, @c_RFID, @c_RFStorerkey, @c_UserName        
   END        
   CLOSE CUR_NonActivePutaway            
   DEALLOCATE CUR_NonActivePutaway         
              
   WHILE @@TRANCOUNT < @n_TranCount   
      BEGIN TRAN      
Quit:  
  
  
END  

GO