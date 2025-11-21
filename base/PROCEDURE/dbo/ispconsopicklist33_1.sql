SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
/***************************************************************************/
/* Store Procedure: ispConsoPickList33_1                                   */
/* Creation Date: 08-APR-2013                                              */
/* Copyright: LF                                                           */
/* Written by: YTWan                                                       */
/*                                                                         */
/* Purpose:  Normal PickSlip                                               */
/*           273792-MY Project Starlight-Pick Slip Generation Process      */
/* Called By: PB: r_dw_consolidate_pick33_1                                */
/*                                                                         */
/* PVCS Version: 1.2                                                       */
/*                                                                         */
/* Version: 5.4                                                            */
/*                                                                         */
/* Data Modifications:                                                     */
/*                                                                         */
/* Updates:                                                                */
/* Date         Author    Ver.  Purposes                                   */
/* 23-Sep-2013  YTWan     1.1   SOS#289942 - LFA - Pick Slip Generation    */
/*                              Process Improvement (Wan01)                */
/* 12-Feb-2014  Leong     1.2   Prevent Pickslip number not tally with     */
/*                              nCounter table. (Leong01)                  */
/* 23-Apr-2014  YTWan     1.2   SOS#308966 - Amend Normal and Cluster Pick */
/*                              Pickslip.(Wan02)                           */
/* 28-Jan-2019  TLTING_ext 1.3  enlarge externorderkey field length        */
/***************************************************************************/

CREATE PROC [dbo].[ispConsoPickList33_1]
   @c_Loadkey NVARCHAR(10)
AS
BEGIN
   SET NOCOUNT ON
   SET ANSI_NULLS OFF
   SET QUOTED_IDENTIFIER OFF
   SET CONCAT_NULL_YIELDS_NULL OFF

DECLARE @n_StartTCnt       INT            -- Holds the current transaction count
      , @n_Err             INT
      , @b_Success         INT
      , @c_errmsg          INT

DECLARE @n_NoOfPickSlip    INT
      , @c_PickHeaderKey   NVARCHAR(10)
      , @c_PrintedFlag     NVARCHAR(1)

      , @c_Orderkey        NVARCHAR(10)
      , @c_PickZone        NVARCHAR(30)
      , @c_PZone           NVARCHAR(10)

SET @n_StartTCnt     = @@TRANCOUNT
SET @n_Err           = 0
SET @b_Success       = 1
SET @c_errmsg        = ''

SET @n_NoOfPickSlip  = ''
SET @c_PickHeaderKey = ''
SEt @c_PrintedFlag   = 'N'

SET @c_Orderkey      = ''
SET @c_PickZone      = ''
SET @c_PZone         = ''

WHILE @@TRANCOUNT > 0
BEGIN
   COMMIT TRAN
END

