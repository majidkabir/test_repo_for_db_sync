SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
       
/*************************************************************************/      
/* Stored Procedure: isp_EXG_CNWMS_PORSCHE_GoodsOutNotice                */      
/* Creation Date: 14 Apr 2020                                            */      
/* Copyright: LFL                                                        */      
/* Written by: GHChan                                                    */      
/*                                                                       */      
/* Purpose: Excel Generator Porsche Goods Out Notices                    */      
/*                                                                       */      
/* Called By:                                                            */      
/*                                                                       */      
/* PVCS Version: -                                                       */      
/*                                                                       */      
/* Updates:                                                              */      
/* Date          Author   Ver  Purposes                                  */      
/* 14-Apr-2020   GHChan   1.0  Initial Development                       */      
/* 21-Apr-2020   TKLim    2.0  Filter OD.OriginalQty > 0 (TK01)          */  
/* 13-Jun-2020   GHCHan   3.0  Modify SP for cater new MAIN SP           */     
/*************************************************************************/      
      
      
CREATE PROCEDURE [dbo].[isp_EXG_CNWMS_PORSCHE_GoodsOutNotice]      
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
      
   DECLARE @n_Continue        INT  = 1      
         , @n_StartTcnt       INT  = @@TRANCOUNT   
           
   /*********************************************/      
   /* Variables Declaration (End)               */      
   /*********************************************/      
      
   IF @b_Debug = 1      
   BEGIN      
      PRINT '[dbo].[isp_EXG_CNWMS_PORSCHE_GoodsOutNotice]: Start...'      
      PRINT '[dbo].[isp_EXG_CNWMS_PORSCHE_GoodsOutNotice]: '      
          + ',@n_FileKey='      + ISNULL(RTRIM(@n_FileKey), '')  
      + ',@n_EXG_Hdr_ID='   + ISNULL(RTRIM(@n_EXG_Hdr_ID), '')  
          + ',@c_FileName='    + ISNULL(RTRIM(@c_FileName), '')  
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
      ,CONCAT(  
            '"', [PCN Order Number], '"', @c_Delimiter,   
            '"', [Shipped Item Code], '"', @c_Delimiter,   
            '"', [Pcn Item Code], '"', @c_Delimiter,   
            '"', [Category], '"', @c_Delimiter,   
            '"', [Description En], '"', @c_Delimiter,   
            '"', [Qty], '"', @c_Delimiter,   
            '"', [Pcs per Unit], '"', @c_Delimiter,   
            '"', [LF Order Number], '"', @c_Delimiter,   
            '"', [Ship Date], '"', @c_Delimiter,   
            '"', [Tracking Number], '"') AS LineText1  
      FROM (  
         SELECT  
            'PCN Order Number' AS [PCN Order Number]  
         ,  'Shipped Item Code' AS [Shipped Item Code]  
         ,  'Pcn Item Code' AS [Pcn Item Code]  
         ,  'Category' AS [Category]  
         ,  'Description En' AS [Description En]  
         ,  'Qty' AS [Qty]  
         ,  'Pcs per Unit' AS [Pcs per Unit]  
         ,  'LF Order Number' AS [LF Order Number]  
         ,  'Ship Date' AS [Ship Date]  
         ,  'Tracking Number' AS [Tracking Number]) AS TEMP1  
  
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
            '"',[PCN Order Number], '"', @c_Delimiter,   
            '"', [Shipped Item Code], '"', @c_Delimiter,   
            '"', [Pcn Item Code], '"', @c_Delimiter,   
            '"', [Category], '"', @c_Delimiter,   
            '"', [Description En], '"', @c_Delimiter,   
            '"', [Qty], '"', @c_Delimiter,   
            '"', [Pcs per Unit], '"', @c_Delimiter,   
            '"', [LF Order Number], '"', @c_Delimiter,   
            '"', [Ship Date], '"', @c_Delimiter,   
            '"', [Tracking Number], '"') AS LineText1  
      FROM (  
      SELECT ISNULL(RTRIM(OH.ExternOrderKey), '') AS [PCN Order Number]  
      ,ISNULL(RTRIM(SKU.SKU), '') AS [Shipped Item Code]  
      ,ISNULL(RTRIM(SKU.AltSKU), '') AS [Pcn Item Code]  
      ,ISNULL(RTRIM(SI.ExtendedField02), '') AS [Category]  
      ,ISNULL(RTRIM(SKU.Notes2), '') AS [Description En]  
      ,ISNULL(RTRIM(OD.ShippedQty), '') AS [Qty]  
      ,ISNULL(RTRIM(SKU.IB_RPT_UOM), '') AS [Pcs per Unit]  
      ,ISNULL(RTRIM(OH.OrderKey), '') AS [LF Order Number]  
      ,CONVERT(NVARCHAR(10),MH.ShipDate,120) as [Ship Date]      
      ,ISNULL(RTRIM(OH.UserDefine04), '') AS [Tracking Number]    
       FROM dbo.MBOL MH WITH (NOLOCK)  
       INNER JOIN dbo.MBOLDetail MD (NOLOCK)  
       ON MD.MBOLKey = MH.MBOLKey  
       INNER JOIN dbo.Orders OH (NOLOCK)  
       ON OH.OrderKey = MD.OrderKey  
       INNER JOIN dbo.OrderDetail OD (NOLOCK)  
       ON OD.OrderKey = OH.OrderKey  
       INNER JOIN dbo.SKU SKU (NOLOCK)  
       ON SKU.StorerKey = OD.StorerKey AND SKU.SKU = OD.SKU  
       INNER JOIN dbo.SKUInfo SI (NOLOCK)  
       ON SI.StorerKey = OD.StorerKey AND SI.SKU = OD.SKU  
       WHERE  OH.Facility =  @c_ParamVal2  
       AND    MH.Mbolkey = @c_ParamVal3  
       AND    MD.OrderKey =  @c_ParamVal4  
       AND    OD.OriginalQty > 0 --(TK01)  
       ORDER BY OD.StorerKey, MH.Mbolkey  
       OFFSET 0 ROWS  
      ) AS TEMP2  
   END TRY      
   BEGIN CATCH      
      SET @n_Err = ERROR_NUMBER();  
      SET @c_ErrMsg = ERROR_MESSAGE() + ' (isp_EXG_CNWMS_PORSCHE_GoodsOutNotice)'  
      SET @n_Continue = 3           
      GOTO QUIT      
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
         PRINT '[dbo].[isp_EXG_CNWMS_PORSCHE_GoodsOutNotice]: @c_ErrMsg=' + RTRIM(@c_ErrMsg)      
         PRINT '[dbo].[isp_EXG_CNWMS_PORSCHE_GoodsOutNotice]: @b_Success=' + RTRIM(CAST(@b_Success AS NVARCHAR))      
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
         PRINT '[dbo].[isp_EXG_CNWMS_PORSCHE_GoodsOutNotice]: @c_ErrMsg=' + RTRIM(@c_ErrMsg)      
         PRINT '[dbo].[isp_EXG_CNWMS_PORSCHE_GoodsOutNotice]: @b_Success=' + RTRIM(CAST(@b_Success AS NVARCHAR))      
      END            
      RETURN            
   END              
   /***********************************************/            
   /* Std - Error Handling (End)                  */            
   /***********************************************/      
END -- End Procedure 

GO