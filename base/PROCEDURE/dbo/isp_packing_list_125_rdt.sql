SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/************************************************************************/
/* Stored Procedure: isp_Packing_List_125_rdt                           */
/* Creation Date: 2022-06-16                                            */
/* Copyright: LFL                                                       */
/* Written by: Mingle                                                   */
/*                                                                      */
/* Purpose: WMS-19893 CN-MHD PACKING LIST                               */
/*                                                                      */
/* Called By: r_dw_Packing_List_125_rdt                                 */
/*                                                                      */
/* GitLab Version: 1.2                                                  */
/*                                                                      */
/* Version: 5.4                                                         */
/*                                                                      */
/* Data Modifications:                                                  */
/*                                                                      */
/* Updates:                                                             */
/* Date         Author  Ver   Purposes                                  */
/* 05-SEP-2022  MIGNLE  1.0   WMS-20684 add storer.b_contact(ML01)      */ 
/* 15-SEP-2022  WLChooi 1.1   WMS-20634 - Add Corp Sales DW (WL01)      */ 
/* 11-Oct-2022  WLChooi 1.2   WMS-20634 - Change Mapping (WL02)         */ 
/* 17-JAN-2023  CHONGCS 1.3   WMS-21490 - new report (CS01)             */
/* 03-JUL-2023  CHONGCS 1.4   Devops Scripts Combine & WMS-22889 (CS02) */
/* 16-AUG-2023  CHONGCS 1.5   WMS-23403 revised report footer (CS03)    */
/************************************************************************/

CREATE   PROC [dbo].[isp_Packing_List_125_rdt] (
      @c_Pickslipno     NVARCHAR(10)
    , @c_Type           NVARCHAR(50) = ''   --WL01
)
AS
BEGIN
   SET NOCOUNT ON 
   SET QUOTED_IDENTIFIER OFF 
   SET ANSI_NULLS OFF   
   SET CONCAT_NULL_YIELDS_NULL OFF 


  --CS02 S
   DECLARE @c_logo      NVARCHAR(60) = ''
          ,@c_showlogo  NVARCHAR(1)  = 'N'

          ,@c_getorderkey   NVARCHAR(20)
          ,@c_getMAdd       NVARCHAR(45)

  --CS02 E

   IF LEFT(@c_Pickslipno,1) = 'P' -- Print from ECOM Packing    
   BEGIN    
      SELECT @c_Pickslipno = Orderkey    
      FROM PICKHEADER WITH (NOLOCK)    
      WHERE PickHeaderKey = @c_Pickslipno    


   SELECT @c_getMAdd = ISNULL(OH.M_Address1,'')
   FROM dbo.ORDERS OH (NOLOCK)
   WHERE OH.OrderKey = @c_Pickslipno

   END  
  ELSE
  BEGIN

   SELECT @c_getMAdd = ISNULL(OH.M_Address1,'')
   FROM dbo.ORDERS OH (NOLOCK)
   WHERE OH.OrderKey = @c_Pickslipno

  END  

  --CS02 S
  

  SELECT TOP 1 @c_logo = ISNULL(UDF05,'')
  FROM codelkup (NOLOCK)
  WHERE LISTNAME = 'MHDBrand' AND Long ='r_dw_Packing_List_125_1_rdt' AND code = @c_getMAdd

  
  IF @c_logo <>''

  BEGIN
       SET @c_showlogo ='Y'
  END
