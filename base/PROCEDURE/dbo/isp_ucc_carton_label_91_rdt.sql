SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/*************************************************************************/
/* Stored Procedure: isp_UCC_Carton_Label_91_rdt                         */
/* Creation Date: 16-Oct-2019                                            */
/* Copyright: LFL                                                        */
/* Written by:                                                           */
/*                                                                       */
/* Purpose: PVH Carton Label                                             */
/*          Copy from r_hk_carton_label_12                               */
/*                                                                       */
/* Called By: Print Carton Label by RDT Pack module                      */
/*            r_dw_ucc_carton_label_91_rdt                               */
/*                                                                       */
/* PVCS Version: 1.0                                                     */
/*                                                                       */
/* Version: 7.0                                                          */
/*                                                                       */
/* Data Modifications:                                                   */
/*                                                                       */
/* Updates:                                                              */
/* Date         Author   Ver  Purposes                                   */
/* 06-MAY-2020  CSCHONG  1.1  WMS-13139 - revised ship to logic (CS01)   */
/* 02-FEB-2021  CSCHONG  1.2  WMS-16055 - revised field mapping (CS02)   */
/* 23-APR-2021  Mingle   1.3  WMS-16815 - change logic(ML01)             */
/* 10-FEB-2022  Mingle   1.4  WMS-18791 - add logic(ML02)                */
/*************************************************************************/

