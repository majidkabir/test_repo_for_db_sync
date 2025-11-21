SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
/************************************************************************/    
/* Stored Proc : isp_CartonTrack2Pool                                   */    
/* Creation Date: 29 Jan 2016                                           */    
/* Copyright: IDS                                                       */    
/* Written by: TLTING                                                   */    
/*                                                                      */    
/* Purpose: to Move TrackingNo to CartonTrack_Pool                      */    
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
/* 05-Nov-2020  TLTING01  1.1 Extend trackingno field length            */       
/************************************************************************/    
CREATE PROCEDURE [dbo].[isp_CartonTrack2Pool]
@n_CheckLevel int = 10000,
@n_MaxLevel INT = 2000
AS    
BEGIN     
   SET NOCOUNT ON        
   SET QUOTED_IDENTIFIER OFF        
   SET ANSI_NULLS OFF        
   SET CONCAT_NULL_YIELDS_NULL OFF        
    
   -- Update Loadkey in Orders Table     

   DECLARE @c_ExecStatements           NVARCHAR(4000) 
         , @c_ExecArguments            NVARCHAR(4000)
         , @n_MaxRowref            Bigint
             
   declare @c_CarrierName Nvarchar(30), @c_KeyName Nvarchar(30) 
   DECLARE   @n_err INT, @n_cnt int    
   DECLARE   @n_debug int    
    
    SET @n_debug = 0
    
    IF @n_CheckLevel is NULL or @n_CheckLevel <= 0
      Set @n_CheckLevel  = 10000

    IF @n_MaxLevel is NULL or @n_MaxLevel <= 0
      Set @n_MaxLevel  = 2000
          
   IF OBJECT_ID('tempdb..#TrackingNo') IS NOT NULL    
      DROP TABLE #TrackingNo    
    
    
    
   CREATE TABLE #TrackingNo    
   (  TrackingNo NVARCHAR(40) PRIMARY key)    
    
   IF EXISTS (     
            SELECT 1 FROM dbo.CartonTrack (NOLOCK)
               WHERE   LabelNo = ''
               GROUP BY CarrierName, KeyName
               Having COUNT(1) >   @n_CheckLevel   )    
   Begin     
    DECLARE Item_Cur CURSOR LOCAL FAST_FORWARD  FOR     
      SELECT CarrierName, KeyName FROM dbo.CartonTrack (NOLOCK)
         WHERE   LabelNo = ''  
         GROUP BY CarrierName, KeyName
         Having COUNT(1) >   @n_CheckLevel 
    
    OPEN Item_Cur     
    FETCH NEXT FROM Item_Cur INTO @c_CarrierName, @c_KeyName      
    WHILE @@FETCH_STATUS = 0     
    BEGIN     
       IF @n_debug = '1'     
       BEGIN    
          PRINT '@c_CarrierName- ' + @c_CarrierName + ' @c_KeyName-' + @c_KeyName  
       END     
       


      SET @c_ExecStatements = ''
      SET @c_ExecArguments  = ''
      SET @n_MaxRowref = 0
      SET @c_ExecStatements = N' SELECT top ' + CAST(@n_MaxLevel AS VARCHAR) + ' @n_MaxRowref  = RowRef ' + CHAR(13) +    
                              '  FROM dbo.CartonTrack with (NOLOCK) ' + CHAR(13) +  
                              ' WHERE CarrierName = ''' + @c_CarrierName + ''' ' + CHAR(13) +    
                              '       AND KeyName = ''' + @c_KeyName  + ''' ' + CHAR(13) +    
                              '       AND LabelNo = '''' ' + CHAR(13) +                         
                              ' ORDER BY  RowRef '  + CHAR(13)    

       IF @n_debug = '1'     
       BEGIN    
          PRINT @c_ExecStatements 
       END   
                      
      SET @c_ExecArguments = N'@n_MaxRowref  BigINT Output'  
 
      EXEC sp_ExecuteSql @c_ExecStatements
                       , @c_ExecArguments
                       , @n_MaxRowref OUTPUT
   
      SELECT @n_err = @@ERROR     
      IF @n_err <> 0      
      BEGIN      
         PRINT 'Error !'    
         Break    
      END      

       IF @n_debug = '1'     
       BEGIN    
          PRINT 'CuroffRowref ' + CAST( @n_MaxRowref AS NVARCHAR)
       END   
             
      INSERT INTO #TrackingNo ( TrackingNo  )
      SELECT   DISTINCT TrackingNo
               FROM  dbo.CartonTrack with (NOLOCK)       
               WHERE CarrierName =   @c_CarrierName    
               AND KeyName =   @c_KeyName    AND LabelNo = ''
               AND rowref > @n_MaxRowref
      Select @n_cnt = @@ROWCOUNT
             
      IF @n_cnt > 0     AND @n_MaxRowref > 0
      BEGIN     
         INSERT INTO dbo.CartonTrack_Pool    
            ( TrackingNo,CarrierName,KeyName,LabelNo,CarrierRef1,CarrierRef2,AddWho,AddDate )    
         SELECT   TrackingNo,CarrierName,KeyName,LabelNo,CarrierRef1,CarrierRef2,AddWho,AddDate    
         FROM  dbo.CartonTrack with (NOLOCK)       
         WHERE CarrierName =   @c_CarrierName    
         AND KeyName =   @c_KeyName   
         AND LabelNo = '' 
         AND EXISTS ( SELECT 1 FROM  #TrackingNo     
                     WHERE #TrackingNo.TrackingNo = CartonTrack.TrackingNo  )    
         AND NOT EXISTS ( SELECT 1 FROM  CartonTrack_Pool WITH (NOLOCK)    
                     WHERE CartonTrack.TrackingNo = CartonTrack_Pool.TrackingNo    
                     AND CartonTrack_Pool.CarrierName =   @c_CarrierName    
                     AND CartonTrack_Pool.KeyName =   @c_KeyName  )        
                         
          IF @n_debug = '1'     
          BEGIN    
             SELECT TOP 1 * FROM #TrackingNo ORDER BY TrackingNo
          END  
                                   
         DELETE FROM dbo.CartonTrack       
         WHERE CarrierName =   @c_CarrierName    
         AND KeyName =   @c_KeyName  
         AND LabelNo = ''       
         AND EXISTS ( SELECT 1 FROM  #TrackingNo     
                     WHERE #TrackingNo.TrackingNo = CartonTrack.TrackingNo  )    
                                                    
      END     
                                 
      Delete from #TrackingNo
         
      FETCH NEXT FROM Item_Cur INTO @c_CarrierName, @c_KeyName 
    END    
    CLOSE Item_Cur     
    DEALLOCATE Item_Cur    
   End    
   Else    
   Begin    
    print 'NO cartontrack record need move ! '    
   End    
    
 END   

GO