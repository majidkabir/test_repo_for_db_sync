SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
/*************************************************************************/
/* Stored Procedure: isp_r_hk_carton_label_12                            */
/* Creation Date: 09-Jul-2018                                            */
/* Copyright: LFL                                                        */
/* Written by: Michael Lam (HK LIT)                                      */
/*                                                                       */
/* Purpose: PVH Carton Label                                             */
/*                                                                       */
/* Called By: Report Module. Datawidnow r_hk_carton_label_12             */
/*                                                                       */
/* PVCS Version: 1.0                                                     */
/*                                                                       */
/* Version: 7.0                                                          */
/*                                                                       */
/* Data Modifications:                                                   */
/*                                                                       */
/* Updates:                                                              */
/* Date         Author   Ver  Purposes                                   */
/* 21/09/2018   ML       1.1  WMS-6359 add new parameters:               */
/*                            @as_fcp = A - All                          */
/*                                      F - FCP (pickdetail.UOM=2)       */
/*                                      Else Non-FCP                     */
/*                            @as_updpikdet = Y/N                        */
/* 15/11/2018   ML       1.2  WMS-6960 add new BRA indicator             */
/* 22/11/2018   ML       1.3  WMS-7085 add RouteCode                     */
/* 12/03/2019   ML       1.4  WMS-8295 add PackInfo.CartonType           */
/* 30/08/2019   ML       1.5  WMS-10451 If PTSLocation is blank then get */
/*                            mapped PAZones                             */
/* 22/01/2020   ML       1.6  Performance tunning                        */
/* 27/08/2020   ML       1.7  WMS-14990 Chg Fields definition            */
/*************************************************************************/

