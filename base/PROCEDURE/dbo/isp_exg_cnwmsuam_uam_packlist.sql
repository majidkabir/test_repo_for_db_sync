SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/*************************************************************************/  
/* Stored Procedure: isp_EXG_CNWMSUAM_UAM_PackList                       */  
/* Creation Date: 17 Dec 2020                                            */  
/* Copyright: LFL                                                        */  
/* Written by: GuanHao Chan                                              */  
/*                                                                       */  
/* Purpose: Excel Generator UAM Packlist Report                          */  
/*                                                                       */  
/* Called By:                                                            */  
/*                                                                       */  
/* PVCS Version: -                                                       */  
/*                                                                       */  
/* Updates:                                                              */  
/* Date          Author   Ver  Purposes                                  */  
/* 17-Dec-2020   GHChan   1.0  Initial Development                       */  
/*************************************************************************/  
  
  
CREATE PROCEDURE [dbo].[isp_EXG_CNWMSUAM_UAM_PackList]  
(  @n_FileKey     INT           = 0  
,  @n_EXG_Hdr_ID  INT     = 0  
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
  
   DECLARE @n_Continue      INT = 1  
         , @n_StartTcnt     INT = @@TRANCOUNT  
  
   /*********************************************/  
   /* Variables Declaration (End)               */  
   /*********************************************/  
  
   IF @b_Debug = 1  
   BEGIN  
      PRINT '[dbo].[isp_EXG_CNWMSUAM_UAM_PackList]: Start...'  
      PRINT '[dbo].[isp_EXG_CNWMSUAM_UAM_PackList]: '  
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
      '"',文件名 , '"', @c_Delimiter, '"', Orderkey ,'"', @c_Delimiter,   
      '"',Externorderkey , '"', @c_Delimiter, '"', Consigneekey, '"', @c_Delimiter,   
      '"',[C Company], '"', @c_Delimiter, '"', Cartonno , '"', @c_Delimiter,   
      '"',Labelno,'"', @c_Delimiter, '"',Sku, '"', @c_Delimiter,   
      '"',Qty, '"', @c_Delimiter, '"', Style, '"', @c_Delimiter,   
      '"',Color, '"', @c_Delimiter, '"', Size, '"', @c_Delimiter,  
      '"',Altsku,'"', @c_Delimiter,    
      '"',Address3, '"', @c_Delimiter, '"', 备注, '"'  
      ) AS LineText1  
      FROM (  
      SELECT   
        N'文件名'          AS 文件名  
      ,  'Orderkey'        AS Orderkey  
      ,  'Externorderkey'  AS Externorderkey  
      ,  'Consigneekey'    AS Consigneekey  
      ,  'C Company'       AS [C Company]  
      ,  'Cartonno'        AS Cartonno  
      ,  'Labelno'         AS Labelno  
      ,  'Sku'             AS Sku  
      ,  'Qty'             AS Qty  
      ,  'Style'           AS Style  
      ,  'Color'           AS Color  
      ,  'Size'            AS Size  
      ,  'Altsku'          AS Altsku  
      ,  'Address3'        AS Address3  
      , N'备注'            AS 备注  
      ) AS TEMP1  
        
  
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
      '"',文件名 , '"', @c_Delimiter, '"', Orderkey ,'"', @c_Delimiter,   
      '"',Externorderkey , '"', @c_Delimiter, '"', Consigneekey, '"', @c_Delimiter,   
      '"',[C Company], '"', @c_Delimiter, '"', Cartonno , '"', @c_Delimiter,   
      '"',Labelno,'"', @c_Delimiter, '"',Sku, '"', @c_Delimiter,   
      '"',Qty, '"', @c_Delimiter, '"', Style, '"', @c_Delimiter,   
      '"',Color, '"', @c_Delimiter, '"', Size, '"', @c_Delimiter,  
      '"',Altsku,'"', @c_Delimiter,    
      '"',Address3, '"', @c_Delimiter, '"', 备注, '"'  
      ) AS LineText1  
      FROM (  
      SELECT ISNULL(RTRIM(TRIM(O.Consigneekey)+'_'+TRIM(O.Externorderkey)+'_'+TRIM(O.C_Company)), '') AS [文件名],  
             ISNULL(RTRIM(O.Orderkey), '')         AS Orderkey,    
             ISNULL(RTRIM(O.Externorderkey), '')   AS Externorderkey,  
             ISNULL(RTRIM(O.Consigneekey), '')     AS Consigneekey,  
             ISNULL(RTRIM(O.C_Company), '')        AS [C Company],  
             PT.Cartonno                           AS Cartonno,  
             ISNULL(RTRIM(PT.Labelno), '')         AS Labelno,  
             ISNULL(RTRIM(PT.Sku), '')             AS Sku,  
             PT.Qty                                AS Qty,  
             ISNULL(RTRIM(SKU.Style), '')          AS Style,  
             ISNULL(RTRIM(SKU.Color), '')          AS Color,  
             ISNULL(RTRIM(SKU.Size), '')           AS Size,  
             ISNULL(RTRIM(SKU.Altsku), '')         AS Altsku,  
             ISNULL(RTRIM(O.C_Address3), '')       AS Address3,  
             ISNULL(RTRIM(O.M_address1), '')       AS 备注  
      FROM dbo.Packheader PD WITH(NOLOCK)  
      JOIN dbo.PackDetail PT WITH(NOLOCK)  
      ON PD.pickslipno = PT.pickslipno  
    JOIN dbo.ORDERS O WITH(NOLOCK)  
    ON  PD.ORDERKEY = O.ORDERKEY  
      JOIN dbo.SKU SKU WITH(NOLOCK)  
      ON PD.Storerkey = SKU.Storerkey  
      AND PT.SKU = SKU.SKU  
      JOIN dbo.MBOLDetail MD WITH(NOLOCK)  
      ON O.OrderKey = MD.OrderKEy  
      JOIN dbo.CODELKUP CD WITH(NOLOCK)  
    ON PD.Storerkey = CD.Storerkey   
    AND CD.LISTNAME='UAPOD'  
      WHERE  O.Storerkey = @c_ParamVal1  
      AND MD.MbolKey = @c_ParamVal2   
      AND O.Consigneekey = @c_ParamVal3  
      AND O.C_Company <> ''  
      AND CD.Short='1'  
      ORDER BY O.Orderkey,PT.Cartonno  
      OFFSET 0 ROWS  
      ) AS TEMP2  
  
   END TRY  
   BEGIN CATCH  
      SET @n_Err = ERROR_NUMBER();  
      SET @c_ErrMsg = ERROR_MESSAGE() + ' (isp_EXG_CNWMSUAM_UAM_PackList)'  
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
         PRINT '[dbo].[isp_EXG_CNWMSUAM_UAM_PackList]: @c_ErrMsg=' + RTRIM(@c_ErrMsg)  
         PRINT '[dbo].[isp_EXG_CNWMSUAM_UAM_PackList]: @b_Success=' + RTRIM(CAST(@b_Success AS NVARCHAR))  
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
         PRINT '[dbo].[isp_EXG_CNWMSUAM_UAM_PackList]: @c_ErrMsg=' + RTRIM(@c_ErrMsg)  
         PRINT '[dbo].[isp_EXG_CNWMSUAM_UAM_PackList]: @b_Success=' + RTRIM(CAST(@b_Success AS NVARCHAR))  
      END        
      RETURN        
   END          
   /***********************************************/        
   /* Std - Error Handling (End)                  */        
   /***********************************************/  
END -- End Procedure  

GO