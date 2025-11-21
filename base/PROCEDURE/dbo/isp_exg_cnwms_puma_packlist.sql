SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
  
/*************************************************************************/    
/* Stored Procedure: isp_EXG_CNWMS_PUMA_PackList                         */    
/* Creation Date: 11 Jun 2020                                            */    
/* Copyright: LFL                                                        */    
/* Written by: GuanHao Chan                                              */    
/*                                                                       */    
/* Purpose: Excel Generator PUMA Packlist Report                         */    
/*                                                                       */    
/* Called By:                                                            */    
/*                                                                       */    
/* PVCS Version: -                                                       */    
/*                                                                       */    
/* Updates:                                                              */    
/* Date          Author   Ver  Purposes                                  */    
/* 11-Jun-2020   GHChan   1.0  Initial Development                       */    
/* 08-Oct-2021   GHChan   2.0  Hardcoded consigneekey between value      */    
/* 06-09-2022    MZhang   3.0  Update for LabelNo                        */  
/*************************************************************************/    
    
    
CREATE    PROCEDURE [dbo].[isp_EXG_CNWMS_PUMA_PackList]    
(  @n_FileKey     INT           = 0    
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
    
   DECLARE @n_Continue      INT = 1    
         , @n_StartTcnt     INT = @@TRANCOUNT    
    
   /*********************************************/    
   /* Variables Declaration (End)               */    
   /*********************************************/    
    
   IF @b_Debug = 1    
   BEGIN    
      PRINT '[dbo].[isp_EXG_CNWMS_PUMA_PackList]: Start...'    
      PRINT '[dbo].[isp_EXG_CNWMS_PUMA_PackList]: '    
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
      '"',Buyerpo , '"', @c_Delimiter, '"', Externorderkey ,'"', @c_Delimiter,     
      '"',Loadkey , '"', @c_Delimiter, '"', Consigneekey, '"', @c_Delimiter,     
      '"',[C Company], '"', @c_Delimiter, '"', Departuredate , '"', @c_Delimiter,     
      '"',Arrivaldate,'"', @c_Delimiter, '"',Address1, '"', @c_Delimiter,     
      '"',Address2, '"', @c_Delimiter, '"', Address3, '"', @c_Delimiter,     
      '"',Address4, '"', @c_Delimiter, '"', Cartonno, '"', @c_Delimiter,    
      '"',[Column 13],'"', @c_Delimiter,      
      '"',Ean1, '"', @c_Delimiter, '"', Article, '"', @c_Delimiter,     
      '"',Size,'"', @c_Delimiter, '"',Qty, '"', @c_Delimiter,     
      '"',Amssku,'"', @c_Delimiter, '"',Skugroup, '"', @c_Delimiter,     
      '"',Itemclass, '"', @c_Delimiter, '"', Ean2,'"', @c_Delimiter,     
      '"',Ean3, '"', @c_Delimiter, '"', Consigneekey1  ,'"', @c_Delimiter, '"',Labelno , '"') AS LineText1    
      FROM (    
      SELECT     
         'Buyerpo' AS Buyerpo    
      ,  'Externorderkey' AS Externorderkey    
      ,  'Loadkey' AS Loadkey    
      ,  'Consigneekey' AS Consigneekey    
      ,  'C Company' AS [C Company]    
      ,  'Departuredate' AS Departuredate    
      ,  'Arrivaldate' AS Arrivaldate    
      ,  'Address1' AS Address1    
      ,  'Address2' AS Address2    
      ,  'Address3' AS Address3    
      ,  'Address4' AS Address4    
      ,  'Cartonno' AS Cartonno    
      ,  'Column 13' AS [Column 13]    
      ,  'Ean1' AS Ean1    
      ,  'Article' AS Article    
      ,  'Size' AS Size    
      ,  'Qty' AS Qty    
      ,  'Amssku' AS Amssku    
      ,  'Skugroup' AS Skugroup    
      ,  'Itemclass' AS Itemclass    
      ,  'Ean2' AS Ean2    
      ,  'Ean3' AS Ean3    
      ,  'Consigneekey1' AS Consigneekey1    
      ,  'Labelno' AS Labelno) AS TEMP1    
          
    
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
      '"',Buyerpo , '"', @c_Delimiter, '"', Externorderkey ,'"', @c_Delimiter,     
      '"',Loadkey , '"', @c_Delimiter, '"', Consigneekey, '"', @c_Delimiter,     
      '"',[C Company], '"', @c_Delimiter, '"', Departuredate , '"', @c_Delimiter,     
      '"',Arrivaldate,'"', @c_Delimiter, '"',Address1, '"', @c_Delimiter,     
      '"',Address2, '"', @c_Delimiter, '"', Address3, '"', @c_Delimiter,     
      '"',Address4, '"', @c_Delimiter, '"', Cartonno, '"', @c_Delimiter,    
      '"',[Column 13],'"', @c_Delimiter,     
      '"',Ean1, '"', @c_Delimiter, '"', Article, '"', @c_Delimiter,     
      '"',Size,'"', @c_Delimiter, Qty, @c_Delimiter,     
      '"',Amssku,'"', @c_Delimiter, '"',Skugroup, '"', @c_Delimiter,     
      '"',Itemclass, '"', @c_Delimiter, '"', Ean2,'"', @c_Delimiter,     
      '"',Ean3, '"', @c_Delimiter, '"', Consigneekey1  ,'"', @c_Delimiter, '"',Labelno , '"') AS LineText1    
      FROM (    
      SELECT ISNULL(RTRIM(O.BuyerPO), '') AS Buyerpo      
      ,ISNULL(RTRIM(O.ExternOrderKey), '') AS Externorderkey        
      ,ISNULL(RTRIM(SUBSTRING(O.LoadKey, PATINDEX('%[^0]%', O.LoadKey+'.'), LEN(O.LoadKey))), '') AS Loadkey        
      ,ISNULL(RTRIM(SUBSTRING(O.ConsigneeKey, PATINDEX('%[^0]%', O.ConsigneeKey+'.'), LEN(O.ConsigneeKey))), '') AS Consigneekey    
      ,ISNULL(RTRIM(O.C_Company), '') AS [C Company]         
      ,FORMAT(O.editdate, 'M/d/yyyy') AS Departuredate    
      --------------------------------------------------------------Modify Start By Song Jian on 2002-04-29    
      --,FORMAT(M.ArrivalDate, 'M/d/yyyy') AS Arrivaldate      
      , case     
        when RTRIM(CL2.SHORT) = '' Then FORMAT(M.EditDate, 'M/d/yyyy')    
        else FORMAT(dateadd(day,convert(int,RTRIM(CL2.SHORT)),M.EditDate), 'M/d/yyyy')    
       end AS Arrivaldate    
      --------------------------------------------------------------Modify End By Song Jian on 2002-04-29    
      ,ISNULL(RTRIM(O.C_Address1), '') AS Address1       
      ,ISNULL(RTRIM(O.C_Address2), '') AS Address2       
      ,ISNULL(RTRIM(O.C_Address3), '') AS Address3        
      ,ISNULL(RTRIM(O.C_Address4), '') AS Address4    
      ,ISNULL(RTRIM(PAD.CartonNo), '''') AS Cartonno    
      ,ISNULL(RTRIM(''''+ PAD.SKU), '') AS [Column 13]        
      ,ISNULL(RTRIM(SKU.ManufacturerSKU), '') AS Ean1     
      ,ISNULL(RTRIM(''''+ LTRIM(RTRIM(SKU.Style)) + LTRIM(RTRIM(SKU.Color))), '') AS Article     
      ,ISNULL(RTRIM(SKU.Size), '') AS Size        
      ,CASE        
           WHEN LEN(PH.Orderkey) = 0 THEN SUM(ISNULL(PD.Qty ,0))    
           ELSE SUM(ISNULL(PAD.Qty ,0))    
       END AS Qty        
      ,ISNULL(RTRIM(SKU.BUSR6), '') AS Amssku    
      ,ISNULL(RTRIM(SKU.SKUGroup), '') AS Skugroup       
      ,ISNULL(RTRIM(SKU.ItemClass), '') AS Itemclass    
      ,ISNULL(RTRIM(SKU.RetailSKU), '') AS Ean2        
      ,ISNULL(RTRIM(SKU.AltSKU), '') AS Ean3    
      ,CASE ISNUMERIC(O.ConsigneeKey)       
            WHEN 1 THEN ISNULL(RTRIM(CAST(CAST(O.ConsigneeKey AS INT) AS NCHAR)), '')      
            ELSE ISNULL(RTRIM(O.ConsigneeKey), '')      
       END AS Consigneekey1        
      ,Labelno = /* CASE         
                    WHEN O.Consigneekey BETWEEN '0003920001' AND '0003929999' THEN 'W'   --2.0  
                    ELSE 'O'         
                 PAD.LabelNo         
                 END      
        + O.LoadKey + RIGHT('00000' + RTRIM(CAST(PAD.CartonNo AS NCHAR)) ,5)  */  
    PAD.LabelNo  
       FROM  dbo.PACKHEADER PH WITH (NOLOCK)     
       JOIN (    
       SELECT Storerkey      
       ,Pickslipno    
       ,CartonNo       
       ,LabelNo        
       ,SKU     
       ,SUM(Qty) AS Qty       
       FROM   dbo.PACKDETAIL(NOLOCK)      
       WHERE  Storerkey = @c_ParamVal1          
       GROUP BY      
       Storerkey    
       ,Pickslipno     
       ,CartonNo     
       ,LabelNo       
       ,SKU       
       ) AS PAD       
       ON  PH.PickSlipNo = PAD.PickSlipNo      
       AND  PH.StorerKey = PAD.StorerKey       
       JOIN dbo.ORDERS O WITH(NOLOCK)       
       ON  (    
       O.Loadkey = PH.Loadkey    
       AND ISNULL(RTRIM(PH.Orderkey) ,'') = ''    
       ) OR (      
       O.Orderkey = PH.Orderkey       
       AND ISNULL(RTRIM(PH.Orderkey) ,'') <> ''       
       )      
       JOIN dbo.SKU SKU(NOLOCK)      
       ON  PAD.Storerkey = SKU.Storerkey       
       AND PAD.SKU = SKU.SKU      
       JOIN dbo.ORDERDETAIL OD WITH (NOLOCK)        
       ON  OD.SKU = PAD.SKU      
       AND OD.OrderKey = O.OrderKey       
       JOIN dbo.MBOLDetail MD WITH(NOLOCK)       
       ON  O.OrderKey = MD.OrderKEy      
       JOIN dbo.MBOL M WITH(NOLOCK)        
       ON  MD.MbolKey = M.Mbolkey       
      --------------------------------------------------------------Modify Start By Song Jian on 2002-04-29    
       LEFT OUTER JOIN dbo.Codelkup CL2 WITH (NOLOCK)        
       ON (CL2.Listname = 'CityLdTime' AND --substring(CL2.code,1,4) = 'PUMA'     
       CL2.Storerkey = @c_ParamVal1 AND    
      -- O.c_city LIKE N'%' + ISNULL(LTRIM(RTRIM(CL2.description)), '') +'%')       
       Charindex(O.c_city,ISNULL(LTRIM(RTRIM(CL2.description)), '')) >0 )    
       --------------------------------------------------------------Modify End By Song Jian on 2002-04-29    
       LEFT OUTER JOIN (        
       SELECT StorerKey      
       ,OrderKey        
       ,OrderLineNumber        
        ,SKU        
        ,DropId        
        ,SUM(Qty) AS Qty        
        FROM dbo.PICKDETAIL(NOLOCK)     
        WHERE  StorerKey = @c_ParamVal1        
        GROUP BY     
        Storerkey      
       ,Orderkey     
       ,OrderLineNumber       
 ,SKU      
       ,DropId       
       ) AS PD        
       ON  PD.Orderkey = O.Orderkey       
       AND PD.DropID = PAD.LabelNo        
       AND PD.Storerkey = PAD.Storerkey      
       AND PD.Sku = PAD.Sku     
       AND ISNULL(RTRIM(PH.Orderkey) ,'') = ''        
       AND PD.OrderLineNumber = OD.OrderLineNumber       
       WHERE  O.Storerkey = @c_ParamVal1      
       AND    MD.MbolKey =  @c_ParamVal2    
       GROUP BY    
       O.ExternOrderKey       
       ,O.BuyerPO      
       ,O.LoadKey       
       ,O.ConsigneeKey      
       ,RTRIM(O.C_Company)      
       ,O.editdate     
        --------------------------------------------------------------Modify Start By Song Jian on 2002-04-29    
      -- ,FORMAT(M.ArrivalDate, 'M/d/yyyy')    
       , case     
        when RTRIM(CL2.SHORT) = '' Then FORMAT(M.EditDate, 'M/d/yyyy')    
        else FORMAT(dateadd(day,convert(int,RTRIM(CL2.SHORT)),M.EditDate), 'M/d/yyyy')    
       end     
       --------------------------------------------------------------Modify End By Song Jian on 2002-04-29    
       ,RTRIM(O.C_Address1)       
       ,RTRIM(O.C_Address2)      
       ,RTRIM(O.C_Address3)       
       ,RTRIM(O.C_Address4)     
       ,PAD.CartonNO    
       ,''''+ PAD.SKU    
       ,SKU.BUSR6       
       ,SKU.SKUGroup      
       ,SKU.ItemClass      
       ,'''' + LTRIM(RTRIM(SKU.Style)) + LTRIM(RTRIM(SKU.Color))     
       ,SKU.Size     
       ,SKU.ManufacturerSKU     
       ,SKU.RetailSKU        
       ,SKU.AltSKU        
       ,PH.Orderkey        
       ,CASE ISNUMERIC(O.ConsigneeKey)        
       WHEN 1 THEN CAST(CAST(O.ConsigneeKey AS INT) AS NCHAR)       
       ELSE O.ConsigneeKey      
       END      
       ,/*CASE        
       WHEN O.Consigneekey BETWEEN '0003920001' AND '0003929999' THEN 'W' ELSE 'O'      --2.0  
       END +  O.LoadKey + RIGHT('00000' + RTRIM(CAST(PAD.CartonNo AS NCHAR)) ,5)) */  
    PAD.LabelNo) AS TEMP2     -- 3.0  
    
   END TRY    
   BEGIN CATCH    
      SET @n_Err = ERROR_NUMBER();    
      SET @c_ErrMsg = ERROR_MESSAGE() + ' (isp_EXG_CNWMS_PUMA_PackList)'    
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
         PRINT '[dbo].[isp_EXG_CNWMS_PUMA_PackList]: @c_ErrMsg=' + RTRIM(@c_ErrMsg)    
         PRINT '[dbo].[isp_EXG_CNWMS_PUMA_PackList]: @b_Success=' + RTRIM(CAST(@b_Success AS NVARCHAR))    
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
         PRINT '[dbo].[isp_EXG_CNWMS_PUMA_PackList]: @c_ErrMsg=' + RTRIM(@c_ErrMsg)    
         PRINT '[dbo].[isp_EXG_CNWMS_PUMA_PackList]: @b_Success=' + RTRIM(CAST(@b_Success AS NVARCHAR))    
      END          
      RETURN          
   END            
   /***********************************************/          
   /* Std - Error Handling (End)                  */          
   /***********************************************/    
END -- End Procedure    


GO