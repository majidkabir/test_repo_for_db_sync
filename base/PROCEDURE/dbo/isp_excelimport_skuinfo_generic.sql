SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/*****************************************************************************************/                    
/* Stored Procedure:   isp_ExcelImport_SkuInfo_Generic                                   */                    
/* Creation Date:                                                                        */                    
/* Copyright: IDS                                                                        */                    
/* Written by: kelvinongcy                                                               */                    
/*                                                                                       */                    
/* Purpose:  New Data import into WMS SkuInfo via Web Excel Loader Management            */                    
/*                                                                                       */                    
/* Updates:      Author ver   Purpose                                                    */                  
/* 18-Nov-2019   kocy   1.0   https://jiralfl.atlassian.net/browse/WMS-10941             */                  
/*                            New Data import into SkuInfo for Storerkey -'PVHQHW'       */                   
/*                            via Web Excel Loader Management                            */                   
/* 05-08-2020    kocy   1.1   New requirement Sku. Style(a) + '_'Sku.Busr1(b)            */                  
/*                            = Newtable.Style_Busr1(a_b)]                               */                  
/*                            when busr1 is empty, the style is a when style is empty,   */                  
/*                            then Busr1 is _b.                                          */                  
/* 19-01-2021    kocy    1.2  https://jiralfl.atlassian.net/browse/WMS-16078             */                  
/*                            New Data import into SkuInfo for Storerkey -'PVHSZ'        */                  
/*                            via Web Excel Loader Management                            */             
/* 03-05-2021    kocy    1.3  revised script try prevent mutliple sku info inserted      */             
/*                             based style_busr1                                         */          
/* 21-05-2021    kocy    1.4  revised script prevent bulk delete, insert, update         */          
/*****************************************************************************************/                  
CREATE   PROCEDURE [dbo].[isp_ExcelImport_SkuInfo_Generic]                  
(                  
   @c_StorerKey nvarchar(15)                  
  ,@b_debug  bit = 0                  
)                  
AS                  
BEGIN                      
   SET NOCOUNT ON                         
   SET ANSI_NULLS OFF                    
   SET QUOTED_IDENTIFIER OFF                         
   SET CONCAT_NULL_YIELDS_NULL OFF                        
                          
   DECLARE @d_EffectiveDate      nvarchar(15)                  
         , @c_Status             nvarchar(5)                  
         , @c_Style_Busr1        nvarchar(20)                
         , @c_SKU                nvarchar(20)              
         , @n_starttcnt          INT                  
         , @n_continue           INT                  
         , @b_success            INT                  
         , @n_err                INT                  
         , @c_errmsg             NVARCHAR(255)                  
         , @c_Delete             NVARCHAR(5)                
         , @c_Exist              NVARCHAR(5)          
         , @n_UniqueKey          BIGINT          
         , @n_UniqueKeyGroup     BIGINT          
         , @c_StorerKeyGroup     nvarchar(15)          
         , @c_Style_Busr1Group   nvarchar (20)          
         , @c_StatusGroup        nvarchar(5)           
                   
                  
   SELECT  @n_starttcnt=@@TRANCOUNT,@n_continue=1 , @b_success=0, @n_err=0, @c_errmsg=''            
   SELECT  @c_Status = '0', @c_Delete = 'Y'                  
           
           
  IF ISNULL(OBJECT_ID('tempdb..#temp_insert'), '') <> ''                                  
   BEGIN                                  
      DROP TABLE #temp_insert                               
   END             
             
   CREATE TABLE #temp_insert (          
      RowRef  INT IDENTITY (1,1) NOT NULL,          
      UniqueKey  BIGINT NOT NULL,          
      Style_Busr1  NVARCHAR(20),             
      Sku        nvarchar(20)     )          
          
  IF ISNULL(OBJECT_ID('tempdb..#temp_STG'), '') <> ''                                  
   BEGIN                                  
      DROP TABLE #temp_STG                                
   END              
            
  CREATE TABLE #temp_STG (          
   RowRef  INT IDENTITY (1,1) NOT NULL,          
   UniqueKey   BIGINT NOT NULL,          
   StorerKey   NVARCHAR(15),             
   Style_Busr1 NVARCHAR(20),             
   Sku         nvarchar(20),             
   [Status]    nvarchar(5)             
  )            
          
  IF ISNULL(OBJECT_ID('tempdb..#temp_update'), '') <> ''                                  
   BEGIN                                  
      DROP TABLE #temp_update                               
   END             
             
   CREATE TABLE #temp_update (          
      RowRef  INT IDENTITY (1,1) NOT NULL,          
      UniqueKey  BIGINT NOT NULL,          
      StorerKey   NVARCHAR(15),             
      Style_Busr1 NVARCHAR(20),          
      [Status]    nvarchar(5)          
   )          
          
             
  IF @n_continue=1          
  BEGIN          
      -- if exist record's EffectiveDate match to today then delete the old batch records                 
      IF EXISTS ( SELECT 1 FROM [DTS].[ExcelImport_DTS_WMS_SKUINFO] WITH (NOLOCK)               
                  WHERE StorerKey = @c_StorerKey              
                  AND EffectiveDate = FORMAT(GETDATE(), 'yyyy-MM-dd') )              
      BEGIN           
         WHILE (1=1)          
         BEGIN          
            DELETE TOP (10000) si FROM [dbo].[SKUINFO] si           
            WHERE si.StorerKey = @c_StorerKey            
                   
            IF @@ROWCOUNT = 0            
            BREAK;          
         END          
      END            
  END          
            
  IF @n_continue=1          
  BEGIN          
      
      INSERT INTO #temp_insert ( UniqueKey, Style_Busr1, Sku)          
      SELECT stg.RowRef, stg.Style_Busr1 , sku.SKU               
      FROM  [DTS].[ExcelImport_DTS_WMS_SKUINFO] stg  WITH (NOLOCK)    -- synonyms table                      
      JOIN dbo.SKU sku WITH (NOLOCK) ON sku.StorerKey = stg.StorerKey  AND ( ISNULL(Style, '') + ISNULL(Busr1, '') )  = REPLACE(stg.Style_Busr1, '_', '')            
      --( ( ISNULL(LTRIM(RTRIM(Style)), '') + CASE WHEN ISNULL(LTRIM(RTRIM(Busr1)), '')  <> '' THEN '_' + LTRIM(RTRIM(Busr1)) ELSE '' END ) = stg.Style_Busr1 )             
      WHERE stg.StorerKey = @c_StorerKey    --'PVHQHW' 'PVHSZ'               
      AND stg.Flag = 'Y'                  
      AND stg.[Status] = '0'                
      AND stg.EffectiveDate = FORMAT(GETDATE(), 'yyyy-MM-dd')          
      --AND stg.Style_Busr1 in ('DP0622L9100', 'B4R0867FT' , 'D3447', 'D3447D')     
            
          
      DECLARE CUR_RETRIEVED_Style_Busr1 CURSOR LOCAL FAST_FORWARD READ_ONLY FOR          
      SELECT UniqueKey, Style_Busr1, Sku          
      FROM #temp_insert          
                
      OPEN CUR_RETRIEVED_Style_Busr1                  
      FETCH NEXT FROM CUR_RETRIEVED_Style_Busr1 INTO @n_UniqueKey, @c_Style_Busr1 , @c_SKu           
      WHILE @@FETCH_STATUS = 0                  
      BEGIN          
         BEGIN TRAN             
                   
         SET @c_Status = '9'                       
                   
         INSERT INTO [dbo].[SKUINFO] (StorerKey, SKU)                   
         SELECT StorerKey, SKU                  
         FROM  [dbo].[SKU] WITH (NOLOCK)                   
         WHERE StorerKey = @c_StorerKey              
         AND SKu = @c_Sku          
                   
         INSERT INTO #temp_STG (UniqueKey, StorerKey, Style_Busr1, Sku, Status)          
         SELECT @n_UniqueKey, @c_StorerKey, @c_Style_Busr1, @c_Sku, @c_Status          
          
         IF @@ERROR <> 0                                               
         BEGIN           
            SELECT @n_continue = 3          
            SELECT @n_err = @@ERROR          
            SELECT @c_errmsg = N'Failed to insert #temp_STG. (Style_Burs1 = ' + @c_Style_Busr1 + ', Sku = ' + @c_Sku + ')'   --ERROR_MESSAGE()          
            ROLLBACK TRAN                                                                                         
         END               
              
         WHILE @@TRANCOUNT > 0                  
         COMMIT TRAN           
                       
         FETCH NEXT FROM CUR_RETRIEVED_Style_Busr1 INTO @n_UniqueKey, @c_Style_Busr1 , @c_SKu              
      END                  
      CLOSE CUR_RETRIEVED_Style_Busr1                  
      DEALLOCATE CUR_RETRIEVED_Style_Busr1                
          
  END          
          
  IF @n_continue =1          
  BEGIN           
          
      INSERT INTO #temp_update (UniqueKey, StorerKey, Style_Busr1, [Status])          
      SELECT UniqueKey, StorerKey, Style_Busr1, [Status]          
      FROM #temp_STG          
      GROUP BY UniqueKey, StorerKey, Style_Busr1, [Status]          
            
      DECLARE CUR_Upd CURSOR LOCAL FAST_FORWARD READ_ONLY FOR           
      SELECT tgt.RowRef, tgt.Style_Busr1, tgt.StorerKey, stg.[Status]           
      FROM [DTS].[ExcelImport_DTS_WMS_SKUINFO] tgt          
      LEFT JOIN #temp_update stg  WITH (NOLOCK) ON stg.UniqueKey = tgt.RowRef and stg.Style_Busr1 = tgt.Style_Busr1  and stg.StorerKey = tgt.Storerkey            
      WHERE tgt.Flag = 'Y'       
      AND tgt.EffectiveDate = FORMAT(GETDATE(), 'yyyy-MM-dd')    
      order by tgt.RowRef         
          
       If (@b_debug) = 1          
       BEGIN                    
           SELECT tgt.RowRef, stg.UniqueKey, tgt.Style_Busr1, tgt.StorerKey, stg.[Status]          
           FROM [DTS].[ExcelImport_DTS_WMS_SKUINFO] tgt          
           LEFT JOIN #temp_update stg  WITH (NOLOCK) ON stg.UniqueKey = tgt.RowRef and stg.Style_Busr1 = tgt.Style_Busr1  and stg.StorerKey = tgt.Storerkey            
           WHERE tgt.Flag = 'Y'    
           AND tgt.EffectiveDate = FORMAT(GETDATE(), 'yyyy-MM-dd')    
           order by tgt.RowRef          
       END        
          
      OPEN CUR_Upd                  
      FETCH NEXT FROM CUR_Upd INTO @n_UniqueKeyGroup,  @c_Style_Busr1Group , @c_StorerKeyGroup, @c_StatusGroup           
      WHILE @@FETCH_STATUS = 0                  
      BEGIN          
        BEGIN TRAN          
          
         IF @c_StatusGroup = '9'          
         BEGIN          
            UPDATE tgt SET [Status] = @c_StatusGroup          
            FROM [DTS].[ExcelImport_DTS_WMS_SKUINFO] tgt          
            WHERE RowRef = @n_UniqueKeyGroup          
            AND Style_Busr1 = @c_Style_Busr1Group         
            AND Storerkey = @c_StorerKeyGroup        
          
            IF @@ERROR <> 0                                               
            BEGIN           
               SELECT @n_continue = 3          
               SELECT @n_err = @@ERROR          
               SELECT @c_errmsg = N'Failed to update target Staging table status = ''9''. Style_Busr1: ' + @c_Style_Busr1Group  --ERROR_MESSAGE()          
               ROLLBACK TRAN                                                                                         
            END              
          
            WHILE @@TRANCOUNT > 0                  
            COMMIT TRAN           
          
         END          
         ELSE          
         BEGIN      
            UPDATE tgt SET [Status] = '5'          
            FROM [DTS].[ExcelImport_DTS_WMS_SKUINFO] tgt          
            WHERE RowRef = @n_UniqueKeyGroup          
            AND Style_Busr1 = @c_Style_Busr1Group          
            AND Storerkey = @c_StorerKeyGroup        
          
            IF @@ERROR <> 0                                               
            BEGIN           
               SELECT @n_continue = 3          
               SELECT @n_err = @@ERROR       
               SELECT @c_errmsg = N'Failed to update target Staging table status = ''5''. Style_Busr1: ' + @c_Style_Busr1Group --ERROR_MESSAGE()    
               ROLLBACK TRAN                                                                                         
            END           
          
            WHILE @@TRANCOUNT > 0                  
            COMMIT TRAN           
         END          
                                  
            FETCH NEXT FROM CUR_Upd INTO @n_UniqueKeyGroup,  @c_Style_Busr1Group , @c_StorerKeyGroup, @c_StatusGroup              
         END                  
         CLOSE CUR_Upd                  
         DEALLOCATE CUR_Upd          
               
   END          
                   
   IF @n_continue=3  -- Error Occured - Process And Return              
   BEGIN              
      SELECT @b_success = 0              
      IF @@TRANCOUNT = 1 and @@TRANCOUNT > @n_starttcnt              
      BEGIN              
   ROLLBACK TRAN              
      END              
      ELSE              
      BEGIN              
         WHILE @@TRANCOUNT > @n_starttcnt              
         BEGIN              
            COMMIT TRAN              
         END              
      END              
      RAISERROR (@c_errmsg, 16, 1) WITH SETERROR    -- SQL2012      
      PRINT 'ErrorMsg:'+ @c_errmsg    
      RETURN              
   END              
   ELSE              
   BEGIN              
      SELECT @b_success = 1              
      WHILE @@TRANCOUNT > @n_starttcnt              
      BEGIN              
         COMMIT TRAN              
      END              
   END              
                  
END --SP 

GO