--CS02 E

   --IF EXISTS (SELECT 1 FROM ORDERS (NOLOCK) WHERE OrderKey = @c_Pickslipno)
   --BEGIN
   -- SELECT @c_Pickslipno = Pickheaderkey
   -- FROM PICKHEADER (NOLOCK)
   -- WHERE OrderKey = @c_Pickslipno
   --END

   --WL01 S
   IF @c_Type = 'H'
   BEGIN
      SELECT O.OrderKey
           , TRIM(ISNULL(C.Long,'')) AS DW
           , ISNULL(ST.Contact1,'') AS ST_Contact1
           , N'江苏省苏州市吴江汾湖经济开发区汾湖大道大同路利丰供应链3号库1楼' AS FooterAddr
           , N'联系电话：0512-65209631' AS FooterPhone
           , N'如有任何关于商城购买或服务的疑问或建议' AS DW3FooterAddr
           , N'请扫码进入小程序咨询，或拨打客服电话400-820-8885' AS DW3FooterPhone
           --, N'江苏省苏州市吴江汾湖经济开发区汾湖大道大同路马士基供应链3号库1楼' AS DW1FooterAddr
             ,ISNULL(C.Notes,'') AS DW1FooterAddr
           --, N'联系电话 ：4006250880  ' AS DW1FooterPhone                                    --CS03
           ,CASE WHEN ISNULL(C.Notes,'') <>'' THEN C.Notes ELSE N'联系电话 ：4008208885  '  END   --CS03
      FROM ORDERS O (NOLOCK)
      JOIN CODELKUP C WITH (NOLOCK) ON C.LISTNAME = 'MHDBrand' AND C.Code = O.M_Address1
                                   AND C.Storerkey = O.StorerKey
      LEFT JOIN STORER ST (NOLOCK) ON O.StorerKey = ST.ConsigneeFor and O.M_Address1 = ST.Address1
      WHERE O.OrderKey = @c_Pickslipno

      GOTO QUIT_SP
   END
   ELSE IF @c_Type = 'r_dw_Packing_List_125_2_rdt'
   BEGIN
      SELECT ISNULL(OH.C_Contact1,'') AS C_Contact1
           , TRIM(ISNULL(OH.C_Address2,'')) + TRIM(ISNULL(OH.C_Address3,'')) + TRIM(ISNULL(OH.C_Address4,'')) AS C_Address2
           , ISNULL(OH.C_Phone1  ,'') AS C_Phone1
           , ISNULL(OH.M_Company ,'') AS M_Company
           , ISNULL(OH.UserDefine04 ,'') AS TrackingNo   --OH.Orderkey   --WL02
           , OH.AddDate
           , 'CNY' AS Currency
           , ISNULL(TRIM(ODR.Note1),'') AS Note1
           , ISNULL(ODR.PackCnt,0) AS PackCnt
           , ISNULL(S.DESCR,'') AS DESCR
           , ISNULL(ODR.ParentSKU,'') AS ParentSKU
           , N'江苏省苏州市吴江汾湖经济开发区汾湖大道大同路利丰供应链3号库1楼' AS FooterAddr
           , N'联系电话：4008208885' AS FooterPhone
           , (Row_Number() OVER (PARTITION BY S.DESCR ORDER BY ODR.Note1, S.DESCR) ) AS RowNo
      FROM ORDERS OH (NOLOCK)
      JOIN ORDERDETAIL OD (NOLOCK) ON OD.OrderKey = OH.OrderKey
      LEFT JOIN OrderDetailRef ODR (NOLOCK) ON ODR.OrderKey = OD.OrderKey AND ODR.RetailSKU = OD.Sku
                                           AND ODR.StorerKey = OD.StorerKey
      JOIN SKU S (NOLOCK) ON S.StorerKey = OD.StorerKey AND S.SKU = OD.SKU
      WHERE OH.OrderKey = @c_Pickslipno
      ORDER BY ISNULL(TRIM(ODR.Note1),''), RowNo, S.DESCR

      GOTO QUIT_SP
   END
