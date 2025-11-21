SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
       
/****************************************************************************************/      
/* Stored Procedure:  isp_InsertSkuInfo_PVHQHW                                          */      
/* Creation Date:                                                                       */      
/* Copyright: IDS                                                                       */      
/* Written by: kelvinongcy                                                              */      
/*                                                                                      */      
/* Purpose:  https://jiralfl.atlassian.net/browse/WMS-10941                             */      
/*                                                                                      */      
/* Updates:      Author ver   Purpose                                                   */    
/* 18-Nov-2019   kocy   1.0   New Data import into SkuInfo for Storerkey                */     
/*                            'PVHQHW' via Web Excel Loader Management                  */     
/* 05-08-2020    kocy   1.1   New requirement Sku. Style(a) + '_'Sku.Busr1(b)           */    
/*                            = Newtable.Style_Busr1(a_b)]                              */    
/*                            when busr1 is empty, the style is a. when style is empty, */    
/*                            then Busr1 is _b.                                         */    
/*                                                                                      */    
/****************************************************************************************/    
CREATE PROC [dbo].[isp_InsertSkuInfo_PVHQHW]    
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
         , @c_SKU                nvarchar(15)    
         , @Status               nvarchar(5)    
         , @c_Style_Busr1        nvarchar(20)    
         , @n_starttcnt          INT    
         , @n_continue           INT    
         , @b_success            INT    
         , @n_Err                INT    
         , @c_ErrMsg             NVARCHAR(255)    
         ,@c_Delete              NVARCHAR(10)    
    
   SELECT  @n_starttcnt=@@TRANCOUNT,@n_continue=1 , @b_success=0, @n_err=0, @c_errmsg=''     
   SELECT  @Status = '0', @c_Delete = 'Y'    
    
   BEGIN TRAN    
    
    
   DECLARE CUR_RETRIEVED_Style_Busr1 CURSOR LOCAL FAST_FORWARD READ_ONLY FOR    
   SELECT DISTINCT(Style_Busr1)    
   FROM  [DTS].[ExcelImport_WMSSKUINFO_PVHQHW]  WITH (NOLOCK)    
   WHERE StorerKey = @c_StorerKey --'PVHQHW'    
   AND   Flag = 'Y'    
   AND   EffectiveDate = FORMAT(GETDATE(), 'yyyy-MM-dd')    
    
    
   OPEN CUR_RETRIEVED_Style_Busr1    
   FETCH NEXT FROM CUR_RETRIEVED_Style_Busr1 INTO @c_Style_Busr1    
   WHILE @@FETCH_STATUS = 0    
   BEGIN    
      -- if exist a record mean that the EffectiveDate match to today and then delete the old batch records    
      IF (@c_Delete = 'Y' )     
      BEGIN    
         DELETE FROM [dbo].[SKUINFO] WHERE StorerKey = @c_StorerKey    
         SET @c_Delete = 'N'    
      END    
    
      IF (@b_debug =1)    
      BEGIN    
        SELECT @c_Style_Busr1 'Style_Busr1'    
      END    
    
      SET @Status = '9'    
      IF NOT EXISTS ( SELECT 1 FROM [dbo].[SKU] WITH (NOLOCK) WHERE StorerKey = @c_StorerKey     
      AND ( ISNULL(LTRIM(RTRIM(Style)), '') + CASE WHEN ISNULL(LTRIM(RTRIM(Busr1)), '')  <> '' THEN '_' + LTRIM(RTRIM(Busr1)) ELSE '' END )  = @c_Style_Busr1 )    
      BEGIN    
        SET @Status = '5'    
         GOTO NEXT_BUSR1    
      END    
    
      INSERT INTO [dbo].[SKUINFO] (StorerKey, SKU)     
      SELECT StorerKey, SKU    
      FROM  dbo.SKU WITH (NOLOCK)     
      WHERE StorerKey = @c_StorerKey    
      AND  ( ISNULL(LTRIM(RTRIM(Style)), '') + CASE WHEN ISNULL(LTRIM(RTRIM(Busr1)), '') <> '' THEN '_' + LTRIM(RTRIM(Busr1)) ELSE '' END )  = @c_Style_Busr1  --a_b, a, _b    
    
    
      IF @@ERROR <> 0    
      BEGIN    
         ROLLBACK TRAN    
         GOTO NEXT_BUSR1    
      END    
    
      IF (@b_debug =1)    
      BEGIN    
        SELECT  SKU 'SKU'    
        FROM  [dbo].[SKU] WITH (NOLOCK)     
        WHERE StorerKey = @c_StorerKey    
        AND ( ISNULL(LTRIM(RTRIM(Style)), '') + CASE WHEN ISNULL(LTRIM(RTRIM(Busr1)), '') <> '' THEN '_' + LTRIM(RTRIM(Busr1)) ELSE '' END ) = @c_Style_Busr1          
      END    
    
      NEXT_BUSR1:    
    
      UPDATE [DTS].[ExcelImport_WMSSKUINFO_PVHQHW] WITH (ROWLOCK)    
      SET [Status] = @Status    
      WHERE StorerKey   = @c_StorerKey     
      AND   Style_Busr1 = @c_Style_Busr1    
    
      FETCH NEXT FROM CUR_RETRIEVED_Style_Busr1 INTO @c_Style_Busr1    
   END    
   CLOSE CUR_RETRIEVED_Style_Busr1    
   DEALLOCATE CUR_RETRIEVED_Style_Busr1    
    
   QUIT:    
   WHILE @@TRANCOUNT > 0    
      COMMIT TRAN    
    
END --SP    
    

GO