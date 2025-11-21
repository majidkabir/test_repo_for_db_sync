SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
/************************************************************************/
/* Stored Proc: isp_UCC_Carton_Label_64_rdt                             */
/* Creation Date: 07-SEP-2017                                           */
/* Copyright: LF Logistics                                              */
/* Written by: Wan                                                      */
/*                                                                      */
/* Purpose: WMS-2375 - GBG bebe Carton Label Enhancement                */
/*        :                                                             */
/* Called By: r_dw_ucc_carton_label_64_rdt                              */
/*          :                                                           */
/* PVCS Version: 1.0                                                    */
/*                                                                      */
/* Version: 7.0                                                         */
/*                                                                      */
/* Data Modifications:                                                  */
/*                                                                      */
/* Updates:                                                             */
/* Date        Author   Ver   Purposes                                  */
/* 14-JUN-2018 CSCHONG  1.1   WMS-5403 - add new field (CS01)           */
/* 28-Jan-2019  TLTING_ext 1.2  enlarge externorderkey field length      */
/************************************************************************/
CREATE PROC [dbo].[isp_UCC_Carton_Label_64_rdt]
            @c_PickSlipNo     NVARCHAR(10) 
         ,  @c_CartonNoStart  NVARCHAR(10)     
         ,  @c_CartonNoEnd    NVARCHAR(10)  