CREATE PROCEDURE [dbo].[isp_UCC_Carton_Label_91_rdt] (
        @as_storerkey    NVARCHAR(15)
      , @as_wavekey      NVARCHAR(4000)
      , @as_pickslipno   NVARCHAR(4000)
      , @as_labelno      NVARCHAR(4000)
      , @as_fcp          NVARCHAR(1) = 'N'
      , @as_updpikdet    NVARCHAR(1) = 'N'
)
AS
BEGIN
   SET NOCOUNT ON
   SET QUOTED_IDENTIFIER OFF
   SET ANSI_NULLS OFF
   SET CONCAT_NULL_YIELDS_NULL OFF

   DECLARE @c_SQL            NVARCHAR(4000)
         , @c_ExecStatements NVARCHAR(4000)
         , @c_PickdetailKey  NVARCHAR(10)

         --CS02 START
         ,@c_ISOCntryCode    NVARCHAR(20)
         ,@n_CtnVAS          INT

         SET @n_CtnVAS = 0

   IF OBJECT_ID('tempdb..#TEMP_RESULT') IS NOT NULL
      DROP TABLE #TEMP_RESULT

   SELECT Pickslipno           = RTRIM(PD.Pickslipno)
        , CartonNo             = PD.CartonNo
        , LabelNo              = RTRIM(PD.LabelNo)
        , LabelLine            = RTRIM(PD.LabelLine)
        , FirstOrderkey        = ISNULL(MAX(RTRIM(PAK.FirstOrderkey)),'')
        , FromEntity           = ISNULL(MAX(RTRIM(FAC.Descr)),'')
        --, PickTicketNo         = ISNULL(MAX(RTRIM(CASE WHEN OG.UDF01 = 'R' THEN OH.Loadkey ELSE OH.ExternOrderkey END)),'')
        , PickTicketNo         = ISNULL(MAX(RTRIM(OH.Loadkey)),'')             --ML01
        , ShipmentNo           = ISNULL(MAX(RTRIM(OH.Userdefine09)),'')
        , C_Country            = ISNULL(MAX(RTRIM(OH.C_Country)),'') 
        --CS01 START
        , C_Company            = CASE WHEN MAX(ISNULL(BILLTO.B_fax1,'')) <>'' THEN ISNULL(MAX(RTRIM(BILLTO.B_Company)),'') ELSE ISNULL(MAX(RTRIM(OH.C_Company)),'') END
        , C_Address1           = CASE WHEN MAX(ISNULL(BILLTO.B_fax1,'')) <>'' THEN ISNULL(MAX(RTRIM(BILLTO.B_Address1)),'') ELSE ISNULL(MAX(RTRIM(OH.C_Address1)),'') END
        , C_Address2           = CASE WHEN MAX(ISNULL(BILLTO.B_fax1,'')) <>'' THEN ISNULL(MAX(RTRIM(BILLTO.B_Address2)),'') ELSE ISNULL(MAX(RTRIM(OH.C_Address2)),'') END
        , C_Address3           = CASE WHEN MAX(ISNULL(BILLTO.B_fax1,'')) <>'' THEN ISNULL(MAX(RTRIM(BILLTO.B_Address3)),'') ELSE ISNULL(MAX(RTRIM(OH.C_Address3)),'') END
        , C_CITY               = CASE WHEN MAX(ISNULL(BILLTO.B_fax1,'')) <>'' THEN ISNULL(MAX(RTRIM(BILLTO.B_CITY)),'') ELSE ISNULL(MAX(RTRIM(OH.C_CITY)),'') END
        , C_State              = CASE WHEN MAX(ISNULL(BILLTO.B_fax1,'')) <>'' THEN ISNULL(MAX(RTRIM(BILLTO.B_Country)),'') ELSE ISNULL(MAX(RTRIM(OH.C_State)),'') END
        --CS01 END
        , Consigneekey         = ISNULL(MAX(RTRIM(OH.ConsigneeKey)),'')
        , Billtokey            = MAX(CASE WHEN OG.UDF01 = 'W' THEN ISNULL(RTRIM(OH.BillToKey),'')      ELSE ISNULL(RTRIM(OH.B_Country),'') END)
        , OH_DELNotes          = MAX(CASE WHEN OG.UDF01 = 'W' THEN ISNULL(RTRIM(OH.UserDefine03),'')   ELSE '' END)
        , OH_UDF01             = MAX(CASE WHEN OG.UDF01 = 'R' THEN ISNULL(RTRIM(OH.UserDefine01),'')   ELSE '' END)
        , Store_Code           = MAX(CASE WHEN OG.UDF01 = 'R' THEN ISNULL(RTRIM(SHPTO.[Secondary]),'') ELSE '' END)
        , OH_Type              = MAX(CASE WHEN OG.UDF01 = 'R' THEN ISNULL(RTRIM(OH.[Type]),'')         ELSE '' END)
       --CS02 START
        --, SPRemarks            = MAX(CASE WHEN OG.UDF01 = 'R' THEN ISNULL(RTRIM(RM.Description),'')    ELSE '' END)
        --, VAS                  = MAX(CASE WHEN OG.UDF01 = 'R' THEN ISNULL(RTRIM((VAS.Long)),'')     ELSE '' END)
        , SPRemarks            = MAX(CASE WHEN OG.Long = 'R' then  isnull(CL3.Notes,'') else '' end)
        , VAS                  = max(Case OG.Long when 'R' then case isnull(CL2.Code,'') when '' then 'V' else '' end else '' end)
        --CS02 END
        , Div                  = ISNULL(RTRIM(MAX(SKU.BUSR5)),'')
        , Brand                = ISNULL(RTRIM(MAX(SKU.BUSR6)),'')
        , PTSLocation          = ISNULL(RTRIM(MAX(PIKDT.ToLoc)),'')
        , TW_ImportVAS         = MAX(CASE WHEN OG.UDF01 = 'R' AND OH.BillToKey='TWRETAIL' AND (OH.Type='R' OR (OH.Type='L' AND PIKDT.OD_UDF06 LIKE 'L%R'))               THEN '1' ELSE '' END)
        , TW_BraVAS            = MAX(CASE WHEN OG.UDF01 = 'R' AND OH.BillToKey='TWRETAIL' AND OH.Type='R' AND OH.BuyerPO='BRA'                                           THEN '2' ELSE '' END)
        , TW_CareLblVAS_NonBra = MAX(CASE WHEN OG.UDF01 = 'R' AND OH.BillToKey='TWRETAIL' AND OH.Type='L' AND PIKDT.OD_UDF06 LIKE 'L%R' AND ISNULL(OH.BuyerPO,'')<>'BRA' THEN '3' ELSE '' END)
        , TW_CareLblVAS_Bra    = MAX(CASE WHEN OG.UDF01 = 'R' AND OH.BillToKey='TWRETAIL' AND OH.Type='L' AND PIKDT.OD_UDF06 LIKE 'L%R' AND OH.BuyerPO='BRA'             THEN '4' ELSE '' END)
        , SQL1                 = ISNULL(RTRIM(MAX(VAS.Notes)),'') 
        , SQL2                 = ISNULL(RTRIM(MAX(RM.Notes2)),'')
        , BRA                  = '' --MAX(CASE WHEN OG.UDF01 = 'R' AND OH.BuyerPO='BRA' THEN 'B' ELSE '' END)
        , RouteCode            = MAX(ISNULL(RTRIM(RT.ZipCodeFrom),''))
        , CartonType           = MAX(ISNULL(RTRIM(PIF.CartonType),''))
        , DeliveryDate         = MAX(CASE WHEN OH.ORDERGROUP = 'R' AND OH.TYPE <> '4' THEN CONVERT(VARCHAR,OH.DELIVERYDATE,103) ELSE '' END) --ML02

   INTO #TEMP_RESULT

   FROM (
      SELECT PickslipNo    = ISNULL(PH1.PickslipNo, PH2.PickslipNo)
           , FirstOrderkey = MIN(OH.Orderkey)
        FROM dbo.ORDERS           OH (NOLOCK)
        LEFT JOIN dbo.PACKHEADER  PH1(NOLOCK) ON OH.Orderkey = PH1.Orderkey AND PH1.Orderkey<>''
        LEFT JOIN dbo.PACKHEADER  PH2(NOLOCK) ON OH.Loadkey = PH2.Loadkey AND OH.Loadkey<>'' AND ISNULL(PH2.Orderkey,'')=''
       WHERE OH.Storerkey = @as_storerkey
         AND (ISNULL(@as_wavekey,'')<>'' OR ISNULL(@as_pickslipno,'')<>'' OR ISNULL(@as_labelno,'')<>'')
         AND (ISNULL(@as_wavekey,'')='' OR OH.Userdefine09 = @as_wavekey)
         AND (ISNULL(@as_pickslipno,'')='' OR ISNULL(PH1.PickslipNo, PH2.PickslipNo) = @as_pickslipno)
         AND ISNULL(PH1.PickslipNo, PH2.PickslipNo) IS NOT NULL
      GROUP BY ISNULL(PH1.PickslipNo, PH2.PickslipNo)
   ) PAK

   JOIN dbo.PACKDETAIL PD  (NOLOCK) ON PAK.PickslipNo = PD.PickslipNo
   JOIN dbo.SKU        SKU (NOLOCK) ON PD.Storerkey = SKU.Storerkey AND PD.Sku = SKU.Sku
   JOIN dbo.ORDERS     OH  (NOLOCK) ON PAK.FirstOrderkey = OH.Orderkey
   JOIN dbo.FACILITY   FAC (NOLOCK) ON OH.Facility = FAC.Facility

   LEFT JOIN dbo.PACKINFO   PIF (NOLOCK) ON PD.PickslipNo = PIF.PickslipNo AND PD.CartonNo = PIF.CartonNo
   LEFT JOIN dbo.ROUTEMASTER RT (NOLOCK) ON OH.Route = RT.Route
   LEFT JOIN (
      SELECT Storerkey = RTRIM( a.Storerkey )
           , CaseID    = RTRIM( a.CaseID )
           , ToLoc     = RTRIM( MAX(a.ToLoc) )
           , OD_UDF06  = RTRIM( MAX(IIF(b.Userdefine06 LIKE 'L%R', b.Userdefine06, '')) )
           , UOM       = MAX(CASE WHEN a.UOM='2' THEN a.UOM ELSE '' END)
        FROM dbo.PICKDETAIL  a (NOLOCK)
        JOIN dbo.ORDERDETAIL b (NOLOCK) ON a.Orderkey = b.Orderkey AND a.OrderLineNumber = b.OrderLineNumber
       WHERE a.Storerkey = @as_storerkey
       GROUP BY a.Storerkey, a.CaseID
   ) PIKDT ON PD.Storerkey = PIKDT.Storerkey AND PD.LabelNo = PIKDT.CaseID

   LEFT JOIN dbo.STORER SHPTO (NOLOCK) ON 'PVH'+OH.ConsigneeKey = SHPTO.Storerkey
   LEFT JOIN dbo.CODELKUP  OG (NOLOCK) ON OG.LISTNAME = 'ORDERGROUP' AND OG.Code = OH.OrderGroup AND OG.Storerkey = OH.Storerkey
   LEFT JOIN dbo.CODELKUP VAS (NOLOCK) ON VAS.LISTNAME = 'PVHPXLBL' AND VAS.Storerkey = OH.StorerKey AND VAS.Code = OH.BillToKey AND VAS.Code2=''
   LEFT JOIN dbo.CODELKUP  RM (NOLOCK) ON RM.LISTNAME = 'PVHREPORT' AND RM.Storerkey = OH.StorerKey AND RM.Code = OH.ConsigneeKey AND RM.Code2='SPREMARK'
   LEFT JOIN dbo.STORER BILLTO (NOLOCK) ON 'QHW-'+OH.ConsigneeKey = BILLTO.Storerkey AND BILLTO.consigneefor=@as_storerkey and BILLTO.type='2'  --CS01
   --CS02 START
   left join STORER ST(nolock) on OH.storerkey = ST.consigneefor and 'PVH-'+OH.consigneekey = ST.storerkey
   left join Codelkup CL1(nolock) on CL1.Listname = 'QHWORDTP' and CL1.Storerkey = SKU.Storerkey and CL1.Code = left(SKU.Busr2,2)
   left join Codelkup CL2(nolock) on CL2.Listname = 'PVHPXLBL' and CL2.Short = Isnull(CL1.UDF01,'') and CL2.UDF01 = ST.ISOCntryCode 
                                  and CL2.Storerkey = OH.Storerkey and CL2.UDF02 = OH.OrderGroup and CL2.Code2 = '1'
   left join CODELKUP CL3(nolock) on CL3.LISTNAME = 'PVHREPORT' and CL3. Storerkey = OH.StorerKey and CL3.Short = CL1.UDF01 and CL3.Long = OH.ConsigneeKey
  --CS02 END
   WHERE (ISNULL(@as_wavekey,'')<>'' OR ISNULL(@as_pickslipno,'')<>'' OR ISNULL(@as_labelno,'')<>'')
   AND (ISNULL(@as_labelno,'')='' OR PD.LabelNo= @as_labelno)
   AND ((ISNULL(@as_fcp,'')='A')
   OR (ISNULL(@as_fcp,'')='F' AND ISNULL(PIKDT.UOM,'')='2')
   OR (ISNULL(@as_fcp,'')<>'F' AND ISNULL(PIKDT.UOM,'')<>'2'))

   GROUP BY PD.Pickslipno
          , PD.CartonNo
          , PD.LabelNo
          , PD.LabelLine

   DECLARE C_CUR1 CURSOR LOCAL FAST_FORWARD READ_ONLY FOR
   SELECT DISTINCT SQL1 FROM #TEMP_RESULT WHERE VAS<>'' AND SQL1<>''

   OPEN C_CUR1

   WHILE 1=1
   BEGIN
      FETCH NEXT FROM C_CUR1
       INTO @c_SQL

      IF @@FETCH_STATUS<>0
         BREAK

      SET @c_ExecStatements = 'UPDATE a SET VAS = '''''
        +' FROM #TEMP_RESULT a'
        +' JOIN ORDERS     (NOLOCK) ON a.FirstOrderkey = ORDERS.Orderkey'
        +' JOIN PACKDETAIL (NOLOCK) ON a.PickslipNo = PACKDETAIL.PickslipNo AND a.CartonNo = PACKDETAIL.CartonNo'
                                +' AND a.LabelNo = PACKDETAIL.LabelNo AND a.LabelLine = PACKDETAIL.LabelLine'
        +' JOIN SKU        (NOLOCK) ON PACKDETAIL.Storerkey = SKU.Storerkey AND PACKDETAIL.Sku = SKU.Sku'
        +' WHERE a.VAS<>'''' AND a.SQL1 = @c_SQL'
        +' AND NOT (' + ISNULL(@c_SQL,'') + ')'

        EXEC sp_ExecuteSql @c_ExecStatements
                       , N'@c_SQL NVARCHAR(4000)'
                       , @c_SQL

   END
   CLOSE C_CUR1
   DEALLOCATE C_CUR1


   DECLARE C_CUR2 CURSOR LOCAL FAST_FORWARD READ_ONLY FOR
   SELECT DISTINCT SQL2 FROM #TEMP_RESULT WHERE SPRemarks<>'' AND SQL2<>''

   OPEN C_CUR2

   WHILE 1=1
   BEGIN
      FETCH NEXT FROM C_CUR2
       INTO @c_SQL

      IF @@FETCH_STATUS<>0
         BREAK

      SET @c_ExecStatements = 'UPDATE a SET SPRemarks = '''''
        +' FROM #TEMP_RESULT a'
        +' JOIN ORDERS     (NOLOCK) ON a.FirstOrderkey = ORDERS.Orderkey'
        +' JOIN PACKDETAIL (NOLOCK) ON a.PickslipNo = PACKDETAIL.PickslipNo AND a.CartonNo = PACKDETAIL.CartonNo'
                                +' AND a.LabelNo = PACKDETAIL.LabelNo AND a.LabelLine = PACKDETAIL.LabelLine'
        +' JOIN SKU        (NOLOCK) ON PACKDETAIL.Storerkey = SKU.Storerkey AND PACKDETAIL.Sku = SKU.Sku'
        +' WHERE a.SPRemarks<>'''' AND a.SQL2 = @c_SQL'
        +' AND NOT (' + ISNULL(@c_SQL,'') + ')'

      EXEC sp_ExecuteSql @c_ExecStatements
                       , N'@c_SQL NVARCHAR(4000)'
                       , @c_SQL

   END
   CLOSE C_CUR2
   DEALLOCATE C_CUR2


   -- Update Pickdetail Status to 5
   IF ISNULL(@as_storerkey,'')<>'' AND ISNULL(@as_labelno,'')<>'' AND ISNULL(@as_fcp,'')='F' AND ISNULL(@as_updpikdet,'')='Y'
   BEGIN
      DECLARE C_CUR3 CURSOR LOCAL FAST_FORWARD READ_ONLY FOR
        SELECT PickdetailKey
        FROM PICKDETAIL (NOLOCK)
        WHERE Storerkey=@as_storerkey AND CaseID=@as_labelno AND Status='3'
        ORDER BY 1

      OPEN C_CUR3

      WHILE 1=1
      BEGIN
         FETCH NEXT FROM C_CUR3
          INTO @c_PickdetailKey

            IF @@FETCH_STATUS<>0
            BREAK

          UPDATE PICKDETAIL SET Status='5'
          WHERE PickdetailKey=@c_PickdetailKey AND Storerkey=@as_storerkey AND CaseID=@as_labelno AND Status='3'
      END
      CLOSE C_CUR3
      DEALLOCATE C_CUR3
   END


   -- Output result
   SELECT DISTINCT
          Pickslipno           = Pickslipno
        , LabelNo              = LabelNo
        , FromEntity           = FIRST_VALUE( FromEntity   ) OVER(PARTITION BY PickslipNo, LabelNo ORDER BY FirstOrderkey)
        , PickTicketNo         = FIRST_VALUE( PickTicketNo ) OVER(PARTITION BY PickslipNo, LabelNo ORDER BY FirstOrderkey)
        , ShipmentNo           = FIRST_VALUE( ShipmentNo   ) OVER(PARTITION BY PickslipNo, LabelNo ORDER BY FirstOrderkey)
        , C_Country            = FIRST_VALUE( C_Country    ) OVER(PARTITION BY PickslipNo, LabelNo ORDER BY FirstOrderkey)
        , C_Company            = FIRST_VALUE( C_Company    ) OVER(PARTITION BY PickslipNo, LabelNo ORDER BY FirstOrderkey)
        , C_Address1           = FIRST_VALUE( C_Address1   ) OVER(PARTITION BY PickslipNo, LabelNo ORDER BY FirstOrderkey)
        , C_Address2           = FIRST_VALUE( C_Address2   ) OVER(PARTITION BY PickslipNo, LabelNo ORDER BY FirstOrderkey)
        , C_Address3           = FIRST_VALUE( C_Address3   ) OVER(PARTITION BY PickslipNo, LabelNo ORDER BY FirstOrderkey)
        , C_CITY               = FIRST_VALUE( C_CITY       ) OVER(PARTITION BY PickslipNo, LabelNo ORDER BY FirstOrderkey)
        , C_State              = FIRST_VALUE( C_State      ) OVER(PARTITION BY PickslipNo, LabelNo ORDER BY FirstOrderkey)
        , Consigneekey         = FIRST_VALUE( Consigneekey ) OVER(PARTITION BY PickslipNo, LabelNo ORDER BY FirstOrderkey)
        , Billtokey            = FIRST_VALUE( Billtokey    ) OVER(PARTITION BY PickslipNo, LabelNo ORDER BY FirstOrderkey)
        , OH_DELNotes          = FIRST_VALUE( OH_DELNotes  ) OVER(PARTITION BY PickslipNo, LabelNo ORDER BY FirstOrderkey)
        , OH_UDF01             = FIRST_VALUE( OH_UDF01     ) OVER(PARTITION BY PickslipNo, LabelNo ORDER BY FirstOrderkey)
        , Store_Code           = FIRST_VALUE( Store_Code   ) OVER(PARTITION BY PickslipNo, LabelNo ORDER BY FirstOrderkey)
        , OH_Type              = FIRST_VALUE( OH_Type      ) OVER(PARTITION BY PickslipNo, LabelNo ORDER BY FirstOrderkey)
        , SPRemarks            = MAX( SPRemarks            ) OVER(PARTITION BY PickslipNo, LabelNo)
        , VAS                  = MAX( VAS                  ) OVER(PARTITION BY PickslipNo, LabelNo)
        , Div                  = MAX( Div                  ) OVER(PARTITION BY PickslipNo, LabelNo)
        , Brand                = MAX( Brand                ) OVER(PARTITION BY PickslipNo, LabelNo)
        , PTSLocation          = MAX( PTSLocation          ) OVER(PARTITION BY PickslipNo, LabelNo)
        , TW_ImportVAS         = MAX( TW_ImportVAS         ) OVER(PARTITION BY PickslipNo, LabelNo)
        , TW_BraVAS            = MAX( TW_BraVAS            ) OVER(PARTITION BY PickslipNo, LabelNo)
        , TW_CareLblVAS_NonBra = MAX( TW_CareLblVAS_NonBra ) OVER(PARTITION BY PickslipNo, LabelNo)
        , TW_CareLblVAS_Bra    = MAX( TW_CareLblVAS_Bra    ) OVER(PARTITION BY PickslipNo, LabelNo)
        , BRA                  = MAX( BRA                  ) OVER(PARTITION BY PickslipNo, LabelNo)
        , RouteCode            = MAX( RouteCode            ) OVER(PARTITION BY PickslipNo, LabelNo)
        , CartonType           = MAX( CartonType           ) OVER(PARTITION BY PickslipNo, LabelNo)
        , DeliveryDate         = FIRST_VALUE( DeliveryDate ) OVER(PARTITION BY PickslipNo, LabelNo ORDER BY FirstOrderkey) --ML02
     FROM #TEMP_RESULT
     ORDER BY 1, 2
END

GO