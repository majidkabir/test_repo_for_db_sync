SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

   
  
  
  
/************************************************************************/  
/* Stored Proc : isp_CartonTrack_PoolMove                               */  
/* Creation Date: 29 June 2015                                          */  
/* Copyright: IDS                                                       */  
/* Written by: TLTING                                                   */  
/*                                                                      */  
/* Purpose: to insert TrackingNo from CartonTrack_Pool                  */  
/*                                                                      */  
/* Input Parameters: NONE                                               */  
/*                                                                      */  
/* Output Parameters: NONE                                              */  
/*                                                                      */  
/* Return Status: NONE                                                  */  
/*                                                                      */  
/* Usage:                                                               */  
/*                                                                      */  
/* Local Variables:                                                     */  
/*                                                                      */  
/* Called By:   Backend Job                                             */  
/*                                                                      */  
/* PVCS Version: 1.0                                                    */  
/*                                                                      */  
/* Version: 5.4                                                         */  
/*                                                                      */  
/* Data Modifications:                                                  */  
/*                                                                      */  
/* Updates:                                                             */  
/* Date         Author        Purposes                                  */  
/* 21Aug2015    TLTING        sort by RowRef                            */
/* 11Nov2015    TLTING        possible duplicate  trackingno            */
/************************************************************************/  
CREATE PROCEDURE [dbo].[isp_CartonTrack_PoolMove]   ( @n_debug INT = 0 )    
AS  
BEGIN   
   SET NOCOUNT ON      
   SET QUOTED_IDENTIFIER OFF      
   SET ANSI_NULLS OFF      
   SET CONCAT_NULL_YIELDS_NULL OFF      
  
   -- Update Loadkey in Orders Table   
  
   declare @c_CarrierName Nvarchar(30), @c_KeyName Nvarchar(30), @c_MinQty Nvarchar(10), @c_InsertQty Nvarchar(10)  
   DECLARE @n_MinQty INT, @n_InsertQty INT  , @n_err INT, @n_cnt int  
   DECLARE @c_SQL NVARCHAR(2000) 
  
  
   IF OBJECT_ID('tempdb..#TrackingNo') IS NOT NULL  
      DROP TABLE #TrackingNo  
  
  
  
   CREATE TABLE #TrackingNo  
   (  TrackingNo NVARCHAR(20) )  
   
   Create index IDX_TrackingNo_01 on #TrackingNo  (TrackingNo) 
  
   IF EXISTS (   
   SELECT 1 FROM codelkup (NOLOCK)  
   WHERE LISTNAME = 'CartnTrack'      )  
   Begin   
    DECLARE Item_Cur CURSOR LOCAL FAST_FORWARD READ_ONLY FOR   
         SELECT Code, Code2, Short, Long   
         FROM codelkup (NOLOCK)  
         WHERE LISTNAME = 'CartnTrack'    
  
    OPEN Item_Cur   
    FETCH NEXT FROM Item_Cur INTO @c_CarrierName, @c_KeyName, @c_MinQty, @c_InsertQty    
    WHILE @@FETCH_STATUS = 0   
    BEGIN   
       IF @n_debug = '1'   
       BEGIN  
          PRINT '@c_CarrierName- ' + @c_CarrierName + ' @c_KeyName-' + @c_KeyName + ' @c_MinQty-' + @c_MinQty +   
                ' @c_InsertQty- ' + @c_InsertQty  
       END   
          
       SET  @n_MinQty = ISNULL(CAST (@c_MinQty AS INT) , 0)   
       SET  @n_InsertQty = ISNULL(CAST (@c_InsertQty AS INT) , 0)    
             
         IF @n_InsertQty > 0        -- having qty to move  
            AND EXISTS ( SELECT 1 FROM dbo.CartonTrack_Pool (NOLOCK) -- having pool to insert  
                           WHERE CarrierName = @c_CarrierName  
                              AND KeyName = @c_KeyName )  
            AND @n_MinQty > ISNULL(( SELECT COUNT(1) FROM dbo.CartonTrack (NOLOCK)  
                           WHERE CarrierName = @c_CarrierName  
                              AND KeyName = @c_KeyName   
                              AND LabelNo='' and CarrierRef2='' ), 0)          -- rearch reinsert level  
         BEGIN  
          IF @n_debug = '1'   
          BEGIN  
             PRINT 'START '    
          END        
            SET @c_SQL = 'INSERT INTO #TrackingNo ' + CHAR(13) +  
                        ' SELECT top ' + @c_InsertQty + ' TrackingNo ' + CHAR(13) +  
                        '  FROM dbo.CartonTrack_Pool with (NOLOCK) ' + CHAR(13) +  
                        ' WHERE CarrierName = ''' + @c_CarrierName + ''' ' + CHAR(13) +  
                        '       AND KeyName = ''' + @c_KeyName  + ''' ' + CHAR(13) +  
                        ' ORDER BY  RowRef '  + CHAR(13)  
  
            EXEC (@c_SQL)    
            SELECT @n_err = @@ERROR  , @n_cnt = @@ROWCOUNT  
            IF @n_err <> 0    
            BEGIN    
               PRINT 'Error !'  
               Break  
            END     
              
            IF @n_cnt > 0  
            BEGIN   
               INSERT INTO dbo.CartonTrack  
                  ( TrackingNo,CarrierName,KeyName,LabelNo,CarrierRef1,CarrierRef2,AddWho,AddDate )  
               SELECT   TrackingNo,CarrierName,KeyName,LabelNo,CarrierRef1,CarrierRef2,AddWho,AddDate  
               FROM  dbo.CartonTrack_Pool with (NOLOCK)     
               WHERE CarrierName =   @c_CarrierName  
               AND KeyName =   @c_KeyName  
               AND EXISTS ( SELECT 1 FROM  #TrackingNo   
                           WHERE #TrackingNo.TrackingNo = CartonTrack_Pool.TrackingNo  )  
               AND NOT EXISTS ( SELECT 1 FROM  CartonTrack WITH (NOLOCK)  
                           WHERE CartonTrack.TrackingNo = CartonTrack_Pool.TrackingNo  
                           AND CarrierName =   @c_CarrierName  
                           AND KeyName =   @c_KeyName  )      
                             
                             
               DELETE FROM dbo.CartonTrack_Pool     
               WHERE CarrierName =   @c_CarrierName  
               AND KeyName =   @c_KeyName       
               AND EXISTS ( SELECT 1 FROM  #TrackingNo   
                           WHERE #TrackingNo.TrackingNo = CartonTrack_Pool.TrackingNo  )  
                                                        
            END   
                
         END                    
       
     FETCH NEXT FROM Item_Cur INTO @c_CarrierName, @c_KeyName, @c_MinQty, @c_InsertQty    
    END  
    CLOSE Item_Cur   
    DEALLOCATE Item_Cur  
   End  
   Else  
   Begin  
    print 'NO cartontrack setup : No Problem'  
   End  
  
 END  
 

GO