AS
BEGIN
   SET NOCOUNT ON
   SET ANSI_NULLS OFF
   SET QUOTED_IDENTIFIER OFF
   SET CONCAT_NULL_YIELDS_NULL OFF

   DECLARE  
           @n_StartTCnt       INT
         , @n_Continue        INT 

         , @n_TTLCnts         INT
         , @c_ST_Susr3        NVARCHAR(20)
         , @c_ST_B_Company    NVARCHAR(45) 
         , @c_Loadkey         NVARCHAR(10)
         , @c_MBOLKey         NVARCHAR(10)
         , @c_ExternMBOLKey   NVARCHAR(30)
         , @c_Orderkey        NVARCHAR(10)
         , @c_ExternOrderKey  NVARCHAR(50)  --tlting_ext

         , @c_OrderInfo01     NVARCHAR(30)        
         , @c_OrderInfo02     NVARCHAR(30)        
         , @c_OrderInfo03     NVARCHAR(30)        
         , @c_OrderInfo04     NVARCHAR(30)        
         , @c_OrderInfo05     NVARCHAR(30)        
         , @c_OrderInfo06     NVARCHAR(30)        
         , @c_OrderInfo07     NVARCHAR(30)  
         , @c_Notes           NVARCHAR(125)       
         , @c_To_Company      NVARCHAR(45)   
         , @c_To_Address1     NVARCHAR(45)   
         , @c_To_Address2     NVARCHAR(45)   
         , @c_To_Address3     NVARCHAR(45)   
         , @c_To_City         NVARCHAR(45)   
         , @c_To_State        NVARCHAR(45)   
         , @c_To_Zip          NVARCHAR(18)   
         , @c_To_Country      NVARCHAR(30)   
         , @c_MarkForkey      NVARCHAR(15)   
         , @c_UserDefine04    NVARCHAR(20)   
         , @c_UserDefine09    NVARCHAR(10) 
         , @c_Salesman        NVARCHAR(30)   
         , @c_C_Zip           NVARCHAR(18) 
         

   CREATE TABLE #TMP_OD 
   (  Storerkey NVARCHAR(15)  NOT NULL DEFAULT('')
   ,  Sku       NVARCHAR(20)  NOT NULL DEFAULT('')
   ,  AltSku    NVARCHAR(20)  NOT NULL DEFAULT('')
   ) 

   SET @n_StartTCnt = @@TRANCOUNT
   SET @n_Continue = 1

   SET @c_ST_Susr3 = ''
   --SELECT @c_ST_Susr3 = ISNULL(RTRIM(ST.Susr3),'')
   --FROM STORER ST WITH (NOLOCK)
   --WHERE ST.Storerkey = '11380'

   SET @n_TTLCnts = 0
   SET @c_Orderkey = ''
   SET @c_Loadkey = ''
   SELECT @c_Orderkey= ISNULL(RTRIM(PH.Orderkey),'')
       ,  @c_Loadkey = ISNULL(RTRIM(PH.Loadkey),'')
       ,  @n_TTLCnts = ISNULL(PH.TTLCnts,0)
   FROM PACKHEADER PH WITH (NOLOCK)
   WHERE PickSlipNo = @c_PickSlipNo

   IF @c_Orderkey <> ''
   BEGIN
      SELECT TOP 1
            --@c_ST_B_Company= ISNULL(RTRIM(ST.B_Company),'')         --(CS01)
            @c_ST_B_Company = ISNULL(c.[Description],'')              --(CS01)
         ,  @c_OrderInfo01 = ISNULL(RTRIM(OI.OrderInfo01),'') 
         ,  @c_OrderInfo02 = ISNULL(RTRIM(OI.OrderInfo02),'') 
         ,  @c_OrderInfo03 = ISNULL(RTRIM(OI.OrderInfo03),'') 
         ,  @c_OrderInfo04 = ISNULL(RTRIM(OI.OrderInfo04),'') 
         ,  @c_OrderInfo05 = ISNULL(RTRIM(OI.OrderInfo05),'') 
         ,  @c_OrderInfo06 = ISNULL(RTRIM(OI.OrderInfo06),'') 
         ,  @c_OrderInfo07 = ISNULL(RTRIM(OI.OrderInfo07),'') 
         ,  @c_Notes       = ISNULL(RTRIM(OI.Notes),'')
         ,  @c_To_Company  = ISNULL(RTRIM(OH.C_Company),'')   
         ,  @c_To_Address1 = ISNULL(RTRIM(OH.C_Address1),'')  
         ,  @c_To_Address2 = ISNULL(RTRIM(OH.C_Address2),'')  
         ,  @c_To_Address3 = ISNULL(RTRIM(OH.C_Address3),'')  
         ,  @c_To_City     = ISNULL(RTRIM(OH.C_City),'')      
         ,  @c_To_State    = ISNULL(RTRIM(OH.C_State),'')     
         ,  @c_To_Zip      = ISNULL(RTRIM(OH.C_Zip),'') 
         ,  @c_To_Country  = ISNULL(RTRIM(OH.C_Country),'')    
         ,  @c_C_Zip       = ISNULL(RTRIM(OH.C_Zip),'')  
         ,  @c_MarkForkey  = ISNULL(RTRIM(OH.MarkForkey),'')  
         ,  @c_UserDefine04= ISNULL(RTRIM(OH.UserDefine04),'')
         ,  @c_UserDefine09= ISNULL(RTRIM(OH.UserDefine09),'')
         ,  @c_Salesman    = ISNULL(RTRIM(OH.Salesman),'')
         ,  @c_Orderkey    = OH.Orderkey
         ,  @c_Loadkey     = ISNULL(RTRIM(OH.Loadkey),'')     
         ,  @c_MBOLKey     = ISNULL(RTRIM(OH.MBOLKey),'')  
         ,  @c_ExternOrderKey = ISNULL(RTRIM(OH.ExternOrderKey),'')   
      FROM ORDERS     OH WITH (NOLOCK)
      JOIN STORER     ST WITH (NOLOCK) ON (OH.Storerkey = ST.Storerkey)
      JOIN ORDERINFO  OI WITH (NOLOCK) ON (OH.Orderkey = OI.Orderkey)
      LEFT JOIN CODELKUP C WITH (NOLOCK) ON C.listname = 'GBG_DIV' 
                    AND c.code = OH.UserDefine01 AND C.storerkey = OH.storerkey         --(CS01)
      WHERE OH.Orderkey = @c_Orderkey 

      INSERT INTO #TMP_OD
         (  Storerkey   
         ,  Sku
         ,  AltSku
         )
      SELECT OD.Storerkey   
         ,  OD.Sku
         ,  AltSku = ISNULL(MAX(RTRIM(OD.UserDefine03)),'')
      FROM ORDERDETAIL OD WITH (NOLOCK) 
      WHERE OD.Orderkey = @c_Orderkey 
      GROUP BY OD.Storerkey   
            ,  OD.Sku
   END
   ELSE
   BEGIN
      SELECT TOP 1
           --@c_ST_B_Company= ISNULL(RTRIM(ST.B_Company),'')         --(CS01)
            @c_ST_B_Company = ISNULL(c.[Description],'')              --(CS01)
         ,  @c_OrderInfo01 = ISNULL(RTRIM(OI.OrderInfo01),'') 
         ,  @c_OrderInfo02 = ISNULL(RTRIM(OI.OrderInfo02),'') 
         ,  @c_OrderInfo03 = ISNULL(RTRIM(OI.OrderInfo03),'') 
         ,  @c_OrderInfo04 = ISNULL(RTRIM(OI.OrderInfo04),'') 
         ,  @c_OrderInfo05 = ISNULL(RTRIM(OI.OrderInfo05),'') 
         ,  @c_OrderInfo06 = ISNULL(RTRIM(OI.OrderInfo06),'') 
         ,  @c_OrderInfo07 = ISNULL(RTRIM(OI.OrderInfo07),'') 
         ,  @c_Notes       = ISNULL(RTRIM(OI.Notes),'')
         ,  @c_To_Company  = ISNULL(RTRIM(OH.C_Company),'')   
         ,  @c_To_Address1 = ISNULL(RTRIM(OH.C_Address1),'')  
         ,  @c_To_Address2 = ISNULL(RTRIM(OH.C_Address2),'')  
         ,  @c_To_Address3 = ISNULL(RTRIM(OH.C_Address3),'')  
         ,  @c_To_City     = ISNULL(RTRIM(OH.C_City),'')      
         ,  @c_To_State    = ISNULL(RTRIM(OH.C_State),'')     
         ,  @c_To_Zip      = ISNULL(RTRIM(OH.C_Zip),'') 
         ,  @c_To_Country  = ISNULL(RTRIM(OH.C_Country),'')  
         ,  @c_C_Zip       = ISNULL(RTRIM(OH.C_Zip),'')   
         ,  @c_MarkForkey  = ISNULL(RTRIM(OH.MarkForkey),'')  
         ,  @c_UserDefine04= ISNULL(RTRIM(OH.UserDefine04),'')
         ,  @c_UserDefine09= ISNULL(RTRIM(OH.UserDefine09),'')
         ,  @c_Salesman    = ISNULL(RTRIM(OH.Salesman),'')
         ,  @c_Orderkey    = OH.Orderkey
         ,  @c_Loadkey     = ISNULL(RTRIM(OH.Loadkey),'')     
         ,  @c_MBOLKey     = ISNULL(RTRIM(OH.MBOLKey),'') 
         ,  @c_ExternOrderKey = ISNULL(RTRIM(OH.ExternOrderKey),'')       
      FROM ORDERS     OH WITH (NOLOCK)
      JOIN STORER     ST WITH (NOLOCK) ON (OH.Storerkey = ST.Storerkey)
      JOIN ORDERINFO  OI WITH (NOLOCK) ON (OH.Orderkey = OI.Orderkey)
      LEFT JOIN CODELKUP C WITH (NOLOCK) ON C.listname = 'GBG_DIV' 
                       AND c.code = OH.UserDefine01 AND C.storerkey = OH.storerkey          --(CS01)
      WHERE OH.Loadkey = @c_Loadkey

      INSERT INTO #TMP_OD
         (  Storerkey   
         ,  Sku
         ,  AltSku
         )
      SELECT OD.Storerkey   
         ,  OD.Sku
         ,  AltSku = ISNULL(MAX(RTRIM(OD.UserDefine03)),'')
      FROM ORDERDETAIL OD WITH (NOLOCK) 
      WHERE OD.Loadkey = @c_Loadkey 
      GROUP BY OD.Storerkey   
            ,  OD.Sku
   END

   SET @c_ExternMBOLKey = ''      
   SELECT @c_ExternMBOLKey = ISNULL(RTRIM(ExternMBOLKey),'')
   FROM MBOL MB WITH (NOLOCK)
   WHERE MB.MBOLKey = @c_MBOLKey    