CREATE PROCEDURE [dbo].[isp_r_hk_carton_label_12] (
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

   IF OBJECT_ID('tempdb..#TEMP_ORDERS') IS NOT NULL
      DROP TABLE #TEMP_ORDERS
   IF OBJECT_ID('tempdb..#TEMP_PACKHEADER') IS NOT NULL
      DROP TABLE #TEMP_PACKHEADER
   IF OBJECT_ID('tempdb..#TEMP_PICKDETAIL') IS NOT NULL
      DROP TABLE #TEMP_PICKDETAIL
   IF OBJECT_ID('tempdb..#TEMP_RESULT') IS NOT NULL
      DROP TABLE #TEMP_RESULT

   -- #TEMP_ORDERS
   SELECT DISTINCT
          Orderkey   = RTRIM( OH.Orderkey )
        , PickslipNo = RTRIM( PH.PickslipNo )
        , LabelNo    = RTRIM( PD.LabelNo )
     INTO #TEMP_ORDERS
     FROM dbo.ORDERS          OH    (NOLOCK)
     JOIN dbo.PACKHEADER      PH    (NOLOCK) ON OH.Orderkey = PH.Orderkey
     JOIN dbo.PACKDETAIL      PD    (NOLOCK) ON PH.PickslipNo = PD.PickslipNo
    WHERE PD.Storerkey = @as_storerkey
      AND (ISNULL(@as_wavekey,'')<>'' OR ISNULL(@as_pickslipno,'')<>'' OR ISNULL(@as_labelno,'')<>'')
      AND (ISNULL(@as_wavekey   ,'')='' OR OH.Userdefine09 = @as_wavekey)
      AND (ISNULL(@as_pickslipno,'')='' OR PH.PickslipNo = @as_pickslipno)
      AND (ISNULL(@as_labelno   ,'')='' OR PD.LabelNo = @as_labelno)

   INSERT INTO #TEMP_ORDERS (Orderkey, PickslipNo, LabelNo)
   SELECT DISTINCT
          Orderkey   = RTRIM( OH.Orderkey )
        , PickslipNo = RTRIM( PH.PickslipNo )
        , LabelNo    = RTRIM( PD.LabelNo )
     FROM dbo.ORDERS          OH    (NOLOCK)
     JOIN dbo.PACKHEADER      PH    (NOLOCK) ON OH.Loadkey = PH.Loadkey AND ISNULL(PH.Orderkey,'')=''
     JOIN dbo.PACKDETAIL      PD    (NOLOCK) ON PH.PickslipNo = PD.PickslipNo
    WHERE PD.Storerkey = @as_storerkey
      AND OH.Loadkey <> ''
      AND (ISNULL(@as_wavekey,'')<>'' OR ISNULL(@as_pickslipno,'')<>'' OR ISNULL(@as_labelno,'')<>'')
      AND (ISNULL(@as_wavekey   ,'')='' OR OH.Userdefine09 = @as_wavekey)
      AND (ISNULL(@as_pickslipno,'')='' OR PH.PickslipNo = @as_pickslipno)
      AND (ISNULL(@as_labelno   ,'')='' OR PD.LabelNo = @as_labelno)


   -- #TEMP_PACKHEADER
   SELECT PickslipNo    = PickslipNo
        , FirstOrderkey = MIN(Orderkey)
     INTO #TEMP_PACKHEADER
     FROM #TEMP_ORDERS
    GROUP BY PickslipNo


   -- #TEMP_PICKDETAIL
   SELECT Storerkey = RTRIM( PD.Storerkey )
        , CaseID    = RTRIM( PD.CaseID )
        , ToLoc     = RTRIM( MAX(PD.ToLoc) )
        , OD_UDF06  = RTRIM( MAX(IIF(OD.Userdefine06 LIKE 'L%R', OD.Userdefine06, '')) )
        , UOM       = MAX(CASE WHEN PD.UOM='2' THEN PD.UOM ELSE '' END)
        , Zones     = ISNULL(STUFF((SELECT DISTINCT '-',LTRIM(RTRIM(z.Short))
                             FROM dbo.PICKDETAIL x (NOLOCK)
                             JOIN dbo.LOC        y (NOLOCK) ON x.Loc = y.Loc
                             JOIN dbo.CODELKUP   z (NOLOCK) ON z.LISTNAME='PVHZONE' AND x.Storerkey=z.Storerkey AND y.PutawayZone=z.Code
                             WHERE ISNULL(z.Short,'')<>'' AND x.CaseID=PD.CaseID
                             ORDER BY 2 FOR XML PATH('')),1,1,''),'')
     INTO #TEMP_PICKDETAIL
     FROM dbo.PICKDETAIL  PD (NOLOCK)
     JOIN dbo.ORDERDETAIL OD (NOLOCK) ON PD.Orderkey = OD.Orderkey AND PD.OrderLineNumber = OD.OrderLineNumber
     JOIN #TEMP_ORDERS    ORD(NOLOCK) ON PD.CaseID = ORD.LabelNo
    WHERE PD.Storerkey = @as_storerkey AND PD.CaseID<>''
    GROUP BY PD.Storerkey, PD.CaseID


   -- #TEMP_RESULT
   SELECT Pickslipno           = RTRIM(PD.Pickslipno)
        , CartonNo             = PD.CartonNo
        , LabelNo              = RTRIM(PD.LabelNo)
        , LabelLine            = RTRIM(PD.LabelLine)
        , FirstOrderkey        = ISNULL(MAX(RTRIM(PAK.FirstOrderkey)),'')
        , FromEntity           = ISNULL(MAX(RTRIM(FAC.Descr)),'')
        , PickTicketNo         = ISNULL(MAX(RTRIM(CASE WHEN OG.UDF01 = 'R' THEN OH.Loadkey ELSE OH.ExternOrderkey END)),'')
        , ShipmentNo           = ISNULL(MAX(RTRIM(OH.Userdefine09)),'')
        , C_Country            = ISNULL(MAX(RTRIM(OH.C_Country)),'')
        , C_Company            = ISNULL(MAX(RTRIM(OH.C_Company)),'')
        , C_Address1           = ISNULL(MAX(RTRIM(OH.C_Address1)),'')
        , C_Address2           = ISNULL(MAX(RTRIM(OH.C_Address2)),'')
        , C_Address3           = ISNULL(MAX(RTRIM(OH.C_Address3)),'')
        , C_CITY               = ISNULL(MAX(RTRIM(OH.C_CITY)),'')
        , C_State              = ISNULL(MAX(RTRIM(OH.C_State)),'')
        , Consigneekey         = ISNULL(MAX(RTRIM(OH.ConsigneeKey)),'')
        , Billtokey            = MAX(CASE WHEN OG.UDF01 = 'W' THEN ISNULL(RTRIM(OH.BillToKey),'')      ELSE ISNULL(RTRIM(OH.B_Country),'') END)
        , OH_DELNotes          = MAX(CASE WHEN OG.UDF01 = 'W' THEN ISNULL(RTRIM(OH.Salesman),'')       ELSE '' END)
        , OH_UDF01             = MAX(CASE WHEN OG.UDF01 = 'R' THEN ISNULL(CONVERT(VARCHAR(10),OH.DeliveryDate,103),'') ELSE '' END)
        , Store_Code           = MAX(CASE WHEN OG.UDF01 = 'R' THEN ISNULL(RTRIM(SHPTO.[Secondary]),'') ELSE '' END)
        , OH_Type              = MAX(CASE WHEN OG.UDF01 = 'R' THEN ISNULL(RTRIM(OH.[Type]),'')         ELSE '' END)
        , SPRemarks            = MAX(CASE WHEN OG.UDF01 = 'R' THEN ISNULL(RTRIM(RM.Description),'')    ELSE '' END)
        , VAS                  = ISNULL(RTRIM(MAX(VAS.Long)),'')
        , Div                  = ISNULL(RTRIM(MAX(SUBSTRING(SKU.BUSR2,3,2))),'')
        , Brand                = ISNULL(RTRIM(MAX(CASE WHEN SUBSTRING(SKU.BUSR2,7,4)='A018' THEN 'P' ELSE DIV.Short END)),'')
        , PTSLocation          = CAST(ISNULL(RTRIM(MAX(IIF(ISNULL(PIKDT.ToLoc,'')<>'',PIKDT.ToLoc,PIKDT.Zones))),'') AS NVARCHAR(50))
        , TW_ImportVAS         = '' --MAX(CASE WHEN OG.UDF01 = 'R' AND OH.BillToKey='TWRETAIL' AND (OH.Type='R' OR (OH.Type='L' AND PIKDT.OD_UDF06 LIKE 'L%R'))               THEN '1' ELSE '' END)
        , TW_BraVAS            = MAX(CASE WHEN OG.UDF01 = 'R' AND OH.BillToKey='TWRETAIL' AND OH.Type='4' AND BRA.Code IS NOT NULL                                       THEN '2' ELSE '' END)
        , TW_CareLblVAS_NonBra = '' --MAX(CASE WHEN OG.UDF01 = 'R' AND OH.BillToKey='TWRETAIL' AND OH.Type='L' AND PIKDT.OD_UDF06 LIKE 'L%R' AND ISNULL(OH.BuyerPO,'')<>'BRA' THEN '3' ELSE '' END)
        , TW_CareLblVAS_Bra    = '' --MAX(CASE WHEN OG.UDF01 = 'R' AND OH.BillToKey='TWRETAIL' AND OH.Type='L' AND PIKDT.OD_UDF06 LIKE 'L%R' AND OH.BuyerPO='BRA'             THEN '4' ELSE '' END)
        , SQL1                 = ISNULL(RTRIM(MAX(VAS.Notes)),'')
        , SQL2                 = ISNULL(RTRIM(MAX(RM.Notes2)),'')
        , BRA                  = MAX(CASE WHEN OG.UDF01 = 'R' AND BRA.Code IS NOT NULL THEN 'B' ELSE '' END)
        , RouteCode            = MAX(ISNULL(RTRIM(RT.ZipCodeFrom),''))
        , CartonType           = MAX(ISNULL(RTRIM(PIF.CartonType),''))

   INTO #TEMP_RESULT

   FROM #TEMP_PACKHEADER PAK
   JOIN dbo.PACKDETAIL PD  (NOLOCK) ON PAK.PickslipNo = PD.PickslipNo
   JOIN dbo.SKU        SKU (NOLOCK) ON PD.Storerkey = SKU.Storerkey AND PD.Sku = SKU.Sku
   JOIN dbo.ORDERS     OH  (NOLOCK) ON PAK.FirstOrderkey = OH.Orderkey
   JOIN dbo.FACILITY   FAC (NOLOCK) ON OH.Facility = FAC.Facility

   LEFT JOIN dbo.PACKINFO     PIF  (NOLOCK) ON PD.PickslipNo = PIF.PickslipNo AND PD.CartonNo = PIF.CartonNo
   LEFT JOIN dbo.ROUTEMASTER  RT   (NOLOCK) ON OH.Route = RT.Route
   LEFT JOIN #TEMP_PICKDETAIL PIKDT(NOLOCK) ON PD.Storerkey = PIKDT.Storerkey AND PD.LabelNo = PIKDT.CaseID

   LEFT JOIN dbo.STORER SHPTO (NOLOCK) ON 'PVH'+OH.ConsigneeKey = SHPTO.Storerkey
   LEFT JOIN dbo.CODELKUP  OG (NOLOCK) ON OG.LISTNAME  = 'ORDERGROUP' AND OG.Code = OH.OrderGroup AND OG.Storerkey = OH.Storerkey
   LEFT JOIN dbo.CODELKUP VAS (NOLOCK) ON VAS.LISTNAME = 'PVHPXLBL'   AND VAS.Storerkey = OH.StorerKey AND VAS.Code = OH.BillToKey AND VAS.Code2=''
   LEFT JOIN dbo.CODELKUP  RM (NOLOCK) ON RM.LISTNAME  = 'PVHREPORT'  AND RM.Storerkey = OH.StorerKey AND RM.Code = OH.ConsigneeKey AND RM.Code2='SPREMARK'
   LEFT JOIN dbo.CODELKUP DIV (NOLOCK) ON DIV.LISTNAME = 'PVHDIV'     AND DIV.Storerkey = SKU.StorerKey AND DIV.Code = SKU.BUSR8
   LEFT JOIN dbo.CODELKUP BRA (NOLOCK) ON BRA.LISTNAME = 'PVHBRA'     AND BRA.Storerkey = SKU.StorerKey AND BRA.Code = SKU.Tariffkey

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
     FROM #TEMP_RESULT
     ORDER BY 1, 2
END

GO