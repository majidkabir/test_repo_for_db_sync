SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/*************************************************************************/  
/* Stored Procedure: isp_EXG_CNWMSNKE_CONVERSE_PackList                  */  
/* Creation Date: 08-Jul-2020                                            */  
/* Copyright: LFL                                                        */  
/* Written by: GHChan                                                    */  
/*                                                                       */  
/* Purpose: Excel Generator CONVERSE PackList Sheet Report               */  
/*                                                                       */  
/* Called By:                                                            */  
/*                                                                       */  
/* PVCS Version: -                                                       */  
/*                                                                       */  
/* Updates:                                                              */  
/* Date          Author   Ver  Purposes                                  */  
/* 08-Jul-2020   GHChan   1.0  Initial Development                       */
/* 26-Jul-2021   GHChan   2.0  Ticket WMS-16796                          */
/*************************************************************************/  
  
CREATE PROCEDURE [dbo].[isp_EXG_CNWMSNKE_CONVERSE_PackList]  
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
      PRINT '[dbo].[isp_EXG_CNWMSNKE_CONVERSE_PackList]: Start...'  
      PRINT '[dbo].[isp_EXG_CNWMSNKE_CONVERSE_PackList]: '  
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
  
   ---- Check whether got records   
   --IF @n_EXG_Hdr_ID = 1  
   --BEGIN  
   --   IF NOT EXISTS (  
   --   Select   1
   --   From dbo.Orders as t1(nolock)   
   --   inner join dbo.PackHeader as t2(nolock) on t1.Orderkey=t2.Orderkey and t2.status='9'   
   --   inner join dbo.PackDetail as t3(nolock) on t2.Pickslipno=t3.Pickslipno   
   --      inner join (select Distinct storerkey,Orderkey,SKU, userdefine06,Userdefine09   
   --               from dbo.Orderdetail(nolock)   
   --                  where Storerkey=@c_ParamVal1) as t8 on t2.Orderkey=t8.Orderkey and t3.SKU=t8.SKU    
   --   inner join dbo.SKU as t4(nolock) on t3.Storerkey=t4.Storerkey and t3.SKU=t4.SKU   
   --   left  join dbo.UCC as t5(nolock) on t3.Storerkey=t5.Storerkey and t3.SKU=t5.SKU and t3.UPC=t5.UCCNo   
   --   left  join dbo.Storer as t7(nolock) on ltrim(rtrim(t1.Billtokey))+ltrim(rtrim(t1.Consigneekey))=t7.Storerkey   
   --   --left  join dbo.Codelkup as t6(nolock) on t6.ListName='CityLdTime' and cast(t6.Notes as varchar(20))='Converse' and (case when len(t1.Consigneekey)=10 and t1.Consigneekey=t6.code then 1 when len(t1.Consigneekey)=7 and ltrim(rtrim(t1.Billtokey))+ltrim(rtrim(t1.Consigneekey))=t6.Code then 1 else 0 end)=1   
   --   left  join dbo.Codelkup as t6(nolock) on t6.ListName='CityLdTime' and cast(t6.Notes as varchar(20))=@c_ParamVal1 and t1.Consigneekey = t6.code   
   --   Where t1.Mbolkey = @c_ParamVal2 and t1.Consigneekey = @c_ParamVal3 and t1.Status in('5','9'))  
   --   BEGIN  
   --      SET @n_Err = 200001  
   --   SET @c_ErrMsg ='No records have been found! (isp_EXG_CNWMSNKE_CONVERSE_PackList)'  
   --      SET @n_Continue = 3  
   --      GOTO QUIT  
   --   END  
   --END  
   --ELSE IF  @n_EXG_Hdr_ID = 3  
   --BEGIN  
   --   IF NOT EXISTS (  
   --   Select   1      
   --   From  dbo.Orders as t1(nolock)   
   --   inner join dbo.PackHeader as t2(nolock) on t1.Orderkey=t2.Orderkey and t2.status='9'   
   --   inner join dbo.PackDetail as t3(nolock) on t2.Pickslipno=t3.Pickslipno   
   --   inner join dbo.SKU as t4(nolock) on t3.Storerkey=t4.Storerkey and t3.SKU=t4.SKU   
   --   left  join dbo.UCC as t5(nolock) on t3.Storerkey=t5.Storerkey and t3.SKU=t5.SKU and t3.UPC=t5.UCCNo   
   --   left  join dbo.Storer as t7(nolock) on ltrim(rtrim(t1.Billtokey))+ltrim(rtrim(t1.Consigneekey))=t7.Storerkey   
   --   left  join dbo.Codelkup as t6(nolock) on t6.ListName='CityLdTime' and cast(t6.Notes as varchar(20))='Converse' and t1.Consigneekey = t6.code   
   --   Where t1.Mbolkey=@c_ParamVal2 and t1.Consigneekey = @c_ParamVal3 and t1.Status in('5','9'))  
   --   BEGIN  
   --      SET @n_Err = 200001  
   --      SET @c_ErrMsg ='No records have been found! (isp_EXG_CNWMS_CONVERSE_PackList)'  
   --      SET @n_Continue = 3  
   --      GOTO QUIT  
   --   END  
   --END  
  
   BEGIN TRAN  
   BEGIN TRY  
  
      -- Records exists start to insert column header and rows values into EXG_FileDet  
  
      IF @n_EXG_Hdr_ID = 1  
      BEGIN  
         INSERT INTO [dbo].[EXG_FileDet](  
              file_key  
            , EXG_Hdr_ID  
            , [FileName]  
            , SheetName  
            , [Status]  
            , LineText1)  
         SELECT  @n_FileKey  
            , @n_EXG_Hdr_ID   
            , @c_FileName  
            , @c_SheetName  
            , 'W'  
            , CONCAT(  
                  '"', [å‘è´§å•å·(Shipment Number)], '"', @c_Delimiter,   
                  '"', [PTå·(PickShip Number)], '"', @c_Delimiter,   
                  '"', [è®¢å•å·(SO Number)], '"', @c_Delimiter,   
                  '"', [å‘è´§æ—¥æœŸ(Shipped Date)], '"', @c_Delimiter,   
                  '"', [é¢„è®¡åˆ°è´§æ—¥æœŸ(ETA)], '"', @c_Delimiter,   
                  '"', [å®¢æˆ·ç¼–å·(Sold to Code)], '"', @c_Delimiter,   
                  '"', [æ”¶è´§å•ä½(Ship to code)], '"', @c_Delimiter,   
                  '"', [å®¢æˆ·åç§°(CustomerName)], '"', @c_Delimiter,   
                  '"', [é€è´§åœ°å€(Ship to Address)], '"', @c_Delimiter,   
                  '"', [ç®±å·(CartonNo)], '"', @c_Delimiter,   
                  '"', [æ¬¾å·(Style)], '"', @c_Delimiter,   
                  '"', [é¢œè‰²(Color)], '"', @c_Delimiter,   
                  '"', [å°ºç (Size)], '"', @c_Delimiter,   
                  '"', [Material_Number], '"', @c_Delimiter,   
                  '"', [äº§å“å¤§ç±»(SKUClass)], '"', @c_Delimiter,   
                  '"', [äº§å“æ¡ç (Product barcode)], '"', @c_Delimiter,   
                  '"', [å­£èŠ‚(Season Code)], '"', @c_Delimiter,   
                  '"', [å‘è´§æ•°é‡(ShippedQty)], '"', @c_Delimiter,   
                  '"', [å¤–ç®±æ¡ç (UCC)], '"', @c_Delimiter,   
                  '"', [Consigneekey], '"', @c_Delimiter,   
                  '"', [æ¡ç ], '"', @c_Delimiter,     
                  '"', [æ€»å•å·(Load)], '"') AS LineText1    
         FROM (  
            SELECT  
               N'å‘è´§å•å·(Shipment Number)' AS [å‘è´§å•å·(Shipment Number)]  
            ,  N'PTå·(PickShip Number)' AS [PTå·(PickShip Number)]  
            ,  N'è®¢å•å·(SO Number)' AS [è®¢å•å·(SO Number)]  
            ,  N'å‘è´§æ—¥æœŸ(Shipped Date)' AS [å‘è´§æ—¥æœŸ(Shipped Date)]  
            ,  N'é¢„è®¡åˆ°è´§æ—¥æœŸ(ETA)' AS [é¢„è®¡åˆ°è´§æ—¥æœŸ(ETA)]  
            ,  N'å®¢æˆ·ç¼–å·(Sold to Code)' AS [å®¢æˆ·ç¼–å·(Sold to Code)]  
            ,  N'æ”¶è´§å•ä½(Ship to code)' AS [æ”¶è´§å•ä½(Ship to code)]  
            ,  N'å®¢æˆ·åç§°(CustomerName)' AS [å®¢æˆ·åç§°(CustomerName)]  
            ,  N'é€è´§åœ°å€(Ship to Address)' AS [é€è´§åœ°å€(Ship to Address)]  
            ,  N'ç®±å·(CartonNo)' AS [ç®±å·(CartonNo)]  
            ,  N'æ¬¾å·(Style)' AS [æ¬¾å·(Style)]  
            ,  N'é¢œè‰²(Color)' AS [é¢œè‰²(Color)]  
            ,  N'å°ºç (Size)' AS [å°ºç (Size)]  
            ,  N'Material_Number' AS [Material_Number]  
            ,  N'äº§å“å¤§ç±»(SKUClass)' AS [äº§å“å¤§ç±»(SKUClass)]  
            ,  N'äº§å“æ¡ç (Product barcode)' AS [äº§å“æ¡ç (Product barcode)]  
            ,  N'å­£èŠ‚(Season Code)' AS [å­£èŠ‚(Season Code)]  
            ,  N'å‘è´§æ•°é‡(ShippedQty)' AS [å‘è´§æ•°é‡(ShippedQty)]  
            ,  N'å¤–ç®±æ¡ç (UCC)' AS [å¤–ç®±æ¡ç (UCC)]  
            ,  N'Consigneekey' AS [Consigneekey]  
            ,  N'æ¡ç ' AS [æ¡ç ]  
            ,  N'æ€»å•å·(Load)' AS [æ€»å•å·(Load)]) AS TEMP1    
  
      INSERT INTO [dbo].[EXG_FileDet](  
              file_key  
            , EXG_Hdr_ID  
            , [FileName]  
            , SheetName  
            , [Status]  
            , LineText1)  
         SELECT  @n_FileKey  
            , @n_EXG_Hdr_ID   
            , @c_FileName  
            , @c_SheetName  
            , 'W'  
            , CONCAT(  
                  '"',[å‘è´§å•å·(Shipment Number)], '"', @c_Delimiter,   
                  '"', [PTå·(PickShip Number)], '"', @c_Delimiter,   
                  '"', [è®¢å•å·(SO Number)], '"', @c_Delimiter,   
                  '"', [å‘è´§æ—¥æœŸ(Shipped Date)], '"', @c_Delimiter,   
                  '"', [é¢„è®¡åˆ°è´§æ—¥æœŸ(ETA)], '"', @c_Delimiter,   
                  '"', [å®¢æˆ·ç¼–å·(Sold to Code)], '"', @c_Delimiter,   
                  '"', [æ”¶è´§å•ä½(Ship to code)], '"', @c_Delimiter,   
                  '"', [å®¢æˆ·åç§°(CustomerName)], '"', @c_Delimiter,   
                  '"', [é€è´§åœ°å€(Ship to Address)], '"', @c_Delimiter,   
                  '"', [ç®±å·(CartonNo)], '"', @c_Delimiter,   
                  '"', [æ¬¾å·(Style)], '"', @c_Delimiter,   
                  '"', [é¢œè‰²(Color)]  , '"', @c_Delimiter,   
                  '"', [å°ºç (Size)]  , '"', @c_Delimiter,   
                  '"', [Material_Number]  , '"', @c_Delimiter,   
                  '"', [äº§å“å¤§ç±»(SKUClass)]  , '"', @c_Delimiter,   
                  '"', [äº§å“æ¡ç (Product barcode)]  , '"', @c_Delimiter,   
                  '"', [å­£èŠ‚(Season Code)]  , '"', @c_Delimiter,   
                  '"', [å‘è´§æ•°é‡(ShippedQty)]  , '"', @c_Delimiter,   
                  '"', [å¤–ç®±æ¡ç (UCC)]  , '"', @c_Delimiter,   
                  '"', [Consigneekey]  , '"', @c_Delimiter,   
                  '"', [æ¡ç ]   , '"', @c_Delimiter,     
                  '"', [æ€»å•å·(Load)]   , '"') AS LineText1    
         FROM (   
         Select   t1.Mbolkey as [å‘è´§å•å·(Shipment Number)]  
               ,  t1.ExternOrderkey as [PTå·(PickShip Number)]  
               ,  t1.BuyerPO as [è®¢å•å·(SO Number)]  
               ,  Convert(char(10),t1.Editdate,121) as [å‘è´§æ—¥æœŸ(Shipped Date)]  
               ,  Convert(char(10),DateAdd(Day,cast(t6.Short as int),t1.Editdate),121) as [é¢„è®¡åˆ°è´§æ—¥æœŸ(ETA)]  
               ,  t1.Billtokey as [å®¢æˆ·ç¼–å·(Sold to Code)]  
               ,  t1.Consigneekey as [æ”¶è´§å•ä½(Ship to code)]  
               ,  case when isnull(t7.Company,'')<>''   
                     then t7.Company   
                     else t1.C_Company   
                  end as [å®¢æˆ·åç§°(CustomerName)]  
               ,  case when isnull(ltrim(rtrim(t7.Address1)),'')+isnull(ltrim(rtrim(t7.Address2)),'')<>''   
                     then ltrim(rtrim(isnull(t7.Address1,'')))+ltrim(rtrim   (isnull(t7.Address2,'')))+ltrim(rtrim(isnull(t7.Address3,'')))   
                     else ltrim(rtrim(isnull(t1.C_Address1,'')))+ltrim(rtrim(isnull    (t1.C_Address2,'')))+ltrim(rtrim(isnull(t1.C_Address3,'')))   
                  end as [é€è´§åœ°å€(Ship to Address)]  
               ,  t3.CartonNo as [ç®±å·(CartonNo)]  
             ,  t4.Style as [æ¬¾å·(Style)]  
               ,  case when t1.stop='20'   
                     then ''   
                     else t4.Color   
                  end as [é¢œè‰²(Color)]    
               ,  case   
                     when t4.BUSR8='10' AND ISNULL(t4.measurement,'') <> '' then t4.measurement  
                   when t4.BUSR8='10' AND ISNULL(t4.measurement,'') = ''  then t4.size   
               when left(ltrim(rtrim(t4.size)),1)='0' and t4.size <> '00' then cast(cast(cast(t4.Size as int) as float)/10 as varchar(5))    
               when (t4.measurement ='' or t4.measurement = 'U') then t4.Size   
               else t4.measurement   
              end as [å°ºç (Size)]  
             ,  t8.Userdefine09 as Material_Number  
               ,  t1.stop as [äº§å“å¤§ç±»(SKUClass)]  
               ,  case   
                     when isnull(t3.UPC,'')<>'' and len(t3.UPC)<=17 and t3.UPC<>t3.SKU   
                        then t3.UPC    
                     when isnull(t4.ProductModel,'')='G' and len(t3.UPC)=20   
                        then ltrim(rtrim(t4.RetailSKU))+ ltrim(rtrim(isnull(t5.Userdefined03,'')))    
                     when isnull(t4.ProductModel,'')<>'G' and len(t3.UPC)=20 and isnull(t4.RetailSKU,'')<>''   
                        then t4.RetailSKU   
                     when isnull(t4.ProductModel,'')<>'G' and t3.UPC=t3.SKU and isnull(t4.RetailSKU,'')<>''   
                        then t4.RetailSKU   
                     when isnull(t4.ProductModel,'')<>'G' and len(t3.UPC)=20 and isnull(t4.MANUFACTURERSKU,'')<>''   
                        then t4.MANUFACTURERSKU   
                     when isnull(t4.ProductModel,'')<>'G' and t3.UPC=t3.SKU and isnull(t4.MANUFACTURERSKU,'')<>''   
                        then t4.MANUFACTURERSKU   
                        else ltrim(rtrim(t4.AltSKU))+left(ltrim(rtrim(t4.BUSR3)),2)+ (case right(ltrim(rtrim(t4.BUSR3)),1) when 'S' then '01' when 'R' then '02' when 'F' then '03' when 'H' then '04' end)    
                  end as [äº§å“æ¡ç (Product barcode)]  
               ,  case   
                     when isnull(t8.Userdefine06,'')<>'' and left(ltrim(rtrim(t8.Userdefine06)),1) not in('S','R','F','H')  
                        then left(ltrim(rtrim(t8.Userdefine06)),2)+ (case right(ltrim(rtrim(t8.Userdefine06)),1) when 'S' then '01' when 'R' then '02' when 'F' then '03' when 'H' then '04' end)    
                     when isnull(t8.Userdefine06,'')<>'' and left(ltrim(rtrim(t8.Userdefine06)),2) in('SP','SU','FA','HO')   
                        then right(ltrim(rtrim(t8.Userdefine06)),2)+ (case left(ltrim(rtrim(t8.Userdefine06)),2) when 'SP' then '01' when 'SU' then '02' when 'FA' then '03' when 'HO' then '04' end)    
                        else left(ltrim(rtrim(t4.BUSR3)),2)+ (case right(ltrim(rtrim(t4.BUSR3)),1) when 'S' then '01' when 'R' then '02' when 'F' then '03' when 'H' then '04' end)   
                  end as [å­£èŠ‚(Season Code)]  
               ,  SUM ( t2.Qty ) as [å‘è´§æ•°é‡(ShippedQty)]  
               ,  t3.LabelNo as [å¤–ç®±æ¡ç (UCC)]  
               ,  case   
                     when len(t1.consigneekey)=7   
                        then ltrim(rtrim(t1.Billtokey))+ltrim(rtrim(t1.Consigneekey))   
                        else t1.Consigneekey   
                     end as Consigneekey  
               ,  '*'+ t3.LabelNo +'*'  AS [æ¡ç ] -- add by ella 1/19  
               , t1.LoadKey AS [æ€»å•å·(Load)]
      From dbo.Orders as t1(nolock)   
      inner join dbo.Pickdetail as t2(nolock) on t1.Orderkey=t2.Orderkey and t2.status IN('9','5')     
      inner join dbo.PackDetail as t3(nolock) on t2.Dropid=substring(t3.Labelno,3,18) and t2.Storerkey = t3.Storerkey and   t2.SKU=t3.SKU     
         inner join (select Distinct storerkey,Orderkey,SKU, userdefine06,Userdefine09   
                  from dbo.Orderdetail(nolock)   
                     where Storerkey=@c_ParamVal1) as t8 on t2.Orderkey=t8.Orderkey and t3.SKU=t8.SKU    
      inner join dbo.SKU as t4(nolock) on t3.Storerkey=t4.Storerkey and t3.SKU=t4.SKU   
      left  join dbo.UCC as t5(nolock) on t3.Storerkey=t5.Storerkey and t3.SKU=t5.SKU and t3.UPC=t5.UCCNo   
      left  join dbo.Storer as t7(nolock) on ltrim(rtrim(t1.Billtokey))+ltrim(rtrim(t1.Consigneekey))=t7.Storerkey   
      --left  join dbo.Codelkup as t6(nolock) on t6.ListName='CityLdTime' and cast(t6.Notes as varchar(20))='Converse' and (case when len(t1.Consigneekey)=10 and t1.Consigneekey=t6.code then 1 when len(t1.Consigneekey)=7 and ltrim(rtrim(t1.Billtokey))+ltrim(rtrim(t1.Consigneekey))=t6.Code then 1 else 0 end)=1   
      left  join dbo.Codelkup as t6(nolock) on t6.ListName='CityLdTime' and cast(t6.Notes as varchar(20))=@c_ParamVal1 and t1.Consigneekey = t6.code   
         Where t1.Mbolkey = @c_ParamVal2 and t1.Consigneekey = @c_ParamVal3 and t1.Status in('5','9')    
         Group by t1.Mbolkey  
               ,  t1.ExternOrderkey   
               ,  t1.BuyerPO  
               ,  Convert(char(10),t1.Editdate,121)   
               ,  t1.Billtokey   
               ,  t1.Consigneekey  
               ,  case   
                     when isnull(t7.Company,'')<>''   
                        then t7.Company   
                        else t1.C_Company   
                  end   
               ,  case   
                     when isnull(ltrim(rtrim(t7.Address1)),'')+isnull(ltrim(rtrim(t7.Address2)),'')<>''   
                        then ltrim(rtrim(isnull(t7.Address1,'')))+ltrim(rtrim(isnull(t7.Address2,'')))+ltrim(rtrim(isnull(t7.Address3,'')))   
                        else ltrim(rtrim(isnull(t1.C_Address1,'')))+ltrim(rtrim(isnull(t1.C_Address2,'')))+ltrim(rtrim(isnull(t1.C_Address3,'')))   
                  end  
               ,  t3.CartonNo  
               ,  t4.Style  
               ,  case   
                     when t1.stop='20'   
                        then ''   
                        else t4.Color   
                  end  
               ,  case   
                     when t4.BUSR8='10' AND ISNULL(t4.measurement,'') <> '' then t4.measurement  
                   when t4.BUSR8='10' AND ISNULL(t4.measurement,'') = ''  then t4.size   
               when left(ltrim(rtrim(t4.size)),1)='0' and t4.size <> '00' then cast(cast(cast(t4.Size as int) as float)/10 as varchar(5))    
               when (t4.measurement ='' or t4.measurement = 'U') then t4.Size   
               else t4.measurement   
              end   
               ,  t4.Measurement  
               ,  case   
                     when isnull(t3.UPC,'')<>'' and len(t3.UPC)<=17 and t3.UPC<>t3.SKU   
                        then t3.UPC    
                     when isnull(t4.ProductModel,'')='G' and len(t3.UPC)=20   
                        then ltrim(rtrim(t4.RetailSKU))+ ltrim(rtrim(isnull(t5.Userdefined03,'')))    
                     when isnull(t4.ProductModel,'')<>'G' and len(t3.UPC)=20 and isnull(t4.RetailSKU,'')<>''   
                        then t4.RetailSKU   
                     when isnull(t4.ProductModel,'')<>'G' and t3.UPC=t3.SKU and isnull(t4.RetailSKU,'')<>''   
                        then t4.RetailSKU   
                     when isnull(t4.ProductModel,'')<>'G' and len(t3.UPC)=20 and isnull(t4.MANUFACTURERSKU,'')<>''   
                        then t4.MANUFACTURERSKU   
                     when isnull(t4.ProductModel,'')<>'G' and t3.UPC=t3.SKU and isnull(t4.MANUFACTURERSKU,'')<>''   
                        then t4.MANUFACTURERSKU   
                        else ltrim(rtrim(t4.AltSKU))+left(ltrim(rtrim(t4.BUSR3)),2)+ (case right(ltrim(rtrim(t4.BUSR3)),1) when 'S' then '01' when 'R' then '02' when 'F' then '03' when 'H' then '04' end)    
                  end  
               ,  case   
                     WHEN isnull(t8.Userdefine06,'')<>'' and left(ltrim(rtrim(t8.Userdefine06)),1) not in('S','R','F','H')    
                        then left(ltrim(rtrim(t8.Userdefine06)),2)+ (case right(ltrim(rtrim(t8.Userdefine06)),1) when 'S' then '01' when 'R' then '02' when 'F' then '03' when 'H' then '04' end)    
                     when isnull(t8.Userdefine06,'')<>'' and left(ltrim(rtrim(t8.Userdefine06)),2) in('SP','SU','FA','HO')   
                        then right(ltrim(rtrim(t8.Userdefine06)),2)+ (case left(ltrim(rtrim(t8.Userdefine06)),2) when 'SP' then '01' when 'SU' then '02' when 'FA' then '03' when 'HO' then '04' end)    
                        else left(ltrim(rtrim(t4.BUSR3)),2)+ (case right(ltrim(rtrim(t4.BUSR3)),1) when 'S' then '01' when 'R' then '02' when 'F' then '03' when 'H' then '04' end)  
                  end   
               ,  t3.LabelNo   
               ,  case   
                     when len(t1.consigneekey)=7   
                        then ltrim(rtrim(t1.Billtokey))+ltrim(rtrim(t1.Consigneekey))   
                       else t1.Consigneekey   
                  end  
               ,  Convert(char(10),DateAdd(Day,cast(t6.Short as int),t1.Editdate),121)  
               ,  t1.stop  
               ,  t8.userdefine09   
               ,  t1.loadkey     
         Order by t1.ExternOrderkey  
               ,  t3.CartonNo  
               ,  t4.Style  
               ,  case   
                     when t1.stop='20'   
                        then ''   
                        else t4.Color   
                  end  
               ,  case   
                     when t4.BUSR8='10' AND ISNULL(t4.measurement,'') <> '' then t4.measurement  
                   when t4.BUSR8='10' AND ISNULL(t4.measurement,'') = ''  then t4.size   
               when left(ltrim(rtrim(t4.size)),1)='0' and t4.size <> '00' then cast(cast(cast(t4.Size as int) as float)/10 as varchar(5))    
               when (t4.measurement ='' or t4.measurement = 'U') then t4.Size   
               else t4.measurement   
              end    
               OFFSET 0 ROWS) AS TEMP2  
      END  
      ELSE IF @n_EXG_Hdr_ID = 3  
      BEGIN  
         INSERT INTO [dbo].[EXG_FileDet](  
              file_key  
            , EXG_Hdr_ID  
            , [FileName]  
            , SheetName  
            , [Status]  
            , LineText1)  
         SELECT  @n_FileKey  
            , @n_EXG_Hdr_ID   
            , @c_FileName  
            , @c_SheetName  
            , 'W'  
            , CONCAT(  
                  '"', [å‘è´§å•å·(Shipment Number)], '"', @c_Delimiter,   
                  '"', [PTå·(PickShip Number)], '"', @c_Delimiter,   
                  --'"', [è®¢å•å·(SO Number)], '"', @c_Delimiter,   
                  '"', [å‘è´§æ—¥æœŸ(Shipped Date)], '"', @c_Delimiter,   
                  '"', [é¢„è®¡åˆ°è´§æ—¥æœŸ(ETA)], '"', @c_Delimiter,   
                  --'"', [å®¢æˆ·ç¼–å·(Sold to Code)], '"', @c_Delimiter,   
                  '"', [æ”¶è´§å•ä½(Ship to code)], '"', @c_Delimiter,   
                  '"', [å®¢æˆ·åç§°(CustomerName)], '"', @c_Delimiter,   
                  '"', [é€è´§åœ°å€(Ship to Address)], '"', @c_Delimiter,   
                  '"', [ç®±å·(CartonNo)], '"', @c_Delimiter,   
                  '"', [æ¬¾å·(Style)], '"', @c_Delimiter,   
                  '"', [é¢œè‰²(Color)], '"', @c_Delimiter,   
                  '"', [å°ºç (Size)], '"', @c_Delimiter,   
                  '"', [Material_Number], '"', @c_Delimiter,   
                  '"', [äº§å“å¤§ç±»(SKUClass)], '"', @c_Delimiter,   
                  '"', [äº§å“æ¡ç (Product barcode)], '"', @c_Delimiter,   
                  --'"', [å­£èŠ‚(Season Code)], '"', @c_Delimiter,   
                  '"', [å‘è´§æ•°é‡(ShippedQty)], '"', @c_Delimiter,   
                  '"', [å¤–ç®±æ¡ç (UCC)], '"', @c_Delimiter,   
                  '"', [Consigneekey], '"', @c_Delimiter,   
                  '"', [æ¡ç ], '"') AS LineText1  
         FROM (  
            SELECT  
               N'å‘è´§å•å·(Shipment Number)' AS [å‘è´§å•å·(Shipment Number)]  
            ,  N'PTå·(PickShip Number)' AS [PTå·(PickShip Number)]  
            --,  N'è®¢å•å·(SO Number)' AS [è®¢å•å·(SO Number)]  
            ,  N'å‘è´§æ—¥æœŸ(Shipped Date)' AS [å‘è´§æ—¥æœŸ(Shipped Date)]  
            ,  N'é¢„è®¡åˆ°è´§æ—¥æœŸ(ETA)' AS [é¢„è®¡åˆ°è´§æ—¥æœŸ(ETA)]  
            --,  N'å®¢æˆ·ç¼–å·(Sold to Code)' AS [å®¢æˆ·ç¼–å·(Sold to Code)]  
            ,  N'æ”¶è´§å•ä½(Ship to code)' AS [æ”¶è´§å•ä½(Ship to code)]  
            ,  N'å®¢æˆ·åç§°(CustomerName)' AS [å®¢æˆ·åç§°(CustomerName)]  
            ,  N'é€è´§åœ°å€(Ship to Address)' AS [é€è´§åœ°å€(Ship to Address)]  
            ,  N'ç®±å·(CartonNo)' AS [ç®±å·(CartonNo)]  
            ,  N'æ¬¾å·(Style)' AS [æ¬¾å·(Style)]  
            ,  N'é¢œè‰²(Color)' AS [é¢œè‰²(Color)]  
            ,  N'å°ºç (Size)' AS [å°ºç (Size)]  
            ,  N'Material_Number' AS [Material_Number]  
            ,  N'äº§å“å¤§ç±»(SKUClass)' AS [äº§å“å¤§ç±»(SKUClass)]  
            ,  N'äº§å“æ¡ç (Product barcode)' AS [äº§å“æ¡ç (Product barcode)]  
            --,  N'å­£èŠ‚(Season Code)' AS [å­£èŠ‚(Season Code)]  
            ,  N'å‘è´§æ•°é‡(ShippedQty)' AS [å‘è´§æ•°é‡(ShippedQty)]  
            ,  N'å¤–ç®±æ¡ç (UCC)' AS [å¤–ç®±æ¡ç (UCC)]  
            ,  N'Consigneekey' AS [Consigneekey]  
            ,  N'æ¡ç ' AS [æ¡ç ]) AS TEMP1  
  
         INSERT INTO [dbo].[EXG_FileDet](  
           file_key  
            , EXG_Hdr_ID  
            , [FileName]  
            , SheetName  
            , [Status]  
            , LineText1)  
         SELECT  @n_FileKey  
            , @n_EXG_Hdr_ID   
            , @c_FileName  
            , @c_SheetName  
            , 'W'  
            , CONCAT(  
                  '"',[å‘è´§å•å·(Shipment Number)], '"', @c_Delimiter,   
                  '"', [PTå·(PickShip Number)], '"', @c_Delimiter,   
                  --'"', [è®¢å•å·(SO Number)], '"', @c_Delimiter,   
                  '"', [å‘è´§æ—¥æœŸ(Shipped Date)], '"', @c_Delimiter,   
                  '"', [é¢„è®¡åˆ°è´§æ—¥æœŸ(ETA)], '"', @c_Delimiter,   
                  --'"', [å®¢æˆ·ç¼–å·(Sold to Code)], '"', @c_Delimiter,   
                  '"', [æ”¶è´§å•ä½(Ship to code)], '"', @c_Delimiter,   
                  '"', [å®¢æˆ·åç§°(CustomerName)], '"', @c_Delimiter,   
                  '"', [é€è´§åœ°å€(Ship to Address)], '"', @c_Delimiter,   
                  '"', [ç®±å·(CartonNo)], '"', @c_Delimiter,   
                  '"', [æ¬¾å·(Style)], '"', @c_Delimiter,   
                  '"', [é¢œè‰²(Color)]  , '"', @c_Delimiter,   
                  '"', [å°ºç (Size)]  , '"', @c_Delimiter,   
                  '"', [Material_Number]  , '"', @c_Delimiter,   
                  '"', [äº§å“å¤§ç±»(SKUClass)]  , '"', @c_Delimiter,   
                  '"', [äº§å“æ¡ç (Product barcode)]  , '"', @c_Delimiter,   
                  --'"', [å­£èŠ‚(Season Code)]  , '"', @c_Delimiter,   
                  '"', [å‘è´§æ•°é‡(ShippedQty)]  , '"', @c_Delimiter,   
                  '"', [å¤–ç®±æ¡ç (UCC)]  , '"', @c_Delimiter,   
                  '"', [Consigneekey]  , '"', @c_Delimiter,   
                  '"', [æ¡ç ]   , '"') AS LineText1  
         FROM (   
            Select   t1. Mbolkey as [å‘è´§å•å·(Shipment Number)]  
                   , t1.ExternOrderkey as [PTå·(PickShip Number)]  
                   , Convert(char(10),t1.Editdate,121) as [å‘è´§æ—¥æœŸ(Shipped Date)]  
                   , Convert(char(10),DateAdd(Day,cast(t6.Short as int),t1.Editdate),121) as [é¢„è®¡åˆ°è´§æ—¥æœŸ(ETA)]  
                   , t1.Consigneekey as [æ”¶è´§å•ä½(Ship to code)]  
                   , case   
                        when isnull(t7.Company,'')<>''   
                           then t7.Company   
                        else t1.C_Company   
                     end as [å®¢æˆ·åç§°(CustomerName)]  
                   , case   
                        when isnull(ltrim(rtrim(t7.Address1)),'')+isnull(ltrim(rtrim(t7.Address2)),'')<>''   
                           then ltrim(rtrim(isnull(t7.Address1,'')))+ltrim(rtrim(isnull(t7.Address2,'')))+ltrim(rtrim(isnull(t7.Address3,'')))   
                        else ltrim(rtrim(isnull(t1.C_Address1,'')))+ltrim(rtrim(isnull(t1.C_Address2,'')))+ltrim(rtrim(isnull(t1.C_Address3,'')))   
                     end as [é€è´§åœ°å€(Ship to Address)]  
                   , t3.CartonNo as [ç®±å·(CartonNo)]  
                   , t4.Style as [æ¬¾å·(Style)]  
                   , case   
                        when t1.stop='20'   
                           then ''   
                        else t4.Color   
                     end as [é¢œè‰²(Color)]  
                   , case   
                        when t4.BUSR8='10' AND ISNULL(t4.measurement,'') <>''   
                           then t4.measurement  
                    when t4.BUSR8='10' AND ISNULL(t4.measurement,'') =''   
                           then t4.size  
                    when left(ltrim(rtrim(t4.size)),1)='0' and t4.size <> '00'   
                           then cast(cast(cast(t4.Size as int) as float)/10 as varchar(5))    
                    when (t4.measurement ='' or t4.measurement = 'U')   
                           then t4.Size   
                        else t4.measurement   
                     end as [å°ºç (Size)]  
                   , t4.SUSR5 AS Material_Number  
                   , t1.stop as [äº§å“å¤§ç±»(SKUClass)]  
                   , t4.MANUFACTURERSKU AS [äº§å“æ¡ç (Product barcode)]  
                   , SUM ( t3.Qty ) as [å‘è´§æ•°é‡(ShippedQty)]  
                   , t3.LabelNo as [å¤–ç®±æ¡ç (UCC)]  
                   , case   
 when len(t1.consigneekey)=7   
                           then ltrim(rtrim(t1.Billtokey))+ltrim(rtrim(t1.Consigneekey))   
                        else t1.Consigneekey   
                     end as Consigneekey  
                   , '*'+ t3.LabelNo +'*'  AS [æ¡ç ]       
            From  dbo.Orders as t1(nolock)   
            inner join dbo.PackHeader as t2(nolock) on t1.Orderkey=t2.Orderkey and t2.status='9'   
            inner join dbo.PackDetail as t3(nolock) on t2.Pickslipno=t3.Pickslipno   
            inner join dbo.SKU as t4(nolock) on t3.Storerkey=t4.Storerkey and t3.SKU=t4.SKU   
            left  join dbo.UCC as t5(nolock) on t3.Storerkey=t5.Storerkey and t3.SKU=t5.SKU and t3.UPC=t5.UCCNo   
            left  join dbo.Storer as t7(nolock) on ltrim(rtrim(t1.Billtokey))+ltrim(rtrim(t1.Consigneekey))=t7.Storerkey   
            left  join dbo.Codelkup as t6(nolock) on t6.ListName='CityLdTime' and cast(t6.Notes as varchar(20))='Converse' and t1.Consigneekey = t6.code   
            Where t1.Mbolkey=@c_ParamVal2 and t1.Consigneekey = @c_ParamVal3 and t1.Status in('5','9')    
            Group by t1. Mbolkey  
                   , t1.ExternOrderkey   
                   , Convert(char(10),t1.Editdate,121)   
                   , t1.Consigneekey  
                   , case   
                        when isnull(t7.Company,'')<>''   
                           then t7.Company   
                        else t1.C_Company   
                     end   
                   , case   
                        when isnull(ltrim(rtrim(t7.Address1)),'')+isnull(ltrim(rtrim(t7.Address2)),'')<>''   
                           then ltrim(rtrim(isnull(t7.Address1,'')))+ltrim(rtrim(isnull(t7.Address2,'')))+ltrim(rtrim(isnull(t7.Address3,'')))   
                        else ltrim(rtrim(isnull(t1.C_Address1,'')))+ltrim(rtrim(isnull(t1.C_Address2,'')))+ltrim(rtrim(isnull(t1.C_Address3,'')))   
                     end  
                   , t3.CartonNo  
                   , t4.Style  
                   , case   
                        when t1.stop='20'   
                           then ''   
                        else t4.Color   
                     end  
                   , t4.BUSR8  
                   , t4.Size   
                   , t4.Measurement  
                   , t4.MANUFACTURERSKU  
                   , t3.LabelNo   
                   , case   
                        when len(t1.consigneekey)=7   
                           then ltrim(rtrim(t1.Billtokey))+ltrim(rtrim(t1.Consigneekey))   
                        else t1.Consigneekey   
                     end  
                   , Convert(char(10),DateAdd(Day,cast(t6.Short as int),t1.Editdate),121)  
                   , t1.stop  
                   , t4.SUSR5   
            Order by t1.ExternOrderkey  
                   , t3.CartonNo  
                   , t4.Style  
                   , case   
                        when t1.stop='20'   
                           then ''   
                        else t4.Color   
                     end  
                   , t4.Size  
         OFFSET 0 ROWS) AS TEMP2  
      END  
   END TRY  
   BEGIN CATCH  
      SET @n_Err = ERROR_NUMBER();  
      SET @c_ErrMsg = ERROR_MESSAGE() + ' (isp_EXG_CNWMSNKE_CONVERSE_PackList)'  
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
         PRINT '[dbo].[isp_EXG_CNWMSNKE_CONVERSE_PackList]: @c_ErrMsg=' + RTRIM(@c_ErrMsg)  
         PRINT '[dbo].[isp_EXG_CNWMSNKE_CONVERSE_PackList]: @b_Success=' + RTRIM(CAST(@b_Success AS NVARCHAR(10)))  
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
         PRINT '[dbo].[isp_EXG_CNWMSNKE_CONVERSE_PackList]: @c_ErrMsg=' + RTRIM(@c_ErrMsg)  
         PRINT '[dbo].[isp_EXG_CNWMSNKE_CONVERSE_PackList]: @b_Success=' + RTRIM(CAST(@b_Success AS NVARCHAR(10)))  
      END        
      RETURN        
   END          
   /***********************************************/        
   /* Std - Error Handling (End)                  */        
   /***********************************************/  
END --End Procedure

GO