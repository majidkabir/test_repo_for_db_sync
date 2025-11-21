SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
  
/*************************************************************************/  
/* Stored Procedure: isp_EXG_CNWMS_PUMA_BuyerPO                          */  
/* Creation Date: 11 Jun 2020                                            */  
/* Copyright: LFL                                                        */  
/* Written by: GuanHao Chan                                              */  
/*                                                                       */  
/* Purpose: Excel Generator PUMA BuyerPO Report                          */  
/*                                                                       */  
/* Called By:                                                            */  
/*                                                                       */  
/* PVCS Version: -                                                       */  
/*                                                                       */  
/* Updates:                                                              */  
/* Date          Author   Ver  Purposes                                  */  
/* 11-Jun-2020   GHChan   1.0  Initial Development                       */  
/*************************************************************************/  
  
CREATE PROCEDURE [dbo].[isp_EXG_CNWMS_PUMA_BuyerPO]  
( @n_FileKey     INT           = 0  
,  @n_EXG_Hdr_ID  INT   = 0  
,  @c_FileName    NVARCHAR(200) = ''  
,  @c_SheetName   NVARCHAR(100) = ''  
,  @c_Delimiter   NVARCHAR(2)   = ''  
,  @c_ParamVal1   NVARCHAR(200) = ''  
,  @c_ParamVal2   NVARCHAR(200) = ''  
,  @c_ParamVal3   NVARCHAR(200) = ''  
,  @c_ParamVal4   NVARCHAR(200) = ''  
,  @c_ParamVal5   NVARCHAR(200) = ''  
,  @c_ParamVal6   NVARCHAR(200) = ''  
,  @c_ParamVal7   NVARCHAR(200) = ''  
,  @c_ParamVal8   NVARCHAR(200) = ''  
,  @c_ParamVal9   NVARCHAR(200) = ''  
,  @c_ParamVal10  NVARCHAR(200) = ''  
,  @b_Debug       INT           = 1  
,  @b_Success     INT           = 1    OUTPUT  
,  @n_Err         INT           = 0    OUTPUT  
,  @c_ErrMsg      NVARCHAR(250) = ''   OUTPUT   
)  
AS  
BEGIN  
   SET NOCOUNT ON   
   SET ANSI_NULLS OFF  
   SET QUOTED_IDENTIFIER OFF   
   SET CONCAT_NULL_YIELDS_NULL OFF    
  
   /*********************************************/  
   /* Variables Declaration (Start)             */  
   /*********************************************/  
  
   DECLARE @n_Continue        INT = 1  
         , @n_StartTcnt       INT = @@TRANCOUNT         
  
   /*********************************************/  
   /* Variables Declaration (End)               */  
   /*********************************************/  
  
   IF @b_Debug = 1  
   BEGIN  
      PRINT '[dbo].[isp_EXG_CNWMS_PUMA_BuyerPO]: Start...'  
      PRINT '[dbo].[isp_EXG_CNWMS_PUMA_BuyerPO]: '  
          + ',@n_FileKey='      + ISNULL(RTRIM(@n_FileKey), '')  
      + ',@n_EXG_Hdr_ID='   + ISNULL(RTRIM(@n_EXG_Hdr_ID), '')  
          + ',@c_FileName='     + ISNULL(RTRIM(@c_FileName), '')  
          + ',@c_SheetName='    + ISNULL(RTRIM(@c_SheetName), '')  
          + ',@c_Delimiter='    + ISNULL(RTRIM(@c_Delimiter), '')  
          + ',@c_ParamVal1='    + ISNULL(RTRIM(@c_ParamVal1), '')  
          + ',@c_ParamVal2='    + ISNULL(RTRIM(@c_ParamVal2), '')  
          + ',@c_ParamVal3='    + ISNULL(RTRIM(@c_ParamVal3), '')  
          + ',@c_ParamVal4='    + ISNULL(RTRIM(@c_ParamVal4), '')  
          + ',@c_ParamVal5='    + ISNULL(RTRIM(@c_ParamVal5), '')  
          + ',@c_ParamVal6='    + ISNULL(RTRIM(@c_ParamVal6), '')  
          + ',@c_ParamVal7='    + ISNULL(RTRIM(@c_ParamVal7), '')  
          + ',@c_ParamVal8='    + ISNULL(RTRIM(@c_ParamVal8), '')  
          + ',@c_ParamVal9='    + ISNULL(RTRIM(@c_ParamVal9), '')  
          + ',@c_ParamVal10='   + ISNULL(RTRIM(@c_ParamVal10), '')  
   END  
  
   BEGIN TRAN  
   BEGIN TRY  
      INSERT INTO [dbo].[EXG_FileDet](  
           file_key  
         , EXG_Hdr_ID  
         , [FileName]  
         , SheetName  
         , [Status]  
         , LineText1)  
      SELECT  @n_FileKey  
      ,  @n_EXG_Hdr_ID   
      , @c_FileName  
      , @c_SheetName  
      , 'W'  
      , CONCAT(  
            '"',Buyerpo, '"', @c_Delimiter,   
            '"', Sku, '"', @c_Delimiter,   
            '"', Article, '"', @c_Delimiter,   
            '"', Size, '"', @c_Delimiter,   
            '"', Qty, '"') AS LineText1  
      FROM (  
         SELECT  
            'Buyerpo' AS Buyerpo  
         ,  'Sku' AS Sku  
         ,  'Article' AS Article  
         ,  'Size' AS Size  
         ,  'Qty' AS Qty) AS TEMP1  
  
      INSERT INTO [dbo].[EXG_FileDet](  
           file_key  
         , EXG_Hdr_ID  
         , [FileName]  
         , SheetName  
         , [Status]  
         , LineText1)  
     SELECT  @n_FileKey  
      ,  @n_EXG_Hdr_ID   
      , @c_FileName  
      , @c_SheetName  
      , 'W'  
      , CONCAT(  
            '"',Buyerpo, '"', @c_Delimiter,   
            '"', Sku, '"', @c_Delimiter,   
            '"', Article, '"', @c_Delimiter,   
            '"', Size, '"', @c_Delimiter,   
            Qty) AS LineText1  
      FROM (  
      SELECT   
         ISNULL(RTRIM(O.BuyerPO), '') AS Buyerpo  
        ,ISNULL(RTRIM('''' + PD.SKU), '') AS Sku  
        ,ISNULL(RTRIM('''' + LTRIM(RTRIM(SKU.Style))    
        + LTRIM(RTRIM(SKU.Color))), '') AS Article  
        ,ISNULL(RTRIM(SKU.Size), '') AS Size  
        ,SUM(ISNULL(PD.Qty ,0)) AS Qty  
        FROM dbo.ORDERS O WITH(NOLOCK)  
        JOIN dbo.PickDetail PD WITH(NOLOCK)   
        ON  O.Orderkey = PD.Orderkey  
        JOIN dbo.SKU SKU(NOLOCK)   
        ON  PD.Storerkey = SKU.Storerkey  
        AND PD.SKU = SKU.SKU  
        JOIN dbo.MBOLDetail MD WITH(NOLOCK)  
        ON  O.OrderKey = MD.OrderKey  
        WHERE O.Storerkey = @c_ParamVal1   
        AND    MD.MbolKey = @c_ParamVal2   
        GROUP BY  
        O.BuyerPO  
        ,''''+ LTRIM(RTRIM(SKU.Style)) + LTRIM(RTRIM(SKU.Color))    
        ,''''+ PD.SKU   
        ,SKU.Size    
        ORDER BY   
        O.BuyerPO   
        ,''''+ LTRIM(RTRIM(SKU.Style)) + LTRIM(RTRIM(SKU.Color))  
        ,SKU  
        OFFSET 0 ROWS) AS TEMP2  
   END TRY  
   BEGIN CATCH  
      SET @n_Err = ERROR_NUMBER();  
      SET @c_ErrMsg = ERROR_MESSAGE() + ' (isp_EXG_CNWMS_PUMA_BuyerPO)'  
      SET @n_Continue = 3  
   END CATCH  
     
  
   QUIT:  
   WHILE @@TRANCOUNT > 0  
      COMMIT TRAN  
  
   WHILE @@TRANCOUNT < @n_StartTCnt        
      BEGIN TRAN   
  
   IF @n_Continue=3  -- Error Occured - Process And Return        
   BEGIN        
      SELECT @b_success = 0        
      IF @@TRANCOUNT > @n_StartTCnt        
      BEGIN                 
         ROLLBACK TRAN        
      END        
      ELSE        
      BEGIN        
         WHILE @@TRANCOUNT > @n_StartTCnt        
         BEGIN        
            COMMIT TRAN        
         END        
      END     
  
      IF @b_Debug = 1  
      BEGIN  
         PRINT '[dbo].[isp_EXG_CNWMS_PUMA_BuyerPO]: @c_ErrMsg=' + RTRIM(@c_ErrMsg)  
         PRINT '[dbo].[isp_EXG_CNWMS_PUMA_BuyerPO]: @b_Success=' + RTRIM(CAST(@b_Success AS NVARCHAR))  
      END  
  
      RETURN        
   END        
   ELSE        
   BEGIN  
      IF ISNULL(RTRIM(@c_ErrMsg), '') <> ''   
      BEGIN  
         SELECT @b_Success = 0  
      END  
      ELSE  
      BEGIN   
         SELECT @b_Success = 1   
      END          
  
      WHILE @@TRANCOUNT > @n_StartTCnt        
      BEGIN        
         COMMIT TRAN        
      END       
        
      IF @b_Debug = 1  
      BEGIN  
         PRINT '[dbo].[isp_EXG_CNWMS_PUMA_BuyerPO]: @c_ErrMsg=' + RTRIM(@c_ErrMsg)  
         PRINT '[dbo].[isp_EXG_CNWMS_PUMA_BuyerPO]: @b_Success=' + RTRIM(CAST(@b_Success AS NVARCHAR))  
      END        
      RETURN        
   END          
   /***********************************************/        
   /* Std - Error Handling (End)                  */        
   /***********************************************/  
END --End Procedure  
  

GO