--CS01 S
   ELSE IF @c_Type = 'r_dw_Packing_List_125_3_rdt'
   BEGIN
        CREATE TABLE #TMPODFPL125_3 
       (
         ID                INT           IDENTITY(1, 1) NOT NULL,
         Storerkey         NVARCHAR(20),
         Orderkey          NVARCHAR(10),
         OrderLineNumber   NVARCHAR(5),
         Note1             NVARCHAR(1000),   
         ODRQTY            INT
)


     INSERT INTO #TMPODFPL125_3
     (
         Storerkey,
         Orderkey,
         OrderLineNumber,
         Note1,
         ODRQTY
     )
    SELECT DISTINCT odr.StorerKey,ODR.Orderkey,odr.OrderLineNumber,CASE WHEN Note1 LIKE '%|%' THEN substring(Note1,1,charindex('|',Note1,2)-1) ELSE Note1 END AS note1
                   ,case when bomqty=0 then packcnt else bomqty end
    FROM OrderDetailRef ODR (NOLOCK)
    WHERE ODR.OrderKey =  @c_Pickslipno

      SELECT ISNULL(OH.C_Contact1,'') AS C_Contact1
           , TRIM(ISNULL(OH.C_Address2,'')) + TRIM(ISNULL(OH.C_Address3,'')) + TRIM(ISNULL(OH.C_Address4,'')) AS C_Address2
           , ISNULL(OH.C_Phone1  ,'') AS C_Phone1
           , ISNULL(OH.M_Company ,'') AS M_Company
           , ISNULL(OH.UserDefine04 ,'') AS TrackingNo   --OH.Orderkey   --WL02
           , OH.AddDate
           , 'CNY' AS Currency
          -- , OD.qtypicked AS ODQtypicked
           , TP1253.ODRQTY AS ODQtypicked--CASE WHEN ODR.BOMQty = 0 THEN ODR.PackCnt ELSE ODR.BOMQty END AS ODQtypicked
           --, ISNULL(S.DESCR,'') AS DESCR
           , ISNULL(TP1253.Note1,'') AS DESCR
           , N'如有任何关于商城购买或服务的疑问或建议' AS FooterAddr
           , N'请扫码进入小程序咨询，或拨打客服电话400-820-8885' AS FooterPhone
          -- , (Row_Number() OVER (PARTITION BY ISNULL(ODR.ParentSKU,'') ORDER BY ISNULL(ODR.ParentSKU,'')) ) AS RowNo
           ,TP1253.ID AS RowNo
           , N'轩尼诗挚樽会商城 订单详情'   AS Rpttitle
      FROM ORDERS OH (NOLOCK)
      JOIN ORDERDETAIL OD (NOLOCK) ON OD.OrderKey = OH.OrderKey
      --LEFT JOIN OrderDetailRef ODR (NOLOCK) ON ODR.OrderKey = OD.OrderKey AND ODR.RetailSKU = OD.Sku
      --                                     AND ODR.StorerKey = OD.StorerKey
      JOIN #TMPODFPL125_3 TP1253 ON TP1253.Storerkey = OD.storerkey AND RIGHT('00000' +TP1253.OrderLineNumber,5)=OD.OrderLineNumber AND TP1253.Orderkey=OD.orderkey
      JOIN SKU S (NOLOCK) ON S.StorerKey = OD.StorerKey AND S.SKU = OD.SKU
      WHERE OH.OrderKey = @c_Pickslipno
      GROUP BY ISNULL(OH.C_Contact1,'') 
           , TRIM(ISNULL(OH.C_Address2,'')) + TRIM(ISNULL(OH.C_Address3,'')) + TRIM(ISNULL(OH.C_Address4,'')) 
           , ISNULL(OH.C_Phone1  ,'') 
           , ISNULL(OH.M_Company ,'') 
           , ISNULL(OH.UserDefine04 ,'') 
           , OH.AddDate
           , TP1253.ODRQTY
           , ISNULL(TP1253.Note1,'') 
           , TP1253.ID
      ORDER BY  TP1253.ID,ISNULL(TP1253.Note1,'') 


      GOTO QUIT_SP
   END
--CS01 E
   --r_dw_Packing_List_125_1_rdt
   --WL01 E

   SELECT ORDERS.C_contact1
        , LTRIM(RTRIM(ISNULL(ORDERS.C_Address2,'')))
        , ORDERS.C_Phone1
        , ORDERS.M_Company
        , PACKDETAIL.LabelNo
        , ORDERS.Adddate
        , SKU.Descr
        , SUM(PACKDETAIL.Qty) AS Qty
        , PACKDETAIL.PickSlipNo
        , storer.contact1  --ML01
        , @c_showlogo AS ShowLogo     --CS02
        , @c_logo AS Logo             --CS02
   FROM ORDERS (NOLOCK)
   JOIN PACKHEADER(NOLOCK) ON PackHeader.OrderKey = ORDERS.OrderKey
   JOIN PACKDETAIL (NOLOCK) ON PackDetail.PickSlipNo = PackHeader.PickSlipNo
   JOIN SKU (NOLOCK) ON PACKDETAIL.StorerKey = SKU.StorerKey AND PACKDETAIL.Sku = SKU.Sku
   --JOIN STORER (NOLOCK) ON STORER.StorerKey = ORDERS.StorerKey
   JOIN STORER (NOLOCK) ON ORDERS.StorerKey=STORER.ConsigneeFor and orders.m_address1=storer.address1 --ML01
   WHERE ORDERS.ORDERKEY = @c_Pickslipno
   GROUP BY ORDERS.C_contact1
        , LTRIM(RTRIM(ISNULL(ORDERS.C_Address2,'')))
        , ORDERS.C_Phone1
        , ORDERS.M_Company
        , PACKDETAIL.LabelNo
        , ORDERS.Adddate
        , PACKDETAIL.PickSlipNo
        , SKU.Descr
        , storer.contact1  --ML01

   QUIT_SP:   --WL01

   IF OBJECT_ID('tempdb..#TMPODFPL125_3') IS NOT NULL
      DROP TABLE #TMPODFPL125_3

END     

GO