BEGIN TRAN
   CREATE TABLE #TMP_ORD
         (  Orderkey          NVARCHAR(10) NOT NULL
         ,  OrderSize         FLOAT        NOT NULL
         ,  OrderWgt          FLOAT        NOT NULL   --(Wan02)
         ,  PickZone          NVARCHAR(10) NOT NULL
         ,  PZType            NVARCHAR(1)  NOT NULL
         ,  RptType           NVARCHAR(1)  NOT NULL
         )

   CREATE TABLE #TMP_PICK
         (  SeqNo             INT      IDENTITY(1,1)  NOT NULL
         ,  PickSlipNo        NVARCHAR(10)
         ,  LoadKey           NVARCHAR(10)   NULL
         ,  Orderkey          NVARCHAR(10)   NULL
         ,  ExternOrderKey    NVARCHAR(50)   NULL   --tlting_ext
         ,  DeliveryDate      DATETIME       NULL
         ,  InvoiceNo         NVARCHAR(30)   NULL
         ,  ConsigneeKey      NVARCHAR(15)   NULL
         ,  C_Company         NVARCHAR(45)   NULL
         ,  C_Addr1           NVARCHAR(45)   NULL
         ,  C_Addr2           NVARCHAR(45)   NULL
         ,  C_Addr3           NVARCHAR(45)   NULL
         ,  C_Zip             NVARCHAR(15)   NULL
         ,  Route             NVARCHAR(10)   NULL
         ,  Route_Desc        NVARCHAR(60)   NULL
         ,  Notes1            NVARCHAR(255)  NULL
         ,  Notes2            NVARCHAR(255)  NULL
         ,  Loc               NVARCHAR(10)   NULL
         ,  Storerkey         NVARCHAR(15)   NULL
         ,  Sku               NVARCHAR(20)   NULL
         ,  SkuDesc           NVARCHAR(60)   NULL
         ,  Qty               INT            NULL
         ,  CaseCnt           INT            NULL
         ,  PackUOM1          NVARCHAR(10)   NULL              --(Wan02)     
         ,  PackUOM3          NVARCHAR(10)   NULL
         ,  Lottable02        NVARCHAR(18)   NULL
         ,  Lottable04        DATETIME       NULL
         ,  LocationSeq       INT            NULL
         ,  LogicalLocation   NVARCHAR(18)   NULL
         ,  PickZone          NVARCHAR(30)   NULL
         ,  OrderSize         FLOAT          NOT NULL
         ,  OrderWgt          FLOAT          NOT NULL             --(Wan02)
         ,  PrintedFlag       NVARCHAR(1)    NULL
         )

   INSERT INTO #TMP_ORD
         (  Orderkey
         ,  OrderSize
         ,  OrderWgt       --(Wan02)
         ,  PickZone
         ,  PZType
         ,  RptType
         )
   SELECT Orderkey   = PD.Orderkey
       ,  OrderSize  = SUM(PD.Qty * SKU.StdCube)
       ,  OrderWgt   = SUM(PD.Qty * SKU.StdGrossWgt)  --(Wan02)
       --,  PZ         = MAX(CASE WHEN LOC.PickZone IN ('LD', 'LE', 'LF', 'LG') THEN LOC.PickZone ELSE '' END) --(Wan02)
       ,  PZ         = MAX(CASE WHEN LOC.PickZone IN ('LA', 'LB', 'LC', 'LS') THEN '' ELSE LOC.PickZone  END)   --(Wan02)
       ,  PZType     = CASE WHEN COUNT(DISTINCT LOC.PickZone ) <= 1 THEN 'S' ELSE 'M' END
       ,  RptType    = ' '
   FROM LOADPLANDETAIL LPD WITH (NOLOCK)
   JOIN PICKDETAIL     PD  WITH (NOLOCK) ON (LPD.Orderkey = PD.ORderkey)
   JOIN SKU            SKU WITH (NOLOCK) ON (PD.Storerkey = SKU.Storerkey)
                                         AND(PD.Sku = SKU.Sku)
   JOIN LOC            LOC WITH (NOLOCK) ON (PD.Loc = LOC.Loc)
   WHERE LPD.LoadKey = @c_Loadkey
   GROUP BY PD.Orderkey

   --(Wan01) - START
   --UPDATE #TMP_ORD
   --   SET RptType  = CASE WHEN PZType = 'S' AND PickZone IN ('LF', 'LG') THEN 'N'
   --                       WHEN OrderSize >= 0.09 THEN 'N'
   --                       ELSE 'C'
   --                       END
   --(Wan02) - START
   --UPDATE #TMP_ORD
   --   SET RptType  = CASE WHEN OrderSize <= 0.12 AND PickZone IN ('LD','LE','LF','LG') THEN 'N'
   --                       WHEN OrderSize >  0.12 THEN 'N'
   --                       ELSE 'C'
   --                  END
   UPDATE #TMP_ORD
      SET RptType  = CASE WHEN OrderWgt <= 15 AND OrderSize <= 0.12 AND PZType = 'S' AND PickZone IN ('LC', 'LG', 'LS') THEN 'C'
                          WHEN OrderWgt <= 15 AND OrderSize <= 0.12 AND PickZone = '' THEN 'C'
                          ELSE 'N'
                     END
   --(Wan01) - END
   INSERT INTO #TMP_PICK
         (  PickSlipNo
         ,  LoadKey
         ,  Orderkey
         ,  ExternOrderKey
         ,  DeliveryDate
         ,  InvoiceNo
         ,  ConsigneeKey
         ,  c_Company
         ,  c_Addr1
         ,  c_Addr2
         ,  c_Addr3
         ,  c_Zip
         ,  Route
         ,  Route_Desc
         ,  Notes1
         ,  Notes2
         ,  Loc
         ,  Storerkey
         ,  Sku
         ,  SkuDesc
         ,  Qty
         ,  CaseCnt
         ,  PackUOM1                --(Wan02)  
         ,  PackUOM3
         ,  Lottable02
         ,  Lottable04
         ,  LocationSeq
         ,  LogicalLocation
         ,  PickZone
         ,  OrderSize
         ,  OrderWgt                --(Wan02)
         ,  PrintedFlag
         )
   SELECT   PickSlipNo     = ISNULL(RTRIM(PH.PickHeaderKey),'')
         ,  LoadKey        = @c_LoadKey
         ,  Orderkey       = O.OrderKey
         ,  ExternOrderKey = LTRIM(CASE WHEN LEFT(O.Externorderkey,5) = O.Storerkey THEN STUFF(ISNULL(RTRIM(O.Externorderkey),''),1,5,'')
                                                                                    ELSE ISNULL(RTRIM(O.Externorderkey),'')
                                                                                    END)
         ,  DeliveryDate   = ISNULL(O.DeliveryDate, '19000101')
         ,  InvoiceNo      = ISNULL(RTRIM(O.InvoiceNo), '')
         ,  ConsigneeKey   = ISNULL(RTRIM(O.BillToKey), '')
         ,  c_Company      = ISNULL(RTRIM(O.c_Company), '')
         ,  c_Addr1        = ISNULL(RTRIM(O.c_Address1), '')
         ,  c_Addr2        = ISNULL(RTRIM(O.c_Address2), '')
         ,  c_Addr3        = ISNULL(RTRIM(O.c_Address3), '')
         ,  c_Zip          = ISNULL(RTRIM(O.c_Zip), '')
         ,  Route          = ISNULL(RTRIM(O.Route), '')
         ,  Route_Desc     = ''--ISNULL(RTRIM(RM.Descr), '')                  --(Wan01)
         ,  Notes1         = CONVERT(NVARCHAR(255), ISNULL(O.Notes, ''))
         ,  Notes2         = CONVERT(NVARCHAR(255), ISNULL(O.Notes2,''))
         ,  Loc            = ISNULL(RTRIM(PD.Loc),'')
         ,  Storerkey      = ISNULL(RTRIM(PD.Storerkey),'')
         ,  Sku            = ISNULL(RTRIM(PD.Sku),'')
         ,  SkuDesc        = ISNULL(RTRIM(Sku.Descr), '')
         ,  Qty            = ISNULL(SUM(PD.qty),0)
         ,  CaseCnt        = ISNULL(PACK.CaseCnt,0)
         ,  PackUOM1       = ISNULL(RTRIM(PACK.PackUOM1), '')                 --(Wan02)
         ,  PackUOM3       = ISNULL(RTRIM(PACK.PackUOM3), '')
         ,  Lottable02     = ISNULL(RTRIM(LA.Lottable02),'')
         ,  Lottable04     = ISNULL(LA.Lottable04,'19000101')
         ,  LocationSeq    = CASE ISNULL(RTRIM(LOC.LocationType), '') WHEN 'OTHER' THEN 3
                                                                      WHEN 'CASE'  THEN 2
                                                                      WHEN 'PICK'  THEN 1
                                                                      END
         ,  LogicalLocation= ISNULL(RTRIM(LOC.LogicalLocation), '')
         ,  PickZone       = ISNULL(RTRIM(LOC.PickZone), '')
         ,  OrderSize      = ISNULL(TMP.OrderSize,0)
         ,  OrderWgt       = ISNULL(TMP.Orderwgt,0)               --(Wan02)
         ,  PrintedFlag    = CASE WHEN ISNULL(RTRIM(PH.PickHeaderKey),'') = '' THEN 'N' ELSE 'Y' END
   FROM #TMP_ORD TMP
   JOIN LOADPLANDETAIL LD   WITH (NOLOCK) ON (TMP.Orderkey = LD.Orderkey)
   JOIN ORDERS         O    WITH (NOLOCK) ON (LD.Orderkey = O.Orderkey)
   JOIN PICKDETAIL     PD   WITH (NOLOCK) ON (O.OrderKey = PD.Orderkey)
   JOIN LOTATTRIBUTE   LA   WITH (NOLOCK) ON (PD.Lot = LA.Lot)
   JOIN LOC            LOC  WITH (NOLOCK) ON (PD.LOC = LOC.LOC)
   JOIN SKU            SKU  WITH (NOLOCK) ON (PD.StorerKey = SKU.StorerKey AND PD.Sku = SKU.Sku)
   JOIN PACK           PACK WITH (NOLOCK) ON (SKU.Packkey = PACK.Packkey)
   LEFT JOIN ROUTEMASTER RM WITH (NOLOCK) ON (O.Route = RM.Route)
   LEFT JOIN PICKHEADER  PH WITH (NOLOCK) ON (LD.LoadKey = PH.ExternOrderKey AND LD.Orderkey = PH.Orderkey AND PH.Zone = '3')
  WHERE TMP.RptType = 'N'
    AND PD.Status  >= '0'
    AND LD.LoadKey = @c_LoadKey
  GROUP BY  ISNULL(RTRIM(PH.PickHeaderKey),'')
         ,  O.OrderKey
         ,  LTRIM(CASE WHEN LEFT(O.Externorderkey,5) = O.Storerkey THEN STUFF(ISNULL(RTRIM(O.Externorderkey),''),1,5,'')
                       ELSE ISNULL(RTRIM(O.Externorderkey),'')
                  END)
         ,  ISNULL(O.DeliveryDate, '19000101')
         ,  ISNULL(RTRIM(O.InvoiceNo), '')
         ,  ISNULL(RTRIM(O.BillToKey), '')
         ,  ISNULL(RTRIM(O.c_Company), '')
         ,  ISNULL(RTRIM(O.c_Address1), '')
         ,  ISNULL(RTRIM(O.c_Address2), '')
         ,  ISNULL(RTRIM(O.c_Address3), '')
         ,  ISNULL(RTRIM(O.c_Zip), '')
         ,  ISNULL(RTRIM(O.Route), '')
         ,  ISNULL(RTRIM(RM.Descr), '')
         ,  CONVERT(NVARCHAR(255), ISNULL(O.Notes, ''))
         ,  CONVERT(NVARCHAR(255), ISNULL(O.Notes2, ''))
         ,  ISNULL(RTRIM(PD.Loc),'')
         ,  ISNULL(RTRIM(PD.Storerkey),'')
         ,  ISNULL(RTRIM(PD.Sku),'')
         ,  ISNULL(RTRIM(Sku.Descr), '')
         ,  ISNULL(PACK.CaseCnt,0)
         ,  ISNULL(RTRIM(PACK.PackUOM1), '')                 --(Wan02)
         ,  ISNULL(RTRIM(PACK.PackUOM3), '')
         ,  ISNULL(RTRIM(LA.Lottable02),'')
         ,  ISNULL(LA.Lottable04,'19000101')
         ,  CASE ISNULL(RTRIM(LOC.LocationType), '') WHEN 'OTHER' THEN 3
                                                     WHEN 'CASE'  THEN 2
                                                     WHEN 'PICK'  THEN 1
                                                     END
         ,  ISNULL(RTRIM(LOC.LogicalLocation), '')
         ,  ISNULL(RTRIM(LOC.PickZone), '')
         ,  ISNULL(TMP.OrderSize,0)
         ,  ISNULL(TMP.Orderwgt,0)               --(Wan02)
   ORDER BY O.OrderKey
         ,  ISNULL(RTRIM(LOC.PickZone), '')
         ,  CASE ISNULL(RTRIM(LOC.LocationType), '') WHEN 'OTHER' THEN 3
                                                     WHEN 'CASE'  THEN 2
                                                     WHEN 'PICK'  THEN 1
                                                     END
         ,  ISNULL(RTRIM(LOC.LogicalLocation), '')
         ,  ISNULL(RTRIM(PD.Loc), '')
         ,  ISNULL(RTRIM(PD.Sku), '')

   BEGIN TRAN
   UPDATE PICKHEADER WITH (ROWLOCK)
   SET PickType = '1'
      ,TrafficCop = NULL
   WHERE ExternOrderKey = @c_Loadkey
   AND Zone = '3'
   AND PickType = '0'

   SET @n_err = @@ERROR

   IF @n_err <> 0
   BEGIN
      IF @@TRANCOUNT >= 1
      BEGIN
         ROLLBACK TRAN
      END
   END
   ELSE
   BEGIN
      IF @@TRANCOUNT > 0
      BEGIN
         COMMIT TRAN
      END
      ELSE
      BEGIN
         ROLLBACK TRAN
      END
   END

   WHILE @@TRANCOUNT > 0
   BEGIN
      COMMIT TRAN
   END

   SELECT @n_NoOfPickSlip = COUNT(DISTINCT Orderkey)
   FROM #TMP_PICK
   WHERE ISNULL(RTRIM(PickSlipNo),'') = '' -- (Leong01)

   IF @n_NoOfPickSlip = 0
   BEGIN
      GOTO QUIT
   END

   BEGIN TRAN
   EXECUTE nspg_GetKey 'PICKSLIP'
                     , 9
                     , @c_PickHeaderKey OUTPUT
                     , @b_success       OUTPUT
                     , @n_err           OUTPUT
                     , @c_errmsg        OUTPUT
                     , 0
                     , @n_NoOfPickSlip
   COMMIT TRAN

   BEGIN TRAN
   INSERT INTO PICKHEADER
         (  PickHeaderKey
         ,  OrderKey
         ,  ExternOrderKey
         ,  PickType
         ,  Zone
         ,  TrafficCop
         )
   SELECT  'P' + RIGHT ( '000000000' +
                 LTRIM(RTRIM(STR(CAST(@c_PickHeaderKey AS INT) +
                                (SELECT COUNT(DISTINCT Orderkey)
                                 FROM #TMP_PICK AS RANK
                                 WHERE RANK.OrderKey < #TMP_PICK.OrderKey
                                 AND ISNULL(RTRIM(Rank.PickSlipNo),'') = '' -- (Leong01)
                                )))),9)
      , OrderKey
      , LoadKey
      , '0'
      , '3'
      , ''
   FROM #TMP_PICK
   WHERE ISNULL(RTRIM(PickSlipNo),'') = '' -- (Leong01)
   GROUP BY LoadKey
         ,  OrderKey
   ORDER BY OrderKey

   UPDATE #TMP_PICK
   SET   PickSlipNo = PICKHEADER.PickHeaderKey
   FROM  PICKHEADER WITH (NOLOCK)
   WHERE PICKHEADER.ExternOrderKey = #TMP_PICK.LoadKey
   AND   PICKHEADER.OrderKey = #TMP_PICK.OrderKey
   AND   PICKHEADER.Zone = '3'
   AND   ISNULL(RTRIM(#TMP_PICK.PickSlipNo),'') = '' -- (Leong01)

   WHILE @@TRANCOUNT > 0
   BEGIN
      COMMIT TRAN
   END

   BEGIN TRAN
   DECLARE CUR_ORD CURSOR LOCAL FAST_FORWARD READ_ONLY FOR
   SELECT DISTINCT Orderkey
   FROM #TMP_ORD
   WHERE RptType = 'N'
   AND   PZType = 'M'

   OPEN CUR_ORD
   FETCH NEXT FROM CUR_ORD INTO @c_OrderKey
   WHILE @@FETCH_STATUS <> -1
   BEGIN
      SET @c_PZone = ''
      DECLARE CUR_PICK CURSOR LOCAL FAST_FORWARD READ_ONLY FOR
      SELECT DISTINCT PickZone
      FROM #TMP_PICK
      WHERE Orderkey = @c_Orderkey

      OPEN CUR_PICK
      FETCH NEXT FROM CUR_PICK INTO @c_PZone
      WHILE @@FETCH_STATUS <> -1
      BEGIN
         SET @c_PickZone = @c_PickZone + @c_PZone + ', '
         FETCH NEXT FROM CUR_PICK INTO @c_PZone
      END

      CLOSE CUR_PICK
      DEALLOCATE CUR_PICK

      IF LEN(@c_PickZone) > 0
      BEGIN
         SET @c_PickZone = SUBSTRING(@c_PickZone,1,LEN(@c_PickZone)-1)
      END

      UPDATE #TMP_PICK
         SET PickZone = @c_PZone
      WHERE Orderkey = @c_OrderKey

      FETCH NEXT FROM CUR_ORD INTO @c_OrderKey
   END
   CLOSE CUR_ORD
   DEALLOCATE CUR_ORD

   WHILE @@TRANCOUNT > 0
   BEGIN
      COMMIT TRAN
   END

   QUIT:

   SELECT   TMP.PickSlipNo
         ,  TMP.LoadKey
         ,  TMP.Orderkey
         ,  TMP.ExternOrderkey
         ,  TMP.DeliveryDate
         ,  TMP.InvoiceNo
         ,  TMP.ConsigneeKey
         ,  TMP.C_Company
         ,  TMP.C_Addr1
         ,  TMP.C_Addr2
         ,  TMP.C_Addr3
         ,  TMP.C_Zip
         ,  TMP.Route
         ,  TMP.Route_Desc
         ,  TMP.Notes1
         ,  TMP.Notes2
         ,  TMP.Loc
         ,  TMP.Storerkey
         ,  TMP.Sku
         ,  TMP.SkuDesc
         ,  SUM(TMP.Qty)
         ,  TMP.CaseCnt
         ,  TMP.PackUOM3
         ,  TMP.Lottable02
         ,  Lottable04 = CASE WHEN TMP.Lottable04 = CONVERT(DATETIME,'19000101') THEN NULL ELSE TMP.Lottable04 END
         ,  TMP.LogicalLocation
         ,  TMP.PickZone
         ,  TMP.OrderSize
         ,  TMP.PrintedFlag
         --(Wan02) - START
         --,  MHEType = CASE WHEN TMP.OrderSize <= 0.12 THEN 'Small Troley'
         --                  WHEN TMP.OrderSize >  0.12 THEN 'Hand Pallet Jack'
         --                  END
         ,  MHEType = CASE WHEN (SELECT MAX(T.LocationSeq)
                                 FROM #TMP_PICK T WHERE T.PickSlipNo = TMP.PickslipNo) > 1 
                                                                             THEN 'Hand Pallet Jack & Stock Picker'
                           WHEN TMP.OrderSize <= 0.12 AND TMP.Orderwgt <= 45 THEN 'Small Trolley'
                           WHEN TMP.OrderSize <= 0.36 AND TMP.Orderwgt <= 45 THEN 'Cluster Trolley'
                           ELSE 'Hand Pallet Jack' 
                           END 
         ,  TMP.PackUOM1
         --(Wan02) - END
   FROM #TMP_PICK TMP
   GROUP BY TMP.PickSlipNo
         ,  TMP.LoadKey
         ,  TMP.Orderkey
         ,  TMP.ExternOrderkey
         ,  TMP.DeliveryDate
         ,  TMP.InvoiceNo
         ,  TMP.ConsigneeKey
         ,  TMP.C_Company
         ,  TMP.C_Addr1
         ,  TMP.C_Addr2
         ,  TMP.C_Addr3
         ,  TMP.C_Zip
         ,  TMP.Route
         ,  TMP.Route_Desc
         ,  TMP.Notes1
         ,  TMP.Notes2
         ,  TMP.Loc
         ,  TMP.Storerkey
         ,  TMP.Sku
         ,  TMP.SkuDesc
         ,  TMP.CaseCnt
         ,  TMP.PackUOM3
         ,  TMP.Lottable02
         ,  CASE WHEN TMP.Lottable04 = CONVERT(DATETIME,'19000101') THEN NULL ELSE TMP.Lottable04 END
         ,  TMP.LogicalLocation
         ,  TMP.PickZone
         ,  TMP.OrderSize
         ,  TMP.PrintedFlag
         ,  TMP.PackUOM1               --(Wan02)
         ,  TMP.Orderwgt               --(Wan02)
   ORDER BY TMP.PickSlipNo
         ,  MIN(TMP.SeqNo)

   DROP TABLE #TMP_ORD
   DROP Table #TMP_PICK

   WHILE @@TRANCOUNT < @n_StartTCnt
   BEGIN
      BEGIN TRAN
   END
END

GO