QUIT_SP:
   SELECT 
         FromCO      = ISNULL(RTRIM(@c_ST_B_Company),'')
      ,  OrderInfo01 = ISNULL(RTRIM(@c_OrderInfo01),'')  
      ,  OrderInfo02 = ISNULL(RTRIM(@c_OrderInfo02),'')  
      ,  OrderInfo03 = ISNULL(RTRIM(@c_OrderInfo03),'')  
      ,  OrderInfo04 = ISNULL(RTRIM(@c_OrderInfo04),'')  
      ,  OrderInfo05 = ISNULL(RTRIM(@c_OrderInfo05),'')  
      ,  OrderInfo06 = ISNULL(RTRIM(@c_OrderInfo06),'') 
      ,  OrderInfo07 = ISNULL(RTRIM(@c_OrderInfo07),'')  
      ,  Notes       = ISNULL(RTRIM(@c_Notes),'')
      ,  To_Company  = ISNULL(RTRIM(@c_To_Company),'')    
      ,  To_Address1 = ISNULL(RTRIM(@c_To_Address1),'')   
      ,  To_Address2 = ISNULL(RTRIM(@c_To_Address2),'')   
      ,  To_Address3 = ISNULL(RTRIM(@c_To_Address3),'')   
      ,  To_City     = ISNULL(RTRIM(@c_To_City),'')       
      ,  To_State    = ISNULL(RTRIM(@c_To_State),'')      
      ,  To_Zip      = ISNULL(RTRIM(@c_To_Zip),'')        
      ,  To_Country  = ISNULL(RTRIM(@c_To_Country),'')  
      ,  C_Zip       = ISNULL(RTRIM(@c_C_Zip),'')     
      ,  MarkForkey  = ISNULL(RTRIM(@c_MarkForkey),'')   
      ,  UserDefine04= ISNULL(RTRIM(@c_UserDefine04),'') 
      ,  Dept        = ''
      ,  Loadkey     = @c_Loadkey     
      ,  ExternOrderKey = @c_ExternOrderKey
      ,  ExternMBOLKey  = @c_ExternMBOLKey 
      ,  TTLCtns        = @n_TTLCnts    
      ,  PD.CartonNo    
      ,  PD.LabelNo    
      ,  UPC   = CASE WHEN COUNT(DISTINCT PD.SKU) > 1 THEN 'MIXED' ELSE MIN(PD.Sku) END
      ,  Sku   = CASE WHEN COUNT(DISTINCT PD.SKU) > 1 THEN 'MIXED' ELSE MIN(CASE WHEN OD.AltSku <> '' THEN OD.AltSku ELSE ISNULL(RTRIM(SKU.AltSku),'') END) END
      ,  Size  = CASE WHEN COUNT(DISTINCT PD.SKU) > 1 THEN 'MIXED' ELSE ISNULL(MIN(SKU.Size),'')  END
      ,  BUSR1 = CASE WHEN COUNT(DISTINCT PD.SKU) > 1 THEN 'MIXED' ELSE ISNULL(MIN(SKU.BUSR1),'') END
      ,  Qty   = ISNULL(SUM(PD.Qty),0)
   FROM PACKDETAIL PD  WITH (NOLOCK)
   JOIN SKU        SKU WITH (NOLOCK) ON (PD.Storerkey = SKU.Storerkey) 
                                     AND(PD.Sku = SKU.Sku)
   JOIN #TMP_OD    OD  WITH (NOLOCK) ON (PD.Storerkey = OD.Storerkey) 
                                     AND(PD.Sku = OD.Sku)
   WHERE PD.PickSlipNo = @c_PickSlipNo
   AND   PD.CartonNo BETWEEN CONVERT(INT, @c_CartonNoStart) AND  CONVERT(INT, @c_CartonNoEnd)
   GROUP BY PD.CartonNo
         ,  PD.LabelNo


END -- procedure

GO